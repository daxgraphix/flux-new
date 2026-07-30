import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../flux_storage/radio_storage.dart';
import '../flux_hardware/radio_service.dart';
import '../flux_ui/models/podcast.dart';
import 'podcast_service.dart';

class LibraryManager extends ChangeNotifier {
  final PodcastService _podcastService = PodcastService();
  List<RadioStation> _recentStations = [];
  List<FavoriteStation> _favorites = [];
  List<Podcast> _followedPodcasts = [];
  List<Episode> _bookmarkedEpisodes = [];
  List<Episode> _inProgressEpisodes = [];
  List<String> _recentSearches = [];
  List<String> _favoriteCategories = [];

  List<RadioStation> get recentStations => List.unmodifiable(_recentStations);
  List<FavoriteStation> get favorites => List.unmodifiable(_favorites);
  List<RadioStation> get favoriteStations => _favorites.map((f) => f.toRadioStation()).toList();
  List<Podcast> get followedPodcasts => List.unmodifiable(_followedPodcasts);
  List<Episode> get bookmarkedEpisodes => List.unmodifiable(_bookmarkedEpisodes);
  List<Episode> get inProgressEpisodes => List.unmodifiable(_inProgressEpisodes);
  List<String> get recentSearches => List.unmodifiable(_recentSearches);
  List<String> get favoriteCategories => List.unmodifiable(_favoriteCategories);

  Future<void> loadLibrary() async {
    await _podcastService.init();
    await loadRecentStations();
    await loadFavorites();
    await loadFollowedPodcasts();
    await loadBookmarks();
    await loadInProgressEpisodes();
    await loadRecentSearches();
    await loadFavoriteCategories();
    
    // Check for new episodes in the background
    refreshFollowedPodcasts();
  }

  Future<void> refreshFollowedPodcasts() async {
    int totalNewEpisodes = 0;
    for (final podcast in _followedPodcasts) {
      if (podcast.rss.isNotEmpty) {
        final newCount = await _podcastService.checkNewEpisodes(podcast.rss);
        totalNewEpisodes += newCount;
      }
    }
    
    if (totalNewEpisodes > 0) {
      debugPrint('Found $totalNewEpisodes new episodes across followed podcasts');
      // Here we could trigger a local notification
    }
  }

  Future<void> loadRecentStations() async {
    _recentStations = await RadioStorage().getRecent();
    notifyListeners();
  }

  Future<void> loadFavorites() async {
    _favorites = await RadioStorage().getFavorites();
    notifyListeners();
  }

  Future<void> loadFollowedPodcasts() async {
    _followedPodcasts = await RadioStorage().getFollowedPodcasts();
    notifyListeners();
  }

  Future<void> loadBookmarks() async {
    _bookmarkedEpisodes = await RadioStorage().getBookmarkedEpisodes();
    notifyListeners();
  }

  Future<void> loadInProgressEpisodes() async {
    _inProgressEpisodes = await RadioStorage().getInProgressEpisodes();
    notifyListeners();
  }

  Future<void> loadRecentSearches() async {
    _recentSearches = await RadioStorage().getRecentSearches();
    notifyListeners();
  }

  Future<void> loadFavoriteCategories() async {
    final list = await RadioStorage().getSettings<List<dynamic>>('favorite_categories');
    _favoriteCategories = list?.cast<String>() ?? [];
    notifyListeners();
  }

  Future<void> toggleFavoriteCategory(String categoryTitle) async {
    if (_favoriteCategories.contains(categoryTitle)) {
      _favoriteCategories.remove(categoryTitle);
    } else {
      _favoriteCategories.add(categoryTitle);
    }
    await RadioStorage().saveSettings('favorite_categories', _favoriteCategories);
    notifyListeners();
  }

  bool isCategoryFavorite(String categoryTitle) {
    return _favoriteCategories.contains(categoryTitle);
  }

  Future<void> addToRecent(RadioStation station) async {
    await RadioStorage().addRecent(station);
    await loadRecentStations();
  }

  Future<void> updateEpisodeProgress(String id, int position, {Episode? episode}) async {
    await RadioStorage().updateEpisodePosition(id, position, episode: episode);
    await loadInProgressEpisodes();
  }

  Future<void> toggleFavorite(RadioStation station) async {
    final id = _getId(station.url, station.uuid);
    if (await RadioStorage().isFavorite(id)) {
      await RadioStorage().removeFavorite(id);
    } else {
      await RadioStorage().addFavorite(station);
    }
    await loadFavorites();
  }

  Future<void> clearRecentStations() async {
    await RadioStorage().clearRecent();
    await loadRecentStations();
  }

  Future<void> clearFavorites() async {
    await RadioStorage().clearFavorites();
    await loadFavorites();
  }

  Future<void> clearBookmarks() async {
    await RadioStorage().clearBookmarks();
    await loadBookmarks();
  }

  Future<void> clearFavoritesAndBookmarks() async {
    await RadioStorage().clearFavorites();
    await RadioStorage().clearBookmarks();
    await loadFavorites();
    await loadBookmarks();
  }

  Future<void> removeRecentSearch(String query) async {
    await RadioStorage().removeRecentSearch(query);
    await loadRecentSearches();
  }

  Future<void> clearRecentSearches() async {
    await RadioStorage().clearRecentSearches();
    await loadRecentSearches();
  }

  Future<void> toggleBookmark(Episode episode) async {
    await RadioStorage().toggleBookmark(episode);
    await loadBookmarks();
  }

  Future<void> toggleFollowPodcast(Podcast podcast) async {
    await RadioStorage().toggleFollowPodcast(podcast);
    await loadFollowedPodcasts();
  }

  bool isFollowingPodcast(String id) {
    return _followedPodcasts.any((p) => p.id == id);
  }

  Future<void> togglePodcastNotifications(String id) async {
    final index = _followedPodcasts.indexWhere((p) => p.id == id);
    if (index != -1) {
      final podcast = _followedPodcasts[index];
      final updatedPodcast = podcast.copyWith(notificationsEnabled: !podcast.notificationsEnabled);
      await RadioStorage().updateFollowedPodcast(updatedPodcast);
      await loadFollowedPodcasts();
    }
  }

  bool areNotificationsEnabled(String id) {
    final podcast = _followedPodcasts.firstWhere((p) => p.id == id, orElse: () => Podcast(id: '', title: '', publisher: '', image: '', description: '', rss: ''));
    return podcast.id.isNotEmpty ? podcast.notificationsEnabled : false;
  }

  Future<void> addRecentSearch(String query) async {
    await RadioStorage().addRecentSearch(query);
    await loadRecentSearches();
  }

  Future<bool> isFavorite(String url, {String? uuid}) async {
    final id = _getId(url, uuid);
    return await RadioStorage().isFavorite(id);
  }

  String _getId(String url, String? uuid) {
    if (uuid != null && uuid.isNotEmpty) return uuid;
    return sha256.convert(utf8.encode(url)).toString().substring(0, 16);
  }
}
