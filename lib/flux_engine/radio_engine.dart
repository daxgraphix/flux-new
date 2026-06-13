import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:location/location.dart';
import 'package:path_provider/path_provider.dart';
import '../flux_hardware/radio_service.dart';
import '../flux_storage/radio_storage.dart';

class RadioEngine extends ChangeNotifier {
  final http.Client _httpClient = http.Client();
  final AudioPlayer _player = AudioPlayer();
  final RadioService _service = RadioService();
  final Location _location = Location();

  RadioStation? _currentStation;
  String _currentTitle = '';
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _loadingKey;
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
  List<String> _recentSearches = [];
  late RadioStorage storage;
  
  HttpClient? _recordingClient;
  HttpClientRequest? _recordingRequest;
  HttpClientResponse? _recordingResponse;
  IOSink? _recordingSink;

  bool _isNetworkAvailable = true;
  Timer? _networkCheckTimer;

  AudioPlayer get player => _player;
  bool get isNetworkAvailable => _isNetworkAvailable;

  bool get isSleepTimerActive => _sleepTimer != null;
  bool get isRecording => _isRecording;
  String? get recordingPath => _recordingPath;
  Duration get recordingDuration => _recordingDuration;
  DateTime? get recordingStartTime => _recordingStartTime;
  Duration get sleepRemainingTime => _sleepRemainingTime;
  List<double> get equalizerBands => List.unmodifiable(_equalizerBands);
  List<RadioStation> get recentStations => List.unmodifiable(_recentStations);
  List<String> get savedRecordings => List.unmodifiable(_savedRecordings);
  List<String> get recentSearches => List.unmodifiable(_recentSearches);
  String? get errorMessage => _errorMessage;
  String? get loadingKey => _loadingKey;

RadioStation? get currentStation => _currentStation;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String get currentTitle => _currentTitle;
  List<RadioStation> get stations => _stations;
  List<String> get countries => _countries;
  List<String> get genres => _genres;
  List<String> get languages => _languages;
  double get volume => _volume;

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
   Duration get sleepDuration => _sleepDuration;

  Future<void> initialize() async {
    storage = RadioStorage();
    await _loadCountriesGenresAndLanguages();
    await Future.wait([
      loadTrendingStations(),
      loadTanzaniaStations(),
      loadMusicStations(),
    ]);
    await loadRecentStations();
    await _configureAudioSession();
    await loadSavedRecordings();
    _startNetworkMonitoring();
  }

  void _startNetworkMonitoring() {
    _networkCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final wasAvailable = _isNetworkAvailable;
      _isNetworkAvailable = await _checkNetwork();
      
      if (wasAvailable && !_isNetworkAvailable && _isPlaying) {
        _errorMessage = 'Network lost. Pausing playback.';
        await _player.pause();
        _isPlaying = false;
        notifyListeners();
      } else if (!wasAvailable && _isNetworkAvailable && _currentStation != null && !_isPlaying) {
        try {
          await _player.play();
          _isPlaying = true;
          _errorMessage = null;
          notifyListeners();
        } catch (e) {
          _errorMessage = 'Failed to resume playback';
          notifyListeners();
        }
      }
    });
  }

  Future<bool> _checkNetwork() async {
    try {
      final response = await http.Client().get(Uri.parse('https://www.google.com'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> _configureAudioSession() async {
    await _player.setVolume(_volume);
  }

  Future<void> _loadCountriesGenresAndLanguages() async {
    try {
      _countries = await _service.getCountries();
      _genres = await _service.getTags();
      _languages = await _service.getLanguages();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load countries/genres: ${e.toString()}';
      notifyListeners();
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
    int limit = 50,
    int offset = 0,
  }) async {
    final cacheKey = 'search_${name ?? ''}_${country ?? ''}_${tag ?? ''}_${language ?? ''}_${bitrateMin ?? ''}_${bitrateMax ?? ''}_$offset';

    if (_cache.containsKey(cacheKey) &&
        _lastCacheUpdate != null &&
        DateTime.now().difference(_lastCacheUpdate!).inMinutes < 15) {
      _stations = List.from(_cache[cacheKey]!);
      notifyListeners();
      return;
    }

    final cached = await storage.getCachedStations(cacheKey, minutes: 30);
    if (cached != null) {
      _stations = cached;
      _cache[cacheKey] = cached;
      _lastCacheUpdate = DateTime.now();
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _stations = await _withRetry(
        () => _service.searchStations(
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
          offset: offset,
        ).timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw Exception('Search timeout'),
        ),
        maxAttempts: 3,
      );

      if (_stations.isNotEmpty) {
        _cache[cacheKey] = List.from(_stations);
        _lastCacheUpdate = DateTime.now();
        await storage.cacheStations(cacheKey, _stations);
      }
    } catch (e) {
      _stations = [];
      _errorMessage = 'Search failed: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<T> _withRetry<T>(Future<T> Function() operation, {int maxAttempts = 3}) async {
    int attempts = 0;
    Exception? lastError;
    
    while (attempts < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        lastError = e as Exception?;
        attempts++;
        if (attempts < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 500 * attempts));
        }
      }
    }
    throw lastError ?? Exception('Unknown error');
  }

  Future<void> playStation(RadioStation station) async {
    if (_currentStation == station && _isPlaying) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_isPlaying) {
        await _player.pause();
        _isPlaying = false;
      }

      // Validate URL first
      if (!_isValidStreamUrl(station.url)) {
        throw Exception('Invalid stream URL');
      }

      // Retry logic with backoff
      int attempts = 0;
      final maxAttempts = 3;
      Exception? lastError;

      while (attempts < maxAttempts) {
        try {
          await _player.setUrl(station.url).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Connection timeout'),
          );
          break;
        } catch (e) {
          lastError = e as Exception;
          attempts++;
          if (attempts < maxAttempts) {
            await Future.delayed(Duration(milliseconds: 500 * attempts));
          }
        }
      }

      if (attempts == maxAttempts && lastError != null) {
        throw lastError;
      }

      await _player.setVolume(_volume);

      await _player.play();
      _currentStation = station;
      _isPlaying = true;
      _currentTitle = station.name;

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

  Future<void> ensurePlaying() async {
    if (_currentStation != null && !_isPlaying) {
      try {
        await _player.play();
        _isPlaying = true;
        notifyListeners();
      } catch (e) {
        _errorMessage = 'Failed to resume playback: ${e.toString()}';
        notifyListeners();
      }
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
      _errorMessage = 'Failed to stop: ${e.toString()}';
      notifyListeners();
    }
  }

Future<void> loadTopStations() async {
    const cacheKey = 'top_stations';
    _loadingKey = cacheKey;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    final storage = RadioStorage();

    if (_cache.containsKey(cacheKey) &&
        _lastCacheUpdate != null &&
        DateTime.now().difference(_lastCacheUpdate!).inMinutes < 30) {
      _stations = List.from(_cache[cacheKey]!);
      _loadingKey = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    final cached = await storage.getCachedStations(cacheKey, minutes: 30);
    if (cached != null) {
      _stations = cached;
      _cache[cacheKey] = cached;
      _lastCacheUpdate = DateTime.now();
      _loadingKey = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      _stations = await _service.getTopStations(limit: 100).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Loading timeout'),
      );

      _cache[cacheKey] = List.from(_stations);
      _lastCacheUpdate = DateTime.now();
      await storage.cacheStations(cacheKey, _stations);
    } catch (e) {
      _errorMessage = 'Failed to load stations: ${e.toString()}';

      if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.isNotEmpty) {
        _stations = List.from(_cache[cacheKey]!);
        _errorMessage = 'Using cached data - ${e.toString()}';
      } else {
        try {
          _stations = await _service.getTrendingStations(limit: 50);
          _errorMessage = null;
        } catch (fallbackError) {
          _stations = [];
        }
      }
    }

    _loadingKey = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTopStationsIfNeeded() async {
    const cacheKey = 'top_stations';
    if (_cache.containsKey(cacheKey) &&
        _lastCacheUpdate != null &&
        DateTime.now().difference(_lastCacheUpdate!).inMinutes < 30) {
      return;
    }
    loadTopStations();
  }

  Future<void> loadTrendingStations() async {
    const cacheKey = 'trending_stations';
    _loadingKey = cacheKey;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _stations = await _service.getTrendingStations(limit: 100);
      _cache[cacheKey] = List.from(_stations);
    } catch (e) {
      _stations = [];
      _errorMessage = 'Failed to load stations';
    }
    _loadingKey = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadLiveStations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _stations = await _service.getLiveStations(limit: 100);
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
      _stations = await _service.getGlobalAmFmStations(limit: 200);
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
      _stations = await _service.getStationsByLanguage(language, limit: 50);
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
      final trending = await _service.getTrendingStations(limit: 50);
      final tanzania = await _service.getTanzaniaStations(limit: 50);
      _stations = [...trending, ...tanzania].take(100).toList();
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
      _stations = await _service.getStationsByCountry(country, limit: 50);
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
      _stations = await _service.getStationsByGenre(genre, limit: 50);
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
      _stations = await _service.getMusicStations(limit: 200);
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
      _stations = await _service.getNewsStations(limit: 100);
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
      _stations = await _service.getSportsStations(limit: 100);
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
      _stations = await _service.getTalkStations(limit: 100);
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
      if (_stations.isEmpty) {
        _stations = RadioService.getStaticTanzaniaStations();
      }
    } catch (e) {
      _stations = RadioService.getStaticTanzaniaStations();
      _errorMessage = 'Using offline station list';
    }
    _isLoading = false;
    notifyListeners();
  }

  List<Duration> get sleepPresets => [
        const Duration(minutes: 15),
        const Duration(minutes: 30),
        const Duration(minutes: 45),
        const Duration(hours: 1),
        const Duration(hours: 2),
        const Duration(hours: 3),
        const Duration(hours: 4),
        const Duration(hours: 6),
        const Duration(hours: 8),
      ];

  Future<void> startRecording() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${dir.path}/audio_recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = _currentStation?.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_') ?? 'recording';
      _recordingPath = '${recordingsDir.path}/${filename}_$timestamp.mp3';
      
      _isRecording = true;
      _recordingStartTime = DateTime.now();
      _recordingDuration = Duration.zero;

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_recordingStartTime != null) {
          _recordingDuration = DateTime.now().difference(_recordingStartTime!);
        }
        notifyListeners();
      });

      notifyListeners();
      
      await _startStreamRecording(_recordingPath!);
    } catch (e) {
      _errorMessage = 'Failed to start recording: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> _startStreamRecording(String path) async {
    try {
      if (_currentStation == null) {
        _errorMessage = 'No station playing';
        _isRecording = false;
        _recordingPath = null;
        notifyListeners();
        return;
      }

      _recordingClient = HttpClient();
      _recordingRequest = await _recordingClient!.getUrl(Uri.parse(_currentStation!.url));
      _recordingRequest!.headers.set('User-Agent', 'FluxRadio/1.0');
      
      _recordingResponse = await _recordingRequest!.close();
      _recordingSink = File(path).openWrite();
      
      _recordingResponse!.listen(
        (chunk) {
          if (_isRecording && _recordingSink != null) {
            _recordingSink!.add(chunk);
          }
        },
        onError: (e) {
          _errorMessage = 'Recording error: ${e.toString()}';
          _isRecording = false;
          notifyListeners();
        },
        onDone: () {
          if (_isRecording) {
            _errorMessage = 'Stream ended';
            stopRecording();
          }
        },
      );
      
      final metadataPath = '$path.metadata';
      final metadata = {
        'duration': _recordingDuration.inSeconds,
        'station': _currentStation?.name,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await File(metadataPath).writeAsString(jsonEncode(metadata));
      
    } catch (e) {
      _errorMessage = 'Recording error: ${e.toString()}';
      _isRecording = false;
      _recordingPath = null;
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    try {
      _recordingTimer?.cancel();
      _recordingTimer = null;
      
      _isRecording = false;
      
      await _recordingSink?.close();
      _recordingClient?.close();
      
      _recordingSink = null;
      _recordingResponse = null;
      _recordingClient = null;
      
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          if (!_savedRecordings.contains(_recordingPath!)) {
            _savedRecordings.add(_recordingPath!);
          }
        }
      }
      
      _recordingPath = null;
      _recordingStartTime = null;
      _recordingDuration = Duration.zero;

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to stop recording: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> playRecording(String path) async {
    if (_currentStation != null && _isPlaying) {
      await stop();
    }
    
    try {
      final file = File(path);
      if (!await file.exists()) {
        _errorMessage = 'Recording file not found';
        notifyListeners();
        return;
      }

      _isLoading = true;
      notifyListeners();

      await _player.setFilePath(path);
      await _player.setVolume(_volume);
      await _player.play();
      
      _isPlaying = true;
      _currentStation = RadioStation(
        name: 'Recording',
        url: path,
        country: 'Local',
        language: 'Audio',
        genre: 'Recording',
        bitrate: 128,
        favicon: '',
      );
      _currentTitle = 'Recording';

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to play recording: ${e.toString()}';
      _isLoading = false;
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
      final recordingsDir = Directory('${dir.path}/audio_recordings');
      if (await recordingsDir.exists()) {
        final files = recordingsDir.listSync();
        _savedRecordings = files
            .whereType<File>()
            .map((f) => f.path)
            .toList();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to load saved recordings: ${e.toString()}';
      notifyListeners();
    }
  }

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
    _player.setVolume(_volume);
    notifyListeners();
  }

  void adjustVolume(double delta) {
    setVolume(_volume + delta);
  }

  Future<void> setEqualizerPreset(String preset) async {
    switch (preset) {
      case 'flat':
        resetEqualizer();
        break;
      case 'rock':
        updateEqualizerBand(0, 2.0);
        updateEqualizerBand(1, 1.0);
        updateEqualizerBand(2, 0.0);
        updateEqualizerBand(3, -1.0);
        updateEqualizerBand(4, -2.0);
        break;
      case 'pop':
        updateEqualizerBand(0, -2.0);
        updateEqualizerBand(1, -1.0);
        updateEqualizerBand(2, 0.0);
        updateEqualizerBand(3, 1.0);
        updateEqualizerBand(4, 2.0);
        break;
      case 'jazz':
        updateEqualizerBand(0, 1.0);
        updateEqualizerBand(1, 0.5);
        updateEqualizerBand(2, 0.0);
        updateEqualizerBand(3, 0.5);
        updateEqualizerBand(4, 1.0);
        break;
      case 'classical':
        updateEqualizerBand(0, -1.0);
        updateEqualizerBand(1, -1.0);
        updateEqualizerBand(2, 0.0);
        updateEqualizerBand(3, 1.0);
        updateEqualizerBand(4, 1.0);
        break;
      case 'bass_boost':
        updateEqualizerBand(0, 5.0);
        updateEqualizerBand(1, 3.0);
        updateEqualizerBand(2, 0.0);
        updateEqualizerBand(3, -1.0);
        updateEqualizerBand(4, -2.0);
        break;
    }
  }

  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  Duration get bufferedPosition => _player.bufferedPosition;

  void seek(Duration position) {
    _player.seek(position);
  }

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

  Future<List<RadioStation>> get favorites async {
    final favs = await storage.getFavorites();
    return favs.map((f) => f.toRadioStation()).toList();
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

  void clearCache() {
    _cache.clear();
    _lastCacheUpdate = null;
    notifyListeners();
  }

  void updateEqualizerBand(int index, double value) {
    if (index >= 0 && index < _equalizerBands.length) {
      _equalizerBands[index] = value.clamp(-10.0, 10.0);
      notifyListeners();
    }
  }

  void resetEqualizer() {
    for (var i = 0; i < _equalizerBands.length; i++) {
      _equalizerBands[i] = 0.0;
    }
    notifyListeners();
  }

  Future<void> saveRecentSearch(String query) async {
    if (query.isEmpty) return;
    _recentSearches.removeWhere((q) => q.toLowerCase() == query.toLowerCase());
    _recentSearches.insert(0, query);
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.sublist(0, 10);
    }
    await storage.cacheStations('recent_searches', _recentSearches.map((s) => RadioStation(
      name: s, url: '', country: '', language: '', genre: '', bitrate: 0, favicon: '',
    )).toList());
    notifyListeners();
  }

  Future<List<String>> getRecentSearches() async {
    final cached = await storage.getCachedStations('recent_searches', minutes: 1440);
    if (cached != null) {
      _recentSearches = cached.map((s) => s.name).toList();
    }
    return _recentSearches;
  }

  bool _isValidStreamUrl(String url) {
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  void disposeStation() {
    _sleepTimer?.cancel();
    _recordingTimer?.cancel();
    _networkCheckTimer?.cancel();
    _recordingSink?.close();
    _recordingClient?.close();
    _httpClient.close();
    _cache.clear();
    _player.dispose();
  }

  @override
  void dispose() {
    disposeStation();
    super.dispose();
  }
}