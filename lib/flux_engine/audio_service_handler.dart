import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

Future<RadioAudioHandler> initAudioService() async {
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
      androidNotificationIcon: 'ic_notification',
      androidNotificationClickStartsActivity: true,
      androidResumeOnClick: true,
    ),
  );
}

class RadioAudioHandler extends BaseAudioHandler with SeekHandler {
  final _equalizer = AndroidEqualizer();
  final _loudnessEnhancer = AndroidLoudnessEnhancer();
  // final _bassBoost = AndroidBassBoost();
  late AudioPlayer _player;
  
  VoidCallback? onSkipNext;
  VoidCallback? onSkipPrevious;

  RadioAudioHandler() {
    _player = AudioPlayer(
      audioPipeline: AudioPipeline(
        androidAudioEffects: [
          _equalizer,
          _loudnessEnhancer,
          // _bassBoost,
        ],
      ),
    );
    
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    
    // Listen to changes in the player's current item to update mediaItem
    _player.sequenceStateStream.listen((state) {
      final sequence = state.sequence;
      final currentIndex = state.currentIndex;
      if (sequence.isEmpty || currentIndex == null) return;
      final currentItem = sequence[currentIndex];
      if (currentItem.tag is MediaItem) {
        mediaItem.add(currentItem.tag as MediaItem);
      }
    });

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
              if (_player.playing) pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(1.0);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              // Only resume if it was playing before
              break;
          }
        }
      });
    });
  }

  void _listenToMetadata() {
    _player.icyMetadataStream.listen((icy) {
      final songTitle = icy?.info?.title;
      if (songTitle != null && songTitle.isNotEmpty) {
        final currentItem = mediaItem.value;
        if (currentItem != null) {
          // If playing a station, we swap Title to song name and move Station Name to Artist line
          // For podcasts, we might treat it differently, but typically ICY is for stations.
          final isStation = currentItem.extras?['type'] == 'station';
          
          if (isStation) {
            // Check if we already stored the original station name in extras or if current artist is the station name
            final stationName = currentItem.extras?['station_name'] ?? currentItem.title;
            
            mediaItem.add(currentItem.copyWith(
              title: songTitle,
              artist: stationName,
              displayTitle: songTitle,
              displaySubtitle: stationName,
              extras: {
                ...currentItem.extras ?? {},
                'station_name': stationName, // Preserve original station name
              },
            ));
          }
        }
      }
    });
  }

  AndroidEqualizer get equalizer => _equalizer;
  AndroidLoudnessEnhancer get loudnessEnhancer => _loudnessEnhancer;
  // AndroidBassBoost get bassBoost => _bassBoost;

  @override
  Future<void> play() async {
    final session = await AudioSession.instance;
    if (await session.setActive(true)) {
      await _player.play();
    }
    await super.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    await super.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    final session = await AudioSession.instance;
    await session.setActive(false);
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async => onSkipNext?.call();

  @override
  Future<void> skipToPrevious() async => onSkipPrevious?.call();

  @override
  Future<void> fastForward() => seek(_player.position + const Duration(seconds: 30));

  @override
  Future<void> rewind() => seek(_player.position - const Duration(seconds: 10));

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Future<void> setUrl(String url, MediaItem item) async {
    try {
      AudioSource source;
      if (url.startsWith('http')) {
        source = AudioSource.uri(Uri.parse(url), tag: item);
      } else {
        source = AudioSource.file(url, tag: item);
      }

      mediaItem.add(item);
      await _player.setAudioSource(source);
      // Ensure the UI and service are perfectly in sync for the notification
      mediaItem.add(item);
    } catch (e) {
      debugPrint("Error setting audio source: $e");
      rethrow;
    }
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    final item = mediaItem.value;
    final isStation = item?.extras?['type'] == 'station';
    
    final controls = [
      MediaControl.skipToPrevious,
      if (_player.playing) MediaControl.pause else MediaControl.play,
      MediaControl.stop,
      MediaControl.skipToNext,
      if (!isStation) MediaControl.rewind,
      if (!isStation) MediaControl.fastForward,
    ];

    return PlaybackState(
      controls: controls,
      systemActions: {
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
        MediaAction.seek,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        if (!isStation) MediaAction.fastForward,
        if (!isStation) MediaAction.rewind,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState] ?? AudioProcessingState.idle,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  @override
  Future<void> onTaskRemoved() {
    if (!playbackState.value.playing) stop();
    return super.onTaskRemoved();
  }
  
  AudioPlayer get player => _player;
}
