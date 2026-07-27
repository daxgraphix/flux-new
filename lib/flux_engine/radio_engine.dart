import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../flux_hardware/radio_service.dart';
import '../flux_storage/radio_storage.dart';
import 'radio_repository.dart';
import '../flux_ui/models/podcast.dart';

import 'package:audio_service/audio_service.dart';
import 'audio_service_handler.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'recording_service.dart';
import 'alarm_service.dart';
import 'station_provider.dart';
import 'download_service.dart';

class RadioEngine extends ChangeNotifier {
  final AudioHandler _audioHandler;
  final RecordingService _recordingService;
  final AlarmService _alarmService;
  final StationProvider _stationProvider;
  final DownloadService _downloadService;
  AudioPlayer get _player => (_audioHandler as RadioAudioHandler).player;
  final RadioRepository _repository = RadioRepository();

  RadioStation? _currentStation;
  Episode? _currentEpisode;
  String _currentTitle = '';
  bool _isPlaying = false;
  
  List<double> _equalizerBands = [0.0, 0.0, 0.0, 0.0, 0.0];
  List<int> _equalizerCenterFrequencies = [60, 230, 910, 3600, 14000];
  double _loudnessGain = 0.0;
  double _volume = 1.0;
  List<RadioStation> _recentStations = [];
  List<FavoriteStation> _favorites = [];
  List<String> _savedRecordings = [];
  final List<String> _recentSearches = [];
  bool _autoPlay = true;
  bool _highQuality = false;
  bool _dataSaver = false;
  
  bool _isNetworkAvailable = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _sleepTimer;
  Duration _sleepDuration = Duration.zero;
  Duration _sleepRemainingTime = Duration.zero;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playerStateSubscription;

  AudioPlayer get player => _player;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isNetworkAvailable => _isNetworkAvailable;
  bool get isSleepTimerActive => _sleepTimer != null;
  bool get isRecording => _recordingService.isRecording;
  String? get recordingPath => _recordingService.recordingPath;
  Duration get recordingDuration => _recordingService.recordingDuration;
  DateTime? get recordingStartTime => _recordingService.recordingStartTime;
  Duration get sleepRemainingTime => _sleepRemainingTime;
  List<double> get equalizerBands => List.unmodifiable(_equalizerBands);
  List<int> get equalizerCenterFrequencies => List.unmodifiable(_equalizerCenterFrequencies);
  double get loudnessGain => _loudnessGain;
  List<RadioStation> get recentStations => List.unmodifiable(_recentStations);
  List<FavoriteStation> get favorites => List.unmodifiable(_favorites);
  List<RadioStation> get favoriteStations => _favorites.map((f) => f.toRadioStation()).toList();
  List<String> get savedRecordings => List.unmodifiable(_savedRecordings);
  List<String> get recentSearches => List.unmodifiable(_recentSearches);
  bool get autoPlay => _autoPlay;
  bool get highQuality => _highQuality;
  bool get dataSaver => _dataSaver;
  List<RadioAlarm> get alarms => _alarmService.alarms;
  bool _isLoading = false;
  String? _errorMessage;
  String? get errorMessage => _errorMessage ?? _stationProvider.errorMessage;
  RadioStation? get currentStation => _currentStation;
  Episode? get currentEpisode => _currentEpisode;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading || _stationProvider.isLoading;
  String get currentTitle => _currentTitle;
  List<RadioStation> get stations => _stationProvider.stations;
  List<Podcast> get podcasts => _stationProvider.podcasts;
  List<Episode> get episodes => _stationProvider.episodes;
  List<String> get countries => _stationProvider.countries;
  List<String> get genres => _stationProvider.genres;
  List<String> get languages => _stationProvider.languages;
  double get volume => _volume;
  Duration get sleepDuration => _sleepDuration;

  // Download states delegation
  double getDownloadProgress(String id) => _downloadService.getDownloadProgress(id);
  bool isDownloading(String id) => _downloadService.isDownloading(id);

  RadioEngine(this._audioHandler, this._recordingService, this._alarmService, this._stationProvider, this._downloadService) {
    _recordingService.addListener(notifyListeners);
    _alarmService.addListener(notifyListeners);
    _stationProvider.addListener(notifyListeners);
    _downloadService.addListener(notifyListeners);
  }

  Future<void> initialize() async {
    await RadioStorage().init();
    await _loadSettings();
    await _stationProvider.initialize();
    await loadRecentStations();
    await loadFavorites();
    await _alarmService.initialize();
    await _configureAudioSession();
    await loadSavedRecordings();
    await loadRecentSearches();
    await _initializeEqualizer();
    _startNetworkMonitoring();
    
    if (_autoPlay && _recentStations.isNotEmpty) {
      playStation(_recentStations.first);
    }
  }

  Future<void> _loadSettings() async {
    _autoPlay = await RadioStorage().getSettings<bool>('auto_play', defaultValue: true) ?? true;
    _highQuality = await RadioStorage().getSettings<bool>('high_quality', defaultValue: false) ?? false;
    _dataSaver = await RadioStorage().getSettings<bool>('data_saver', defaultValue: false) ?? false;
    _volume = await RadioStorage().getSettings<double>('volume', defaultValue: 1.0) ?? 1.0;
  }

  Future<void> setAutoPlay(bool value) async {
    _autoPlay = value;
    await RadioStorage().saveSettings('auto_play', value);
    notifyListeners();
  }

  Future<void> setHighQuality(bool value) async {
    _highQuality = value;
    await RadioStorage().saveSettings('high_quality', value);
    notifyListeners();
    // Refresh current list with new quality preference
    loadTopStations(forceRefresh: true);
  }

  Future<void> setDataSaver(bool value) async {
    _dataSaver = value;
    await RadioStorage().saveSettings('data_saver', value);
    notifyListeners();
  }

  void _startNetworkMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      final wasAvailable = _isNetworkAvailable;
      _isNetworkAvailable = !results.contains(ConnectivityResult.none);
      
      if (wasAvailable && !_isNetworkAvailable && _isPlaying) {
        await _player.pause();
        _isPlaying = false;
        notifyListeners();
      } else if (!wasAvailable && _isNetworkAvailable && _currentStation != null && !_isPlaying) {
        try {
          await _player.play();
          _isPlaying = true;
          notifyListeners();
        } catch (e) {
          debugPrint('Failed to resume playback after network restored: $e');
        }
      }
    });
  }

  Future<void> _configureAudioSession() async {
    await _player.setVolume(_volume);
    
    _positionSubscription = _player.positionStream.listen((p) {
      _position = p;
      notifyListeners();
    });
    _durationSubscription = _player.durationStream.listen((d) {
      _duration = d ?? Duration.zero;
      notifyListeners();
    });
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
      }
      notifyListeners();
    });
  }


  Future<void> loadTrendingStations() async {
    await _stationProvider.loadTrendingStations();
  }

  Future<void> loadStationsByCountry(String country) async {
    await _stationProvider.loadStationsByCountry(country);
  }

  Future<void> loadTopStationsIfNeeded() async {
    if (stations.isEmpty) {
      await _stationProvider.loadTopStations(highQuality: _highQuality);
    }
  }

  Future<void> searchStations({String? name, String? tag, int limit = 50}) async {
    if (name != null) {
      await _stationProvider.searchStations(name);
    } else if (tag != null) {
      await _stationProvider.loadStationsByTag(tag, limit: limit, highQuality: _highQuality);
    }
  }

  Future<void> loadTopStations({bool forceRefresh = false}) async {
    await _stationProvider.loadTopStations(forceRefresh: forceRefresh, highQuality: _highQuality);
  }

  Future<void> playStation(RadioStation station) async {
    if (_currentStation == station && _isPlaying) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_isPlaying) {
        await _audioHandler.pause();
        _isPlaying = false;
      }

      if (!_isValidStreamUrl(station.url)) {
        throw Exception('Invalid stream URL');
      }

      // Update MediaItem for Background Notification
      final mediaItem = MediaItem(
        id: station.url,
        album: 'Flux Radio',
        title: station.name,
        artist: station.country,
        artUri: station.favicon.isNotEmpty ? Uri.parse(station.favicon) : null,
      );
      
      _audioHandler.addQueueItem(mediaItem);
      
      if (_audioHandler is RadioAudioHandler) {
        _audioHandler.setMediaItem(mediaItem);
        await _audioHandler.setUrl(station.url).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('Connection timed out'),
        );
      }

      await _audioHandler.play();

      _currentStation = station;
      _isPlaying = true;
      _currentTitle = station.name;

      await _repository.addToRecent(station);
      await loadRecentStations();
    } on TimeoutException catch (_) {
      _errorMessage = 'Station is taking too long to respond. It might be offline.';
      _isPlaying = false;
      _currentStation = null;
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('403')) {
        _errorMessage = 'This station is currently unavailable in your region.';
      } else if (errorStr.contains('404')) {
        _errorMessage = 'The station link seems to be broken.';
      } else if (errorStr.contains('SocketException')) {
        _errorMessage = 'No internet connection. Please check your network.';
      } else {
        _errorMessage = 'Oops! Something went wrong while trying to play this station.';
      }
      _isPlaying = false;
      _currentStation = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> pause() async {
    await _audioHandler.pause();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> resume() async {
    if (_currentStation != null || _currentEpisode != null) {
      await _audioHandler.play();
      _isPlaying = true;
      notifyListeners();
    }
  }

  Future<void> skipNext() async {
    if (_currentStation != null) {
      final list = stations;
      if (list.isEmpty) return;
      int index = list.indexWhere((s) => s.url == _currentStation!.url);
      if (index != -1) {
        int nextIndex = (index + 1) % list.length;
        await playStation(list[nextIndex]);
      }
    } else if (_currentEpisode != null) {
      final list = episodes;
      if (list.isEmpty) return;
      int index = list.indexWhere((e) => e.audio == _currentEpisode!.audio);
      if (index != -1 && index < list.length - 1) {
        await playEpisode(list[index + 1]);
      }
    }
  }

  Future<void> skipPrevious() async {
    if (_currentStation != null) {
      final list = stations;
      if (list.isEmpty) return;
      int index = list.indexWhere((s) => s.url == _currentStation!.url);
      if (index != -1) {
        int prevIndex = (index - 1 + list.length) % list.length;
        await playStation(list[prevIndex]);
      }
    } else if (_currentEpisode != null) {
      final list = episodes;
      if (list.isEmpty) return;
      int index = list.indexWhere((e) => e.audio == _currentEpisode!.audio);
      if (index != -1 && index > 0) {
        await playEpisode(list[index - 1]);
      }
    }
  }

  Future<void> stop() async {
    await _audioHandler.stop();
    _isPlaying = false;
    _currentStation = null;
    _currentTitle = '';
    cancelSleepTimer();
    if (_recordingService.isRecording) {
      await _recordingService.stopRecording();
    }
    notifyListeners();
  }

  // --- Equalizer & Audio Effects ---
  Future<void> _initializeEqualizer() async {
    if (_audioHandler is RadioAudioHandler) {
      final equalizer = _audioHandler.equalizer;
      final parameters = await equalizer.parameters;
      
      _equalizerCenterFrequencies = parameters.bands.map((b) => b.centerFrequency.toInt()).toList();
      
      final savedEq = await RadioStorage().getEqualizer();
      final List<dynamic>? savedBands = savedEq['bands'];
      final double? savedLoudness = savedEq['loudness'];
      
      if (savedBands != null && savedBands.length == _equalizerCenterFrequencies.length) {
        _equalizerBands = savedBands.cast<double>();
        for (int i = 0; i < _equalizerBands.length; i++) {
          if (i < parameters.bands.length) {
            parameters.bands[i].setGain(_equalizerBands[i]);
          }
        }
      } else {
        _equalizerBands = parameters.bands.map((b) => b.gain).toList();
      }
      
      final loudness = _audioHandler.loudnessEnhancer;
      if (savedLoudness != null) {
        _loudnessGain = savedLoudness;
        _audioHandler.loudnessEnhancer.setTargetGain(_loudnessGain);
      } else {
        _loudnessGain = loudness.targetGain;
      }
      
      notifyListeners();
    }
  }

  void updateEqualizerBand(int index, double value) {
    if (index >= 0 && index < _equalizerBands.length) {
      _equalizerBands[index] = value;
      if (_audioHandler is RadioAudioHandler) {
        final equalizer = _audioHandler.equalizer;
        equalizer.parameters.then((parameters) {
          if (index < parameters.bands.length) {
            parameters.bands[index].setGain(value);
            RadioStorage().saveEqualizer(_equalizerBands, _loudnessGain);
          }
        });
      }
      notifyListeners();
    }
  }

  void setLoudnessGain(double value) {
    _loudnessGain = value;
    if (_audioHandler is RadioAudioHandler) {
      _audioHandler.loudnessEnhancer.setTargetGain(value);
      RadioStorage().saveEqualizer(_equalizerBands, _loudnessGain);
    }
    notifyListeners();
  }

  void resetEqualizer() {
    for (int i = 0; i < _equalizerBands.length; i++) {
      _equalizerBands[i] = 0.0;
      if (_audioHandler is RadioAudioHandler) {
        final equalizer = _audioHandler.equalizer;
        equalizer.parameters.then((parameters) {
          if (i < parameters.bands.length) {
            parameters.bands[i].setGain(0.0);
          }
        });
      }
    }
    _loudnessGain = 0.0;
    if (_audioHandler is RadioAudioHandler) {
      _audioHandler.loudnessEnhancer.setTargetGain(0.0);
    }
    RadioStorage().saveEqualizer(_equalizerBands, _loudnessGain);
    notifyListeners();
  }

  // --- Favorites ---
  Future<void> loadFavorites() async {
    _favorites = await _repository.getFavorites();
    notifyListeners();
  }

  Future<void> toggleFavorite(RadioStation station) async {
    final id = station.id;
    if (await RadioStorage().isFavorite(id)) {
      await RadioStorage().removeFavorite(id);
    } else {
      await RadioStorage().addFavorite(station);
    }
    await loadFavorites();
  }

  Future<void> removeFromFavorites(RadioStation station) async {
    await RadioStorage().removeFavorite(station.id);
    await loadFavorites();
  }

  Future<void> addToFavorites(RadioStation station) async {
    await RadioStorage().addFavorite(station);
    await loadFavorites();
  }

  Future<bool> isFavorite(String url, {String? uuid}) async {
    if (uuid != null && uuid.isNotEmpty) return await RadioStorage().isFavorite(uuid);
    // Fallback to generating ID if we don't have a station object
    final id = sha256.convert(utf8.encode(url)).toString().substring(0, 16);
    return await RadioStorage().isFavorite(id);
  }

  // --- Recent ---
  Future<void> loadRecentStations() async {
    _recentStations = await _repository.getRecentStations();
    notifyListeners();
  }

  Future<void> saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    await RadioStorage().addRecentSearch(query);
    await loadRecentSearches();
  }

  Future<void> loadRecentSearches() async {
    final searches = await RadioStorage().getRecentSearches();
    _recentSearches.clear();
    _recentSearches.addAll(searches);
    notifyListeners();
  }

  // --- Alarms ---
  Future<void> addAlarm(RadioAlarm alarm) async {
    await _alarmService.addAlarm(alarm);
  }

  Future<void> deleteAlarm(String id) async {
    await _alarmService.deleteAlarm(id);
  }

  Future<void> toggleAlarm(String id) async {
    await _alarmService.toggleAlarm(id);
  }

  Future<void> getRecentSearches() async {
    await loadRecentSearches();
  }

  // --- Sleep Timer ---
  void startSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepDuration = duration;
    _sleepRemainingTime = duration;
    
    // Original volume to restore after fade or cancellation
    final double originalVolume = _volume;

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _sleepRemainingTime = _sleepRemainingTime - const Duration(seconds: 1);
      
      // Volume fade-out: Linear fade in the last 60 seconds (increased from 30)
      if (_sleepRemainingTime.inSeconds <= 60 && _sleepRemainingTime.inSeconds > 0) {
        double fadeVolume = originalVolume * (_sleepRemainingTime.inSeconds / 60.0);
        // Ensure volume doesn't suddenly jump if user adjusted it during fade
        if (fadeVolume < _volume) {
           _player.setVolume(fadeVolume);
        }
      }

      if (_sleepRemainingTime.inSeconds <= 0) {
        await stop();
        await _player.setVolume(originalVolume); // Reset volume for next time
        _sleepTimer?.cancel();
        _sleepTimer = null;
        _sleepDuration = Duration.zero;
        _sleepRemainingTime = Duration.zero;
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepDuration = Duration.zero;
    _sleepRemainingTime = Duration.zero;
    notifyListeners();
  }

  // --- Recordings ---
  Future<void> startRecording() async {
    if (_currentStation == null) return;
    final success = await _recordingService.startRecording(_currentStation!);
    if (!success) {
      _errorMessage = 'Recording failed. Check permissions.';
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    await _recordingService.stopRecording();
    await loadSavedRecordings();
  }

  Future<void> loadSavedRecordings() async {
    _savedRecordings = await _recordingService.getSavedRecordings();
    notifyListeners();
  }

  // --- Other Methods ---
  Future<void> loadTanzaniaStations() async {
    await _stationProvider.loadTanzaniaStations();
  }

  Future<void> loadMusicStations() async {
    await _stationProvider.loadMusicStations();
  }

  Future<void> loadNewsStations() async {
    await _stationProvider.loadNewsStations();
  }

  Future<void> loadSportsStations() async {
    await _stationProvider.loadSportsStations();
  }

  Future<void> loadTalkStations() async {
    await _stationProvider.loadTalkStations();
  }

  Future<void> loadGlobalAmFmStations() async {
    await _stationProvider.loadGlobalAmFmStations();
  }

  Future<void> loadLiveStations() async {
    await _stationProvider.loadLiveStations();
  }

  Future<void> loadNearbyStations() async {
    await _stationProvider.loadTanzaniaStations(); // Defaulting to TZ for now
  }

  Future<void> checkForUpdates() async {
    await _stationProvider.checkForUpdates();
    notifyListeners();
  }

  Future<void> clearCache() async {
    await RadioStorage().clearCache();
    notifyListeners();
  }

  Future<void> playRecording(String path) async {
    try {
      if (_isPlaying) await _player.pause();
      await _player.setFilePath(path);
      await _player.play();
      _isPlaying = true;
      _currentTitle = path.split('/').last;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Oops! We couldn\'t play this recording.';
      notifyListeners();
    }
  }

  Future<bool> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        await loadSavedRecordings();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Failed to delete recording: $e');
      return false;
    }
  }

  Future<void> reportBrokenStation(String uuid) async {
    try {
      final success = await RadioService().reportStation(uuid);
      if (!success) {
        _errorMessage = 'We couldn\'t submit your report. Please try again later.';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Something went wrong while reporting. Please try again.';
      notifyListeners();
    }
  }

  // --- Podcasts ---
  Future<void> searchPodcasts(String query) async {
    await _stationProvider.searchPodcasts(query);
  }

  Future<void> loadEpisodes(String rssUrl) async {
    await _stationProvider.loadEpisodes(rssUrl);
  }

  Future<void> playEpisode(Episode episode) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_isPlaying) {
        await _audioHandler.pause();
        _isPlaying = false;
      }

      final source = episode.downloadPath != null 
          ? episode.downloadPath! 
          : episode.audio;

      final mediaItem = MediaItem(
        id: source,
        album: 'Podcast',
        title: episode.title,
        artist: 'Flux Radio',
        artUri: episode.image.isNotEmpty ? Uri.parse(episode.image) : null,
        duration: Duration(seconds: episode.duration),
      );
      
      _audioHandler.addQueueItem(mediaItem);
      
      if (_audioHandler is RadioAudioHandler) {
        _audioHandler.setMediaItem(mediaItem);
        if (episode.downloadPath != null) {
          await _audioHandler.player.setFilePath(source);
        } else {
          await _audioHandler.setUrl(source).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Connection timed out'),
          );
        }
      }

      await _audioHandler.play();

      _isPlaying = true;
      _currentTitle = episode.title;
      _currentStation = null;
      _currentEpisode = episode;

    } on TimeoutException catch (_) {
      _errorMessage = 'Episode is taking too long to respond.';
      _isPlaying = false;
    } catch (e) {
      _errorMessage = 'Oops! Something went wrong while trying to play this episode.';
      _isPlaying = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  // --- Downloads ---
  Future<void> downloadEpisode(Episode episode) async {
    final path = await _downloadService.downloadEpisode(episode);
    if (path != null) {
      final updatedEpisode = episode.copyWith(downloadPath: path);
      // We need to persist this in RadioStorage if we want it to survive app restarts
      await RadioStorage().saveDownloadedEpisode(updatedEpisode);
      await _stationProvider.updateEpisode(updatedEpisode);
    }
  }

  Future<void> deleteDownloadedEpisode(Episode episode) async {
    if (episode.downloadPath != null) {
      await _downloadService.deleteEpisode(episode.downloadPath!);
      final updatedEpisode = Episode(
        id: episode.id,
        title: episode.title,
        description: episode.description,
        audio: episode.audio,
        duration: episode.duration,
        pubDate: episode.pubDate,
        image: episode.image,
        downloadPath: null,
      );
      await RadioStorage().removeDownloadedEpisode(episode.id);
      await _stationProvider.updateEpisode(updatedEpisode);
    }
  }

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
    _player.setVolume(_volume);
    RadioStorage().saveSettings('volume', _volume);
    notifyListeners();
  }

  bool _isValidStreamUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _sleepTimer?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _player.dispose();
    _recordingService.removeListener(notifyListeners);
    _alarmService.removeListener(notifyListeners);
    _stationProvider.removeListener(notifyListeners);
    super.dispose();
  }
}
