import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:location/location.dart';
import 'package:path_provider/path_provider.dart';
import '../flux_hardware/radio_service.dart';
import '../flux_storage/radio_storage.dart';

class AudioRecorder {
  Future<bool> hasPermission() async => true;
  Future<void> start({required String path}) async {}
  Future<String?> stop() async => null;
}

class RadioEngine extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final RadioService _service = RadioService();
  final Location _location = Location();
  final AudioRecorder _recorder = AudioRecorder();

  RadioStation? _currentStation;
  String _currentTitle = '';
  bool _isPlaying = false;
  bool _isLoading = false;
  List<RadioStation> _stations = [];
  List<String> _countries = [];
  List<String> _genres = [];
  List<String> _languages = [];
  String? _errorMessage;
  Timer? _sleepTimer;
  Duration _sleepDuration = Duration.zero;
  Duration _sleepRemainingTime = Duration.zero;
  bool _isRecording = false;
  String? _recordingPath;
  DateTime? _recordingStartTime;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  final List<double> _equalizerBands = [0.0, 0.0, 0.0, 0.0, 0.0];
  double _volume = 1.0;
  final Map<String, List<RadioStation>> _cache = {};
  DateTime? _lastCacheUpdate;
  List<RadioStation> _recentStations = [];
  List<String> _savedRecordings = [];

  bool get isSleepTimerActive => _sleepTimer != null;
  bool get isRecording => _isRecording;
  String? get recordingPath => _recordingPath;
  Duration get recordingDuration => _recordingDuration;
  DateTime? get recordingStartTime => _recordingStartTime;
  Duration get sleepRemainingTime => _sleepRemainingTime;
  List<double> get equalizerBands => _equalizerBands;
  List<RadioStation> get recentStations => List.unmodifiable(_recentStations);
  List<String> get savedRecordings => List.unmodifiable(_savedRecordings);

  RadioStation? get currentStation => _currentStation;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String get currentTitle => _currentTitle;
  List<RadioStation> get stations => _stations;
  List<String> get countries => _countries;
  List<String> get genres => _genres;
  List<String> get languages => _languages;

  List<Map<String, dynamic>> get categories => [
        {'title': 'Trending', 'icon': Icons.trending_up, 'color': Colors.red, 'action': loadTrendingStations},
        {'title': 'Tanzania', 'icon': Icons.location_on, 'color': Color(0xFF4CAF50), 'action': loadTanzaniaStations},
        {'title': 'Music', 'icon': Icons.music_note, 'color': Color(0xFF9C27B0), 'action': loadMusicStations},
        {'title': 'Sports', 'icon': Icons.sports_soccer, 'color': Color(0xFF2196F3), 'action': loadSportsStations},
        {'title': 'News', 'icon': Icons.article, 'color': Color(0xFFFF9800), 'action': loadNewsStations},
        {'title': 'AM/FM', 'icon': Icons.radio, 'color': Color(0xFF00BCD4), 'action': loadGlobalAmFmStations},
        {'title': 'Talk', 'icon': Icons.mic, 'color': Color(0xFF795548), 'action': loadTalkStations},
        {'title': 'Live', 'icon': Icons.wifi, 'color': Color(0xFFE91E63), 'action': loadLiveStations},
      ];
  String? get errorMessage => _errorMessage;
  Duration get sleepDuration => _sleepDuration;
  double get volume => _volume;

  Future<void> initialize() async {
    await _loadCountriesGenresAndLanguages();
    await loadTrendingStations();
    await loadRecentStations();
  }

  Future<void> _loadCountriesGenresAndLanguages() async {
    try {
      _countries = await _service.getCountries();
      _genres = await _service.getTags();
      _languages = await _service.getLanguages();
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> searchStations({
    String? name,
    String? country,
    String? tag,
    String? language,
    int? bitrateMin,
    int? bitrateMax,
    bool hasGeoInfo = false,
    String? order = 'votes',
    bool reverse = true,
    int limit = 200, // Reduced default limit for better performance
  }) async {
    // Create cache key from search parameters
    final cacheKey = 'search_${name ?? ''}_${country ?? ''}_${tag ?? ''}_${language ?? ''}_${bitrateMin ?? ''}_${bitrateMax ?? ''}';

    // Check cache first (valid for 15 minutes for search results)
    if (_cache.containsKey(cacheKey) &&
        _lastCacheUpdate != null &&
        DateTime.now().difference(_lastCacheUpdate!).inMinutes < 15) {
      _stations = List.from(_cache[cacheKey]!);
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _stations = await _service.searchStations(
        name: name,
        country: country,
        tag: tag,
        language: language,
        bitrateMin: bitrateMin,
        bitrateMax: bitrateMax,
        hasGeoInfo: hasGeoInfo,
        order: order,
        reverse: reverse,
        limit: limit,
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw Exception('Search timeout'),
      );

      // Cache successful search results
      if (_stations.isNotEmpty) {
        _cache[cacheKey] = List.from(_stations);
        _lastCacheUpdate = DateTime.now();
      }
    } catch (e) {
      _stations = [];
      _errorMessage = 'Search failed: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> playStation(RadioStation station) async {
    if (_currentStation == station && _isPlaying) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Stop current playback before switching
      if (_isPlaying) {
        await _player.pause();
        _isPlaying = false;
      }

      // Set audio source with timeout
      await _player.setUrl(station.url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      // Set volume before playing
      await _player.setVolume(_volume);

      await _player.play();
      _currentStation = station;
      _isPlaying = true;
      _currentTitle = station.name;

      // Add to recent stations and refresh the list
      final storage = RadioStorage();
      await storage.addRecent(station);
      _recentStations = await storage.getRecent();

    } catch (e) {
      _errorMessage = 'Failed to play station: ${e.toString()}';
      _isLoading = false;
      _isPlaying = false;
      _currentStation = null;
      notifyListeners();
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> pause() async {
    try {
      await _player.pause();
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      // Handle pause error gracefully
      _errorMessage = 'Failed to pause: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> resume() async {
    try {
      if (_currentStation != null) {
        await _player.play();
        _isPlaying = true;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to resume: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      _isPlaying = false;
      _currentStation = null;
      _currentTitle = '';
      cancelSleepTimer();
      if (_isRecording) {
        await stopRecording();
      }
      notifyListeners();
    } catch (e) {
      // Handle stop error gracefully
      _errorMessage = 'Failed to stop: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> loadTopStations() async {
    const cacheKey = 'top_stations';

    // Check cache first (valid for 30 minutes)
    if (_cache.containsKey(cacheKey) &&
        _lastCacheUpdate != null &&
        DateTime.now().difference(_lastCacheUpdate!).inMinutes < 30) {
      _stations = List.from(_cache[cacheKey]!);
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _stations = await _service.getTopStations(limit: 1000).timeout(
        const Duration(seconds: 10), // Reduced timeout
        onTimeout: () => throw Exception('Loading timeout'),
      );

      // Cache the results
      _cache[cacheKey] = List.from(_stations);
      _lastCacheUpdate = DateTime.now();
    } catch (e) {
      _errorMessage = 'Failed to load stations: ${e.toString()}';

      // Try fallback with cached data first
      if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.isNotEmpty) {
        _stations = List.from(_cache[cacheKey]!);
        _errorMessage = 'Using cached data - ${e.toString()}';
      } else {
        // Try fallback with trending stations
        try {
          _stations = await _service.getTrendingStations(limit: 500);
          _errorMessage = null; // Clear error if fallback succeeds
        } catch (fallbackError) {
          _stations = [];
        }
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTrendingStations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _stations = await _service.getTrendingStations(limit: 1000);
    } catch (e) {
      _stations = [];
      _errorMessage = 'Failed to load stations';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadLiveStations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _stations = await _service.getLiveStations(limit: 1000);
    } catch (e) {
      _stations = [];
      _errorMessage = 'Failed to load stations';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadGlobalAmFmStations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _stations = await _service.getGlobalAmFmStations(limit: 1000);
    } catch (e) {
      _stations = [];
      _errorMessage = 'Failed to load stations';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadStationsByLanguage(String language) async {
    _isLoading = true;
    notifyListeners();
    try {
      _stations = await _service.getStationsByLanguage(language, limit: 200);
    } catch (e) {
      _stations = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadDiscoverStations() async {
    _isLoading = true;
    notifyListeners();
    try {
      final trending = await _service.getTrendingStations(limit: 150);
      final tanzania = await _service.getTanzaniaStations(limit: 150);
      _stations = [...trending, ...tanzania].take(300).toList();
    } catch (e) {
      _stations = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadStationsByCountry(String country) async {
    _isLoading = true;
    notifyListeners();
    try {
      _stations = await _service.getStationsByCountry(country, limit: 200);
    } catch (e) {
      _stations = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadStationsByGenre(String genre) async {
    _isLoading = true;
    notifyListeners();
    try {
      _stations = await _service.getStationsByGenre(genre, limit: 200);
    } catch (e) {
      _stations = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMusicStations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _stations = await _service.getMusicStations(limit: 1500);
    } catch (e) {
      _stations = [];
      _errorMessage = 'Failed to load stations';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadNewsStations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _stations = await _service.getNewsStations(limit: 1000);
    } catch (e) {
      _stations = [];
      _errorMessage = 'Failed to load stations';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadSportsStations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _stations = await _service.getSportsStations(limit: 1000);
    } catch (e) {
      _stations = [];
      _errorMessage = 'Failed to load stations';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTalkStations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _stations = await _service.getTalkStations(limit: 1000);
    } catch (e) {
      _stations = [];
      _errorMessage = 'Failed to load stations';
    }
    _isLoading = false;
    notifyListeners();
  }

  void startSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepDuration = duration;
    _sleepRemainingTime = duration;
    
    // Update remaining time every second
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _sleepRemainingTime = _sleepRemainingTime - const Duration(seconds: 1);
      if (_sleepRemainingTime.inSeconds <= 0) {
        stop();
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

  Future<void> loadNearbyStations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final locationData = await _location.getLocation();
      _stations = await _service.getNearbyStations(
        lat: locationData.latitude!,
        lon: locationData.longitude!,
        limit: 500,
      );
    } catch (e) {
      // Fallback to Tanzania stations
      await loadTanzaniaStations();
      return;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTanzaniaStations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _stations = await _service.getTanzaniaStations(limit: 500);
    } catch (e) {
      _stations = [];
      _errorMessage = 'Failed to load stations';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> startRecording() async {
    if (await _recorder.hasPermission()) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final recordingsDir = Directory('${dir.path}/recordings');
        if (!await recordingsDir.exists()) {
          await recordingsDir.create(recursive: true);
        }
        
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filename = _currentStation?.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_') ?? 'recording';
        final path = '${recordingsDir.path}/${filename}_$timestamp.m4a';
        
        await _recorder.start(path: path);
        _isRecording = true;
        _recordingPath = path;
        _recordingStartTime = DateTime.now();
        _recordingDuration = Duration.zero;
        
        // Update recording duration every second
        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_recordingStartTime != null) {
            _recordingDuration = DateTime.now().difference(_recordingStartTime!);
          }
          notifyListeners();
        });
        
        notifyListeners();
      } catch (e) {
        _errorMessage = 'Failed to start recording: ${e.toString()}';
        notifyListeners();
      }
    }
  }

  Future<void> stopRecording() async {
    try {
      _recordingTimer?.cancel();
      _recordingTimer = null;
      final path = await _recorder.stop();
      _isRecording = false;
      _recordingPath = path;
      _recordingStartTime = null;
      
      if (path != null && !_savedRecordings.contains(path)) {
        _savedRecordings.add(path);
      }
      
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to stop recording: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<bool> exportRecording(String sourcePath, String destinationPath) async {
    try {
      final sourceFile = File(sourcePath);
      if (await sourceFile.exists()) {
        await sourceFile.copy(destinationPath);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Failed to export recording: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        _savedRecordings.remove(path);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Failed to delete recording: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<void> loadSavedRecordings() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${dir.path}/recordings');
      if (await recordingsDir.exists()) {
        final files = recordingsDir.listSync();
        _savedRecordings = files
            .whereType<File>()
            .map((f) => f.path)
            .toList();
        notifyListeners();
      }
    } catch (e) {
      // Handle error
    }
  }

  void updateEqualizerBand(int index, double value) {
    if (index >= 0 && index < _equalizerBands.length) {
      _equalizerBands[index] = value;
      // Apply to audio player if supported
      notifyListeners();
    }
  }

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
    _player.setVolume(_volume);
    notifyListeners();
  }

  // Getters for player properties
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  Duration get bufferedPosition => _player.bufferedPosition;

  Future<void> addToFavorites(RadioStation station) async {
    final storage = RadioStorage();
    await storage.addFavorite(station);
    notifyListeners();
  }

  Future<void> removeFromFavorites(String id) async {
    final storage = RadioStorage();
    await storage.removeFavorite(id);
    notifyListeners();
  }

  Future<List<FavoriteStation>> getFavorites() async {
    final storage = RadioStorage();
    return await storage.getFavorites();
  }

  Future<bool> isFavorite(String id) async {
    final storage = RadioStorage();
    return await storage.isFavorite(id);
  }

  Future<void> loadRecentStations() async {
    final storage = RadioStorage();
    _recentStations = await storage.getRecent();
    notifyListeners();
  }

  // Cache management
  void clearCache() {
    _cache.clear();
    _lastCacheUpdate = null;
    notifyListeners();
  }



  @override
  void dispose() {
    _player.dispose();
    _sleepTimer?.cancel();
    _recordingTimer?.cancel();
    _cache.clear(); // Clear cache on dispose
    super.dispose();
  }
}