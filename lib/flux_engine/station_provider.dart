import 'dart:async';
import 'package:flutter/material.dart';
import '../flux_hardware/radio_service.dart';
import '../flux_storage/radio_storage.dart';
import 'radio_repository.dart';
import '../flux_ui/models/podcast.dart';
import 'podcast_service.dart';

class StationProvider extends ChangeNotifier {
  final RadioRepository _repository = RadioRepository();
  final PodcastService _podcastService = PodcastService();
  
  List<RadioStation> _stations = [];
  List<Podcast> _podcasts = [];
  List<Episode> _episodes = [];
  List<String> _countries = [];
  List<String> _genres = [];
  List<String> _languages = [];
  
  bool _isLoading = false;
  String? _errorMessage;
  String? _loadingKey;

  List<RadioStation> get stations => _stations;
  List<Podcast> get podcasts => _podcasts;
  List<Episode> get episodes => _episodes;
  List<String> get countries => _countries;
  List<String> get genres => _genres;
  List<String> get languages => _languages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get loadingKey => _loadingKey;

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

  Future<void> initialize() async {
    await _loadCountriesGenresAndLanguages();
    await loadTopStations();
  }

  Future<void> _loadCountriesGenresAndLanguages({bool forceRefresh = false}) async {
    try {
      final metadata = await _repository.getDirectoryMetadata(forceRefresh: forceRefresh);
      
      _countries = metadata['countries'] ?? [];
      _genres = metadata['tags'] ?? [];
      _languages = metadata['languages'] ?? [];
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load directory metadata: $e';
    }
    notifyListeners();
  }

  Future<void> checkForUpdates() async {
    await _loadCountriesGenresAndLanguages(forceRefresh: true);
  }

  Future<void> loadTopStations({bool forceRefresh = false, bool highQuality = false}) async {
    if (_isLoading && _loadingKey == 'top_stations') return;
    
    _isLoading = true;
    _loadingKey = 'top_stations';
    _errorMessage = null;
    notifyListeners();

    try {
      final service = RadioService();
      final stations = await service.getTopStations(
        limit: 100,
        bitrateMin: highQuality ? 128 : null,
      );
      _stations = stations;
      if (_stations.isEmpty) {
        _errorMessage = 'No stations available at the moment. Please try again later.';
      }
    } catch (e) {
      _errorMessage = 'Could not fetch stations. You might be offline.';
    } finally {
      _isLoading = false;
      _loadingKey = null;
      notifyListeners();
    }
  }

  Future<void> searchStations(String query, {bool highQuality = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final stations = await _repository.searchStations(query);
      _stations = stations;
    } catch (e) {
      _stations = [];
      _errorMessage = 'No stations found for that search. Try something else!';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadStationsByTag(String tag, {int limit = 50, bool highQuality = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final stations = await RadioService().getStationsByGenre(
        tag, 
        limit: limit,
        bitrateMin: highQuality ? 128 : null,
      );
      _stations = stations;
    } catch (e) {
      _errorMessage = 'Couldn\'t find stations for this genre.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTanzaniaStations() async {
    _isLoading = true;
    notifyListeners();
    try {
      final stations = await RadioService().getTanzaniaStations();
      _stations = stations;
    } catch (e) {
      _stations = RadioService.getStaticTanzaniaStations();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

  Future<void> searchPodcasts(String query) async {
    _isLoading = true;
    notifyListeners();
    try {
      await Future.delayed(const Duration(seconds: 1));
      _podcasts = [
        Podcast(
          id: '1',
          title: 'The Daily',
          publisher: 'The New York Times',
          image: 'https://static01.nyt.com/images/2017/01/29/podcasts/the-daily-album-art/the-daily-album-art-square320-v4.png',
          description: 'This is what the news should sound like.',
          rss: 'https://feeds.simplecast.com/54nAGpEC',
        ),
        Podcast(
          id: '2',
          title: 'Joe Rogan Experience',
          publisher: 'Joe Rogan',
          image: 'https://upload.wikimedia.org/wikipedia/en/4/4b/The_Joe_Rogan_Experience_logo.jpg',
          description: 'The official podcast of comedian Joe Rogan.',
          rss: 'https://feeds.megaphone.fm/WWO3519750118',
        ),
        Podcast(
          id: '3',
          title: 'BBC Global News',
          publisher: 'BBC World Service',
          image: 'https://ichef.bbci.co.uk/images/ic/1200x675/p03r82bc.jpg',
          description: 'The day\'s top stories from BBC News.',
          rss: 'https://podcasts.files.bbci.co.uk/p02nq0gn.rss',
        ),
      ];
    } catch (e) {
      _errorMessage = 'Failed to load podcasts: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadEpisodes(String rssUrl) async {
    _isLoading = true;
    _episodes = [];
    notifyListeners();
    try {
      var episodes = await _podcastService.fetchEpisodes(rssUrl);
      
      // Check for downloads
      for (int i = 0; i < episodes.length; i++) {
        final downloaded = await RadioStorage().getDownloadedEpisode(episodes[i].id);
        if (downloaded != null) {
          episodes[i] = episodes[i].copyWith(downloadPath: downloaded.downloadPath);
        }
      }
      _episodes = episodes;
    } catch (e) {
      _errorMessage = 'Failed to load episodes: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateEpisode(Episode episode) async {
    final index = _episodes.indexWhere((e) => e.id == episode.id);
    if (index != -1) {
      _episodes[index] = episode;
      notifyListeners();
    }
  }
}
