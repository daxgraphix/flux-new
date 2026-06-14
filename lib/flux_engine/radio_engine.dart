import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../flux_hardware/radio_service.dart';
import '../flux_storage/radio_storage.dart';
import 'radio_repository.dart';
import '../flux_ui/models/podcast.dart';

import 'package:audio_service/audio_service.dart';
import 'audio_service_handler.dart';

class RadioEngine extends ChangeNotifier {
  final AudioHandler _audioHandler;
  AudioPlayer get _player => (_audioHandler as RadioAudioHandler).player;
  final RadioRepository _repository = RadioRepository();

  RadioStation? _currentStation;
  String _currentTitle = '';
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _loadingKey;
  List<RadioStation> _stations = [];
  List<Podcast> _podcasts = [];
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
  
  HttpClient? _recordingClient;
  HttpClientRequest? _recordingRequest;
  HttpClientResponse? _recordingResponse;
  IOSink? _recordingSink;

  bool _isNetworkAvailable = true;
  Timer? _networkCheckTimer;
  StreamSubscription? _topStationsSubscription;

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
  bool get isRecording => _isRecording;
  String? get recordingPath => _recordingPath;
  Duration get recordingDuration => _recordingDuration;
  DateTime? get recordingStartTime => _recordingStartTime;
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
  String? get errorMessage => _errorMessage;
  String? get loadingKey => _loadingKey;
  RadioStation? get currentStation => _currentStation;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String get currentTitle => _currentTitle;
  List<RadioStation> get stations => _stations;
  List<Podcast> get podcasts => _podcasts;
  List<String> get countries => _countries;
  List<String> get genres => _genres;
  List<String> get languages => _languages;
  double get volume => _volume;
  Duration get sleepDuration => _sleepDuration;

  List<Map<String, dynamic>> get categories => [
        {'title': 'Trending', 'icon': Icons.trending_up, 'color': Colors.red, 'action': loadTopStations},
        {'title': 'Tanzania', 'icon': Icons.location_on, 'color': Colors.red, 'action': loadTanzaniaStations},
        {'title': 'Music', 'icon': Icons.music_note, 'color': Colors.red, 'action': loadMusicStations},
        {'title': 'Sports', 'icon': Icons.sports_soccer, 'color': Colors.red, 'action': loadSportsStations},
        {'title': 'News', 'icon': Icons.article, 'color': Colors.red, 'action': loadNewsStations},
        {'title': 'AM/FM', 'icon': Icons.radio, 'color': Colors.red, 'action': loadGlobalAmFmStations},
        {'title': 'Talk', 'icon': Icons.mic, 'color': Colors.red, 'action': loadTalkStations},
        {'title': 'Live', 'icon': Icons.wifi, 'color': Colors.red, 'action': loadLiveStations},
      ];

  RadioEngine(this._audioHandler);

  Future<void> initialize() async {
    await RadioStorage().init();
    await _loadSettings();
    await _loadCountriesGenresAndLanguages();
    await loadTopStations();
    await loadRecentStations();
    await loadFavorites();
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
    final prefs = await SharedPreferences.getInstance();
    _autoPlay = prefs.getBool('auto_play') ?? true;
    _highQuality = prefs.getBool('high_quality') ?? false;
    _dataSaver = prefs.getBool('data_saver') ?? false;
    _volume = prefs.getDouble('volume') ?? 1.0;
  }

  Future<void> setAutoPlay(bool value) async {
    _autoPlay = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_play', value);
    notifyListeners();
  }

  Future<void> setHighQuality(bool value) async {
    _highQuality = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('high_quality', value);
    notifyListeners();
    // Refresh current list with new quality preference
    loadTopStations(forceRefresh: true);
  }

  Future<void> setDataSaver(bool value) async {
    _dataSaver = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('data_saver', value);
    notifyListeners();
  }

  void _startNetworkMonitoring() {
    _networkCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
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
      final response = await http.get(Uri.parse('https://www.google.com')).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
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

  Future<void> _loadCountriesGenresAndLanguages() async {
    try {
      final service = RadioService();
      _countries = await service.getCountries();
      _genres = await service.getTags();
      _languages = await service.getLanguages();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load countries/genres: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> loadTrendingStations() async {
    _isLoading = true;
    notifyListeners();
    try {
      _stations = await RadioService().getTrendingStations();
    } catch (e) {
      _errorMessage = 'Failed to load trending: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadStationsByCountry(String country) async {
    _isLoading = true;
    notifyListeners();
    try {
      _stations = await RadioService().getStationsByCountry(country);
    } catch (e) {
      _errorMessage = 'Failed to load stations for $country: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTopStationsIfNeeded() async {
    if (_stations.isEmpty) {
      await loadTopStations();
    }
  }

  Future<void> searchStations({String? name, String? tag, int limit = 50}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (name != null) {
        _stations = await _repository.searchStations(name);
      } else if (tag != null) {
        _stations = await RadioService().getStationsByGenre(
          tag, 
          limit: limit,
          bitrateMin: _highQuality ? 128 : null,
        );
      }
    } catch (e) {
      _stations = [];
      _errorMessage = 'Search failed: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTopStations({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await _topStationsSubscription?.cancel();
    // Pass high quality preference to repository/service
    final service = RadioService();
    try {
      final stations = await service.getTopStations(
        limit: 100,
        bitrateMin: _highQuality ? 128 : null,
      );
      _stations = stations;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load stations: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
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
      _errorMessage = 'Connection timeout: The station might be offline or slow.';
      _isPlaying = false;
      _currentStation = null;
    } catch (e) {
      if (e.toString().contains('403')) {
        _errorMessage = 'Access denied (403): Station might be geo-restricted.';
      } else if (e.toString().contains('404')) {
        _errorMessage = 'Station not found (404): The link is broken.';
      } else {
        _errorMessage = 'Playback error: ${e.toString()}';
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
    if (_currentStation != null) {
      await _audioHandler.play();
      _isPlaying = true;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _audioHandler.stop();
    _isPlaying = false;
    _currentStation = null;
    _currentTitle = '';
    cancelSleepTimer();
    if (_isRecording) {
      await stopRecording();
    }
    notifyListeners();
  }

  // --- Equalizer & Audio Effects ---
  Future<void> _initializeEqualizer() async {
    if (_audioHandler is RadioAudioHandler) {
      final equalizer = _audioHandler.equalizer;
      final parameters = await equalizer.parameters;
      
      _equalizerBands = parameters.bands.map((b) => b.gain).toList();
      _equalizerCenterFrequencies = parameters.bands.map((b) => b.centerFrequency.toInt()).toList();
      
      final loudness = _audioHandler.loudnessEnhancer;
      _loudnessGain = loudness.targetGain;
      
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
    setLoudnessGain(0.0);
    notifyListeners();
  }

  // --- Favorites ---
  Future<void> loadFavorites() async {
    _favorites = await _repository.getFavorites();
    notifyListeners();
  }

  Future<void> toggleFavorite(RadioStation station) async {
    await _repository.toggleFavorite(station);
    await loadFavorites();
  }

  Future<void> removeFromFavorites(String id) async {
    await RadioStorage().removeFavorite(id);
    await loadFavorites();
  }

  Future<void> addToFavorites(RadioStation station) async {
    await _repository.toggleFavorite(station);
    await loadFavorites();
  }

  Future<bool> isFavorite(String url) async {
    final id = _generateStationId(url, null);
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

  Future<void> getRecentSearches() async {
    await loadRecentSearches();
  }

  // --- Sleep Timer ---
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

  // --- Recordings ---
  Future<void> startRecording() async {
    if (_currentStation == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${dir.path}/audio_recordings');
      if (!await recordingsDir.exists()) await recordingsDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = _currentStation!.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      _recordingPath = '${recordingsDir.path}/${filename}_$timestamp.mp3';
      
      _isRecording = true;
      _recordingStartTime = DateTime.now();
      _recordingDuration = Duration.zero;

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_recordingStartTime != null) {
          _recordingDuration = DateTime.now().difference(_recordingStartTime!);
        }
        notifyListeners();
      });

      _recordingClient = HttpClient();
      _recordingRequest = await _recordingClient!.getUrl(Uri.parse(_currentStation!.url));
      _recordingResponse = await _recordingRequest!.close();
      _recordingSink = File(_recordingPath!).openWrite();
      
      _recordingResponse!.listen((chunk) => _recordingSink?.add(chunk));
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Recording failed: $e';
      _isRecording = false;
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    _isRecording = false;
    _recordingTimer?.cancel();
    await _recordingSink?.close();
    _recordingClient?.close();
    await loadSavedRecordings();
    notifyListeners();
  }

  Future<void> loadSavedRecordings() async {
    final dir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory('${dir.path}/audio_recordings');
    if (await recordingsDir.exists()) {
      _savedRecordings = recordingsDir.listSync().whereType<File>().map((f) => f.path).toList();
      notifyListeners();
    }
  }

  // --- Other Methods ---
  Future<void> loadTanzaniaStations() async {
    _isLoading = true;
    notifyListeners();
    try {
      _stations = await RadioService().getTanzaniaStations();
    } catch (e) {
      _stations = RadioService.getStaticTanzaniaStations();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMusicStations() async {
    _isLoading = true;
    notifyListeners();
    _stations = await RadioService().getMusicStations();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadNewsStations() async {
    _isLoading = true;
    notifyListeners();
    _stations = await RadioService().getNewsStations();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadSportsStations() async {
    _isLoading = true;
    notifyListeners();
    _stations = await RadioService().getSportsStations();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTalkStations() async {
    _isLoading = true;
    notifyListeners();
    _stations = await RadioService().getTalkStations();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadGlobalAmFmStations() async {
    _isLoading = true;
    notifyListeners();
    _stations = await RadioService().getGlobalAmFmStations();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadLiveStations() async {
    _isLoading = true;
    notifyListeners();
    _stations = await RadioService().getLiveStations();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadNearbyStations() async {
    _isLoading = true;
    notifyListeners();
    try {
      // For now, we'll use Tanzania as a default nearby if location is not handled
      _stations = await RadioService().getTanzaniaStations();
    } catch (e) {
      _stations = RadioService.getStaticTanzaniaStations();
    }
    _isLoading = false;
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
      _errorMessage = 'Failed to play recording: $e';
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

  String _generateStationId(String url, String? uuid) {
    if (uuid != null && uuid.isNotEmpty) return uuid;
    return sha256.convert(utf8.encode(url)).toString().substring(0, 16);
  }

  // --- Podcasts ---
  Future<void> searchPodcasts(String query) async {
    _isLoading = true;
    notifyListeners();
    try {
      // Mocked for now until a real Podcast API is integrated
      await Future.delayed(const Duration(seconds: 1));
      _podcasts = [
        Podcast(
          id: '1',
          title: 'The Daily',
          publisher: 'The New York Times',
          image: 'https://static01.nyt.com/images/2017/01/29/podcasts/the-daily-album-art/the-daily-album-art-square320-v4.png',
          description: 'This is what the news should sound like.',
          rss: '',
        ),
        Podcast(
          id: '2',
          title: 'Joe Rogan Experience',
          publisher: 'Joe Rogan',
          image: 'https://upload.wikimedia.org/wikipedia/en/4/4b/The_Joe_Rogan_Experience_logo.jpg',
          description: 'The official podcast of comedian Joe Rogan.',
          rss: '',
        ),
      ];
    } catch (e) {
      _errorMessage = 'Failed to load podcasts: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
    _player.setVolume(_volume);
    SharedPreferences.getInstance().then((prefs) => prefs.setDouble('volume', _volume));
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
    _topStationsSubscription?.cancel();
    _sleepTimer?.cancel();
    _recordingTimer?.cancel();
    _networkCheckTimer?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}
