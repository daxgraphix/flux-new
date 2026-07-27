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

enum SearchType { station, podcast }

class RadioEngine extends ChangeNotifier {
  final RadioAudioHandler _audioHandler;
  final RecordingService _recordingService;
  final AlarmService _alarmService;
  final StationProvider _stationProvider;
  final DownloadService _downloadService;
  AudioPlayer get _player => _audioHandler.player;
  final RadioRepository _repository = RadioRepository();

  RadioStation? _currentStation;
  Episode? _currentEpisode;
  String _currentTitle = '';
  String _currentSubtitle = '';
  bool _isPlaying = false;
  
  List<double> _equalizerBands = [0.0, 0.0, 0.0, 0.0, 0.0];
  List<int> _equalizerCenterFrequencies = [60, 230, 910, 3600, 14000];
  double _loudnessGain = 0.0;
  double _bassBoostStrength = 0.0;
  double _speed = 1.0;
  double _pitch = 1.0;
  double _volume = 1.0;
  List<RadioStation> _recentStations = [];
  List<FavoriteStation> _favorites = [];
  List<Episode> _downloadedEpisodes = [];
  List<String> _savedRecordings = [];
  final List<String> _recentSearches = [];
  bool _autoPlay = true;
  bool _highQuality = false;
  bool _dataSaver = false;
  bool _notificationsEnabled = true;
  String _language = 'en';
  int _cacheSize = 100;
  
  bool _isNetworkAvailable = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  // Timer? _updateTimer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _mediaItemSubscription;
  SearchType _searchType = SearchType.station;
  Timer? _sleepTimer;
  Duration? _sleepTimerDuration;

  AudioPlayer get player => _player;
  Duration get position => _position;
  Duration get duration => _duration;
  Duration? get sleepTimerDuration => _sleepTimerDuration;
  bool get isNetworkAvailable => _isNetworkAvailable;
  bool get isRecording => _recordingService.isRecording;
  String? get recordingPath => _recordingService.recordingPath;
  Duration get recordingDuration => _recordingService.recordingDuration;
  DateTime? get recordingStartTime => _recordingService.recordingStartTime;
  List<double> get equalizerBands => List.unmodifiable(_equalizerBands);
  List<int> get equalizerCenterFrequencies => List.unmodifiable(_equalizerCenterFrequencies);
  double get loudnessGain => _loudnessGain;
  double get bassBoostStrength => _bassBoostStrength;
  double get speed => _speed;
  double get pitch => _pitch;
  List<RadioStation> get recentStations => List.unmodifiable(_recentStations);
  List<FavoriteStation> get favorites => List.unmodifiable(_favorites);
  List<RadioStation> get favoriteStations => _favorites.map((f) => f.toRadioStation()).toList();
  List<Episode> get downloadedEpisodes => List.unmodifiable(_downloadedEpisodes);
  List<String> get savedRecordings => List.unmodifiable(_savedRecordings);
  List<String> get recentSearches => List.unmodifiable(_recentSearches);
  bool get autoPlay => _autoPlay;
  bool get highQuality => _highQuality;
  bool get dataSaver => _dataSaver;
  bool get notificationsEnabled => _notificationsEnabled;
  String get language => _language;
  int get cacheSize => _cacheSize;
  List<RadioAlarm> get alarms => _alarmService.alarms;
  bool _isLoading = false;
  String? _errorMessage;
  String? get errorMessage => _errorMessage ?? _stationProvider.errorMessage;
  RadioStation? get currentStation => _currentStation;
  Episode? get currentEpisode => _currentEpisode;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading || _stationProvider.isLoading;
  String get currentTitle => _currentTitle;
  String get currentSubtitle => _currentSubtitle;
  List<RadioStation> get stations => _stationProvider.stations;
  List<Podcast> get podcasts => _stationProvider.podcasts;
  List<Episode> get episodes => _stationProvider.episodes;
  List<String> get countries => _stationProvider.countries;
  List<String> get genres => _stationProvider.genres;
  List<String> get languages => _stationProvider.languages;
  double get volume => _volume;
  SearchType get searchType => _searchType;

  // Download states delegation
  double getDownloadProgress(String id) => _downloadService.getDownloadProgress(id);
  bool isDownloading(String id) => _downloadService.isDownloading(id);

  RadioEngine(this._audioHandler, this._recordingService, this._alarmService, this._stationProvider, this._downloadService) {
    _recordingService.addListener(notifyListeners);
    _alarmService.addListener(notifyListeners);
    _stationProvider.addListener(notifyListeners);
    _downloadService.addListener(notifyListeners);
    
    // Set up storage error reporting
    RadioStorage.onError = (error) {
      _errorMessage = error;
      notifyListeners();
    };
  }

  Future<void> initialize() async {
    await RadioStorage().init();
    await _loadSettings();
    await _stationProvider.initialize();
    await loadRecentStations();
    await loadFavorites();
    await loadDownloadedEpisodes();
    await _alarmService.initialize();
    await _configureAudioSession();
    await loadSavedRecordings();
    await loadRecentSearches();
    await _initializeEqualizer();
    _startNetworkMonitoring();
    // _startBackgroundUpdates();
    
    await _restoreLastPlayed();
    
    if (_autoPlay && _isPlaying == false && _currentStation != null) {
       playStation(_currentStation!);
    }
  }

  Future<void> _restoreLastPlayed() async {
    final lastPlayed = await RadioStorage().getLastPlayed();
    if (lastPlayed != null) {
      final type = lastPlayed['type'];
      final item = lastPlayed['item'];
      if (type == 'station') {
        _currentStation = RadioStation.fromJson(item);
        _currentTitle = _currentStation!.name;
        _currentSubtitle = [_currentStation!.country, _currentStation!.genre].where((s) => s.isNotEmpty).join(' • ');
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

  Future<void> _loadSettings() async {
    _autoPlay = await RadioStorage().getSettings<bool>('auto_play', defaultValue: true) ?? true;
    _highQuality = await RadioStorage().getSettings<bool>('high_quality', defaultValue: false) ?? false;
    _dataSaver = await RadioStorage().getSettings<bool>('data_saver', defaultValue: false) ?? false;
    _notificationsEnabled = await RadioStorage().getSettings<bool>('notifications_enabled', defaultValue: true) ?? true;
    _language = await RadioStorage().getSettings<String>('language', defaultValue: 'en') ?? 'en';
    _cacheSize = await RadioStorage().getSettings<int>('cache_size', defaultValue: 100) ?? 100;
    _volume = await RadioStorage().getSettings<double>('volume', defaultValue: 1.0) ?? 1.0;
    await _player.setVolume(_volume);
  }

  Future<void> _configureAudioSession() async {
    _positionSubscription = _player.positionStream.listen((p) {
      _position = p;
      if (_currentEpisode != null && p.inSeconds > 0 && p.inSeconds % 5 == 0) {
        RadioStorage().updateEpisodePosition(
          _currentEpisode!.id, 
          p.inSeconds,
          episode: _currentEpisode
        );
      }
      notifyListeners();
    });
    _durationSubscription = _player.durationStream.listen((d) {
      _duration = d ?? Duration.zero;
      notifyListeners();
    });
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        skipNext();
      }
      notifyListeners();
    });
    _mediaItemSubscription = _audioHandler.mediaItem.listen((item) {
       // Sync with background media item if needed
    });
  }

  void _startNetworkMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      _isNetworkAvailable = result.any((r) => r != ConnectivityResult.none);
      notifyListeners();
    });
  }

  Future<void> saveSettings(String key, dynamic value) async {
    await RadioStorage().saveSettings(key, value);
    await _loadSettings();
    notifyListeners();
  }

  Future<void> resume() async {
    if (_currentStation != null || _currentEpisode != null) {
      await _audioHandler.play();
      _isPlaying = true;
      notifyListeners();
    }
  }

  Future<void> playStation(RadioStation station) async {
    if (_currentStation?.url == station.url && _isPlaying) return;

    _isLoading = true;
    _errorMessage = null;
    _currentStation = station; // Set early so UI knows what we're loading
    _currentTitle = station.name;
    _currentSubtitle = [station.country, station.genre].where((s) => s.isNotEmpty).join(' • ');
    _currentEpisode = null;
    notifyListeners();

    try {
      if (_isPlaying) {
        await _audioHandler.pause();
        _isPlaying = false;
      }

      await RadioStorage().saveLastPlayed('station', station.toJson());

      if (!_isValidStreamUrl(station.url)) {
        throw Exception('Invalid stream URL');
      }

      // Update MediaItem for Background Notification
      final subtitle = [station.country, station.genre].where((s) => s.isNotEmpty).join(' • ');
      final mediaItem = MediaItem(
        id: station.url,
        album: 'Flux Radio',
        title: station.name,
        artist: subtitle,
        artUri: station.favicon.isNotEmpty ? Uri.parse(station.favicon) : null,
        extras: {'type': 'station', 'station': jsonEncode(station.toJson())},
      );
      
      await _audioHandler.setUrl(station.url, mediaItem).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Connection timed out'),
      );

      await _audioHandler.play();

      _isPlaying = true;

      await _repository.addToRecent(station);
      await loadRecentStations();
    } on TimeoutException catch (_) {
      _errorMessage = 'Station is taking too long to respond. It might be offline.';
      _isPlaying = false;
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
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> pause() async {
    await _audioHandler.pause();
    _isPlaying = false;
    if (_currentEpisode != null) {
      await RadioStorage().updateEpisodePosition(
        _currentEpisode!.id, 
        _position.inSeconds,
        episode: _currentEpisode
      );
    }
    notifyListeners();
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
    if (_currentEpisode != null) {
      await RadioStorage().updateEpisodePosition(
        _currentEpisode!.id, 
        _position.inSeconds,
        episode: _currentEpisode
      );
    }
    await _audioHandler.stop();
    _isPlaying = false;
    _currentStation = null;
    _currentEpisode = null;
    _currentTitle = '';
    _currentSubtitle = '';
    if (_recordingService.isRecording) {
      await _recordingService.stopRecording();
    }
    notifyListeners();
  }

  // --- Equalizer & Audio Effects ---
  Future<void> _initializeEqualizer() async {
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

    final savedBass = savedEq['bass_boost'];
    if (savedBass != null) {
      _bassBoostStrength = savedBass;
      // _audioHandler.bassBoost.setEnabled(_bassBoostStrength > 0);
      // _audioHandler.bassBoost.setStrength(_bassBoostStrength.round());
    }

    _speed = await RadioStorage().getSettings<double>('speed', defaultValue: 1.0) ?? 1.0;
    _pitch = await RadioStorage().getSettings<double>('pitch', defaultValue: 1.0) ?? 1.0;
    await _player.setSpeed(_speed);
    await _player.setPitch(_pitch);
    
    notifyListeners();
  }

  void updateEqualizerBand(int index, double value) {
    if (index >= 0 && index < _equalizerBands.length) {
      _equalizerBands[index] = value;
      final equalizer = _audioHandler.equalizer;
      equalizer.parameters.then((parameters) {
        if (index < parameters.bands.length) {
          parameters.bands[index].setGain(value);
          RadioStorage().saveEqualizer(_equalizerBands, _loudnessGain, bass: _bassBoostStrength, speed: _speed, pitch: _pitch);
        }
      });
      notifyListeners();
    }
  }

  Future<void> setHighQuality(bool value) async {
    _highQuality = value;
    await RadioStorage().saveSettings('high_quality', value);
    notifyListeners();
  }

  Future<void> setAutoPlay(bool value) async {
    _autoPlay = value;
    await RadioStorage().saveSettings('auto_play', value);
    notifyListeners();
  }

  Future<void> setDataSaver(bool value) async {
    _dataSaver = value;
    await RadioStorage().saveSettings('data_saver', value);
    notifyListeners();
  }

  Future<void> setCacheSize(int value) async {
    _cacheSize = value;
    await RadioStorage().saveSettings('cache_size', value);
    notifyListeners();
  }

  void setSearchType(SearchType type) {
    _searchType = type;
    notifyListeners();
  }

  Future<void> search(String query) async {
    if (_searchType == SearchType.station) {
      await searchStations(query);
    } else {
      await searchPodcasts(query);
    }
  }

  Future<void> searchStations(String? query, {String? tag, int limit = 100}) async {
    if (tag != null) {
      await _stationProvider.loadStationsByTag(tag, limit: limit, highQuality: _highQuality);
    } else if (query != null) {
      await _stationProvider.searchStations(query, highQuality: _highQuality);
    }
  }

  Future<void> loadTrendingStations() async {
    await _stationProvider.loadTrendingStations();
  }

  Future<void> loadTopStations() async {
    await _stationProvider.loadTopStations(highQuality: _highQuality);
  }

  Future<void> loadTopStationsIfNeeded() async {
    if (_stationProvider.stations.isEmpty) {
      await loadTopStations();
    }
  }

  Future<void> loadStationsByCountry(String country) async {
    await _stationProvider.loadStationsByCountry(country);
  }

  void setLoudnessGain(double value) {
    _loudnessGain = value;
    _audioHandler.loudnessEnhancer.setTargetGain(value);
    RadioStorage().saveEqualizer(_equalizerBands, _loudnessGain, bass: _bassBoostStrength, speed: _speed, pitch: _pitch);
    notifyListeners();
  }

  void setBassBoostStrength(double value) {
    _bassBoostStrength = value;
    // _audioHandler.bassBoost.setEnabled(value > 0);
    // _audioHandler.bassBoost.setStrength(value.round());
    RadioStorage().saveEqualizer(_equalizerBands, _loudnessGain, bass: _bassBoostStrength, speed: _speed, pitch: _pitch);
    notifyListeners();
  }

  void setPlaybackSpeed(double value) {
    _speed = value;
    _player.setSpeed(value);
    RadioStorage().saveSettings('speed', value);
    notifyListeners();
  }

  void setPlaybackPitch(double value) {
    _pitch = value;
    _player.setPitch(value);
    RadioStorage().saveSettings('pitch', value);
    notifyListeners();
  }

  void resetEqualizer() {
    for (int i = 0; i < _equalizerBands.length; i++) {
      _equalizerBands[i] = 0.0;
      final equalizer = _audioHandler.equalizer;
      equalizer.parameters.then((parameters) {
        if (i < parameters.bands.length) {
          parameters.bands[i].setGain(0.0);
        }
      });
    }
    _loudnessGain = 0.0;
    _audioHandler.loudnessEnhancer.setTargetGain(0.0);
    _bassBoostStrength = 0.0;
    // _audioHandler.bassBoost.setEnabled(false);
    // _audioHandler.bassBoost.setStrength(0);
    _speed = 1.0;
    _player.setSpeed(1.0);
    _pitch = 1.0;
    _player.setPitch(1.0);
    RadioStorage().saveEqualizer(_equalizerBands, _loudnessGain, bass: 0.0, speed: 1.0, pitch: 1.0);
    notifyListeners();
  }

  // --- Favorites ---
  Future<void> loadFavorites() async {
    _favorites = await _repository.getFavorites();
    notifyListeners();
  }

  Future<void> loadDownloadedEpisodes() async {
    _downloadedEpisodes = await RadioStorage().getDownloadedEpisodes();
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

  Future<void> clearFavorites() async {
    await RadioStorage().clearFavorites();
    await loadFavorites();
  }

  Future<void> addToFavorites(RadioStation station) async {
    await RadioStorage().addFavorite(station);
    await loadFavorites();
  }

  Future<bool> isFavorite(String url, {String? uuid}) async {
    if (uuid != null && uuid.isNotEmpty) return await RadioStorage().isFavorite(uuid);
    final id = sha256.convert(utf8.encode(url)).toString().substring(0, 16);
    return await RadioStorage().isFavorite(id);
  }

  // --- Recent ---
  Future<void> loadRecentStations() async {
    _recentStations = await _repository.getRecentStations();
    notifyListeners();
  }

  Future<void> clearRecentStations() async {
    await RadioStorage().clearRecent();
    await loadRecentStations();
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

  Future<void> removeRecentSearch(String query) async {
    await RadioStorage().removeRecentSearch(query);
    await loadRecentSearches();
  }

  Future<void> clearRecentSearches() async {
    await RadioStorage().clearRecentSearches();
    await loadRecentSearches();
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

  Future<void> loadKenyaStations() async {
    await _stationProvider.loadKenyaStations();
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
    await _stationProvider.loadTanzaniaStations();
  }

  Future<void> loadUgandaStations() async {
    await _stationProvider.loadStationsByCountry('Uganda');
  }

  Future<void> loadRwandaStations() async {
    await _stationProvider.loadStationsByCountry('Rwanda');
  }

  Future<void> checkForUpdates() async {
    await _stationProvider.checkForUpdates();
    notifyListeners();
  }

  Future<void> clearCache() async {
    await RadioStorage().clearCache();
    notifyListeners();
  }

  Future<void> resetSettings() async {
    await RadioStorage().saveSettings('auto_play', true);
    await RadioStorage().saveSettings('high_quality', false);
    await RadioStorage().saveSettings('data_saver', false);
    await RadioStorage().saveSettings('notifications_enabled', true);
    await RadioStorage().saveSettings('language', 'en');
    await RadioStorage().saveSettings('cache_size', 100);
    await RadioStorage().saveSettings('volume', 1.0);
    await _loadSettings();
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

  void clearError() {
    _errorMessage = null;
    _stationProvider.clearError();
    notifyListeners();
  }

  // --- Podcasts ---
  Future<void> searchPodcasts(String query) async {
    await _stationProvider.searchPodcasts(query);
  }

  Future<void> loadTrendingPodcasts() async {
    await _stationProvider.loadTrendingPodcasts();
  }

  Future<void> loadEpisodes(String rssUrl) async {
    await _stationProvider.loadEpisodes(rssUrl);
  }

  Future<void> playEpisode(Episode episode) async {
    _isLoading = true;
    _errorMessage = null;
    _currentEpisode = episode;
    _currentTitle = episode.title;
    _currentSubtitle = 'Podcast';
    _currentStation = null;
    notifyListeners();

    try {
      if (_isPlaying) {
        await _audioHandler.pause();
        _isPlaying = false;
      }

      await RadioStorage().saveLastPlayed('episode', episode.toJson());

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
        extras: {'type': 'episode'},
      );
      
      await _audioHandler.setUrl(source, mediaItem).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Connection timed out'),
      );

      final lastPosition = await RadioStorage().getEpisodePosition(episode.id);
      if (lastPosition > 0) {
        await _player.seek(Duration(seconds: lastPosition));
      } else if (episode.lastPosition > 0) {
        await _player.seek(Duration(seconds: episode.lastPosition));
      }

      await _audioHandler.play();
      _isPlaying = true;

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
      await RadioStorage().saveDownloadedEpisode(updatedEpisode);
      await _stationProvider.updateEpisode(updatedEpisode);
      await loadDownloadedEpisodes();
    } else {
      _errorMessage = 'Download failed for "${episode.title}". Please try again.';
      notifyListeners();
    }
  }

  Future<void> cancelDownload(String id) async {
    _downloadService.cancelDownload(id);
    notifyListeners();
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
      await loadDownloadedEpisodes();
    }
  }

  Future<void> clearAllDownloads() async {
    await _downloadService.clearAllDownloads();
    await RadioStorage().clearAllDownloadedEpisodes();
    await loadDownloadedEpisodes();
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
    await RadioStorage().saveSettings('volume', _volume);
    notifyListeners();
  }

  Future<void> playStream(String url, String name, {String? favicon}) async {
    _isLoading = true;
    _errorMessage = null;
    
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
        _isPlaying = false;
      }

      final mediaItem = MediaItem(
        id: url,
        album: 'Flux Radio',
        title: name,
        artist: 'Streema Global Stream',
        artUri: favicon != null && favicon.isNotEmpty ? Uri.parse(favicon) : null,
        extras: {'type': 'station'},
      );

      await _audioHandler.setUrl(url, mediaItem).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Connection timed out'),
      );

      await _audioHandler.play();
      _isPlaying = true;
    } catch (e) {
      _errorMessage = 'Failed to play Streema stream: ${e.toString()}';
      _isPlaying = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  bool _isValidStreamUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
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

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimerDuration = duration;
    if (duration != null) {
      _sleepTimer = Timer(duration, () {
        pause();
        _sleepTimerDuration = null;
        notifyListeners();
      });
      
      // Update the remaining time every second
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_sleepTimerDuration == null || !(_sleepTimer?.isActive ?? false)) {
          timer.cancel();
          return;
        }
        _sleepTimerDuration = _sleepTimerDuration! - const Duration(seconds: 1);
        notifyListeners();
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
    if (_currentEpisode != null && _isPlaying) {
      RadioStorage().updateEpisodePosition(
        _currentEpisode!.id, 
        _position.inSeconds,
        episode: _currentEpisode
      );
    }
    _connectivitySubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _mediaItemSubscription?.cancel();
    _player.dispose();
    _recordingService.removeListener(notifyListeners);
    _alarmService.removeListener(notifyListeners);
    _stationProvider.removeListener(notifyListeners);
    super.dispose();
  }
}
