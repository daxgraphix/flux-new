import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'audio_service_handler.dart';
import '../flux_hardware/radio_service.dart';
import '../flux_ui/models/podcast.dart';
import '../flux_storage/radio_storage.dart';
import 'app_exception.dart';

class PlaybackController extends ChangeNotifier {
  final RadioAudioHandler _audioHandler;
  AudioPlayer get _player => _audioHandler.player;

  RadioStation? _currentStation;
  Episode? _currentEpisode;
  String _currentTitle = '';
  String _currentSubtitle = '';
  bool _isPlaying = false;
  bool _isLoading = false;
  AppException? _error;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isNetworkAvailable = true;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playerStateSubscription;

  Timer? _sleepTimer;
  Duration? _sleepTimerDuration;

  Duration? get sleepTimerDuration => _sleepTimerDuration;
  RadioStation? get currentStation => _currentStation;
  Episode? get currentEpisode => _currentEpisode;
  String get currentTitle => _currentTitle;
  String get currentSubtitle => _currentSubtitle;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  AppException? get error => _error;
  String? get errorMessage => _error?.localizedMessage;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isNetworkAvailable => _isNetworkAvailable;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get sleepTimerStream {
    final controller = StreamController<Duration?>.broadcast();
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (controller.isClosed) {
        timer.cancel();
        return;
      }
      controller.add(_sleepTimerDuration);
    });
    return controller.stream;
  }

  PlaybackController(this._audioHandler) {
    _initStreams();
    _startNetworkMonitoring();
  }

  void _initStreams() {
    _positionSubscription = _player.positionStream.listen((p) {
      _position = p;
      if (_currentEpisode != null && p.inSeconds > 0 && p.inSeconds % 5 == 0) {
        RadioStorage().updateEpisodePosition(
          _currentEpisode!.id, 
          p.inSeconds,
          episode: _currentEpisode
        );
      }
    });

    _durationSubscription = _player.durationStream.listen((d) {
      _duration = d ?? Duration.zero;
      notifyListeners();
    });

    _playerStateSubscription = _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
    });
  }

  void _startNetworkMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      _isNetworkAvailable = result.any((r) => r != ConnectivityResult.none);
      notifyListeners();
    });
  }

  Future<void> initialize() async {
    final lastPlayed = await RadioStorage().getLastPlayed();
    if (lastPlayed != null) {
      final type = lastPlayed['type'];
      final item = lastPlayed['item'];
      if (type == 'station') {
        _currentStation = RadioStation.fromJson(item);
        _currentTitle = _currentStation!.name;
        _currentSubtitle = [_currentStation!.country, _currentStation!.genre]
            .where((s) => s.isNotEmpty)
            .join(' • ');
      } else if (type == 'episode') {
        _currentEpisode = Episode.fromJson(item);
        _currentTitle = _currentEpisode!.title;
        _currentSubtitle = 'Podcast';
        final pos = await RadioStorage().getEpisodePosition(_currentEpisode!.id);
        _position = Duration(seconds: pos);
      }
      notifyListeners();
    }
  }

  Future<void> playStream(String url, String name, {String? favicon}) async {
    if (!_isNetworkAvailable) {
      _error = AppException('No network connection', ExceptionType.network);
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    
    _currentStation = RadioStation(
      name: name,
      url: url,
      country: 'Global',
      language: '',
      genre: 'Streema',
      bitrate: 128,
      favicon: favicon ?? '',
    );
    _currentTitle = name;
    _currentSubtitle = 'Streema Global Stream';
    _currentEpisode = null;
    notifyListeners();

    try {
      if (_isPlaying) {
        await _audioHandler.pause();
      }

      final mediaItem = MediaItem(
        id: url,
        album: 'Flux Radio',
        title: name,
        artist: _currentSubtitle,
        artUri: favicon != null && favicon.isNotEmpty ? Uri.parse(favicon) : null,
        extras: {'type': 'station', 'url': url},
      );
      
      await _audioHandler.setUrl(url, mediaItem).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Connection timed out'),
      );

      await _audioHandler.play();
    } on TimeoutException {
      _error = AppException('Connection timed out', ExceptionType.timeout);
      _isPlaying = false;
    } catch (e) {
      _error = _mapErrorToException(e);
      _isPlaying = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> playStation(RadioStation station) async {
    if (!_isNetworkAvailable) {
      _error = AppException('No network connection', ExceptionType.network);
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    _currentStation = station;
    _currentTitle = station.name;
    _currentSubtitle = [station.country, station.genre].where((s) => s.isNotEmpty).join(' • ');
    _currentEpisode = null;
    notifyListeners();

    try {
      if (_isPlaying) {
        await _audioHandler.pause();
      }

      await RadioStorage().saveLastPlayed('station', station.toJson());

      final mediaItem = MediaItem(
        id: station.url,
        album: 'Flux Radio',
        title: station.name,
        artist: _currentSubtitle,
        artUri: station.favicon.isNotEmpty ? Uri.parse(station.favicon) : null,
        extras: {'type': 'station', 'station': jsonEncode(station.toJson())},
      );
      
      await _audioHandler.setUrl(station.url, mediaItem).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Connection timed out'),
      );

      await _audioHandler.play();
    } on TimeoutException {
      _error = AppException('Connection timed out', ExceptionType.timeout);
      _isPlaying = false;
    } catch (e) {
      _error = _mapErrorToException(e);
      _isPlaying = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> playEpisode(Episode episode) async {
    final isDownloaded = episode.downloadPath != null && File(episode.downloadPath!).existsSync();
    
    if (!_isNetworkAvailable && !isDownloaded) {
      _error = AppException('No network connection', ExceptionType.network);
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    _currentEpisode = episode;
    _currentStation = null;
    _currentTitle = episode.title;
    _currentSubtitle = 'Podcast';
    notifyListeners();

    try {
      if (_isPlaying) {
        await _audioHandler.pause();
      }

      final pos = await RadioStorage().getEpisodePosition(episode.id);
      
      final source = isDownloaded ? episode.downloadPath! : episode.audio;

      final mediaItem = MediaItem(
        id: source,
        album: 'Flux Podcast',
        title: episode.title,
        artist: episode.podcastTitle ?? 'Podcast',
        artUri: episode.image.isNotEmpty ? Uri.parse(episode.image) : null,
        extras: {'type': 'episode', 'episode': jsonEncode(episode.toJson())},
      );

      await _audioHandler.setUrl(source, mediaItem);
      if (pos > 0) {
        await _player.seek(Duration(seconds: pos));
      }
      await _audioHandler.play();
      await RadioStorage().saveLastPlayed('episode', episode.toJson());
    } catch (e) {
      _error = _mapErrorToException(e);
      _isPlaying = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  AppException _mapErrorToException(dynamic e) {
    final errorStr = e.toString();
    if (errorStr.contains('403')) {
      return AppException('Access denied', ExceptionType.unavailable, e);
    } else if (errorStr.contains('404')) {
      return AppException('Not found', ExceptionType.broken, e);
    } else if (e is SocketException) {
      return AppException('Network error', ExceptionType.network, e);
    }
    return AppException('Unknown error', ExceptionType.unknown, e);
  }

  Future<void> pause() async {
    await _audioHandler.pause();
    if (_currentEpisode != null) {
      await RadioStorage().updateEpisodePosition(
        _currentEpisode!.id, 
        _position.inSeconds,
        episode: _currentEpisode
      );
    }
  }

  Future<void> resume() async {
    await _audioHandler.play();
  }

  Future<void> stop() async {
    await _audioHandler.stop();
    _currentStation = null;
    _currentEpisode = null;
    _currentTitle = '';
    _currentSubtitle = '';
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> seekForward({int seconds = 30}) async {
    final newPosition = _position + Duration(seconds: seconds);
    if (newPosition < _duration) {
      await seek(newPosition);
    } else {
      await seek(_duration);
    }
  }

  Future<void> seekBackward({int seconds = 10}) async {
    final newPosition = _position - Duration(seconds: seconds);
    if (newPosition > Duration.zero) {
      await seek(newPosition);
    } else {
      await seek(Duration.zero);
    }
  }

  Future<void> skipNext(List<RadioStation> stations, List<Episode> episodes) async {
    if (_currentStation != null) {
      if (stations.isEmpty) return;
      int index = stations.indexWhere((s) => s.url == _currentStation!.url);
      if (index != -1) {
        int nextIndex = (index + 1) % stations.length;
        await playStation(stations[nextIndex]);
      }
    } else if (_currentEpisode != null) {
      if (episodes.isEmpty) return;
      int index = episodes.indexWhere((e) => e.audio == _currentEpisode!.audio);
      if (index != -1 && index < episodes.length - 1) {
        await playEpisode(episodes[index + 1]);
      }
    }
  }

  Future<void> skipPrevious(List<RadioStation> stations, List<Episode> episodes) async {
    if (_currentStation != null) {
      if (stations.isEmpty) return;
      int index = stations.indexWhere((s) => s.url == _currentStation!.url);
      if (index != -1) {
        int prevIndex = (index - 1 + stations.length) % stations.length;
        await playStation(stations[prevIndex]);
      }
    } else if (_currentEpisode != null) {
      if (episodes.isEmpty) return;
      int index = episodes.indexWhere((e) => e.audio == _currentEpisode!.audio);
      if (index != -1 && index > 0) {
        await playEpisode(episodes[index - 1]);
      }
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> retry() async {
    if (_currentStation != null) {
      await playStation(_currentStation!);
    } else if (_currentEpisode != null) {
      await playEpisode(_currentEpisode!);
    }
  }

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimerDuration = duration;
    if (duration != null) {
      _sleepTimer = Timer(duration, () {
        pause();
        _sleepTimerDuration = null;
        notifyListeners();
      });

      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_sleepTimerDuration == null || !(_sleepTimer?.isActive ?? false)) {
          timer.cancel();
          return;
        }
        _sleepTimerDuration = _sleepTimerDuration! - const Duration(seconds: 1);
        // We avoid calling notifyListeners() here; UI can use a stream if needed
      });
    }
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimerDuration = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    super.dispose();
  }
}
