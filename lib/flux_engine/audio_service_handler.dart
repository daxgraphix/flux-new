import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

Future<AudioHandler> initAudioService() async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  return await AudioService.init(
    builder: () => RadioAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.flux.radio.channel.audio',
      androidNotificationChannelName: 'Flux Radio Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: false,
      androidShowNotificationBadge: true,
      notificationColor: const Color(0xFFE53935),
    ),
  );
}

class RadioAudioHandler extends BaseAudioHandler with SeekHandler {
  final _equalizer = AndroidEqualizer();
  final _loudnessEnhancer = AndroidLoudnessEnhancer();
  late AudioPlayer _player;

  RadioAudioHandler() {
    _player = AudioPlayer(
      audioPipeline: AudioPipeline(
        androidAudioEffects: [
          _equalizer,
          _loudnessEnhancer,
        ],
      ),
    );
    _player.setAudioSource(
      AudioSource.uri(Uri.parse(''), tag: const MediaItem(id: '', title: '')),
      preload: false,
    );
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    _listenToMetadata();
    _handleAudioInterruptions();
  }

  void _handleAudioInterruptions() {
    AudioSession.instance.then((session) {
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(0.5);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(1.0);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              play();
              break;
          }
        }
      });
    });
  }

  void _listenToMetadata() {
    _player.icyMetadataStream.listen((icy) {
      final title = icy?.info?.title;
      if (title != null && title.isNotEmpty) {
        final currentItem = mediaItem.value;
        if (currentItem != null) {
          mediaItem.add(currentItem.copyWith(
            displaySubtitle: title,
            title: currentItem.title, // Keep station name as main title
          ));
        }
      }
    });
  }

  AndroidEqualizer get equalizer => _equalizer;
  AndroidLoudnessEnhancer get loudnessEnhancer => _loudnessEnhancer;

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setUrl(String url) async {
    await _player.setUrl(url);
  }

  void setMediaItem(MediaItem item) {
    mediaItem.add(item);
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
  
  AudioPlayer get player => _player;
}
