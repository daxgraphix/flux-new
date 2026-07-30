import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../flux_storage/radio_storage.dart';
import '../flux_hardware/radio_service.dart';
import '../flux_ui/models/podcast.dart';

class LibraryManager extends ChangeNotifier {
  List<RadioStation> _recentStations = [];
  List<FavoriteStation> _favorites = [];
  List<Episode> _bookmarkedEpisodes = [];
  List<String> _recentSearches = [];

  List<RadioStation> get recentStations => List.unmodifiable(_recentStations);
  List<FavoriteStation> get favorites => List.unmodifiable(_favorites);
  List<RadioStation> get favoriteStations => _favorites.map((f) => f.toRadioStation()).toList();
  List<Episode> get bookmarkedEpisodes => List.unmodifiable(_bookmarkedEpisodes);
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  Future<void> loadLibrary() async {
    await loadRecentStations();
    await loadFavorites();
    await loadBookmarks();
    await loadRecentSearches();
  }

  Future<void> loadRecentStations() async {
    _recentStations = await RadioStorage().getRecent();
    notifyListeners();
  }

  Future<void> loadFavorites() async {
    _favorites = await RadioStorage().getFavorites();
    notifyListeners();
  }

  Future<void> loadBookmarks() async {
    _bookmarkedEpisodes = await RadioStorage().getBookmarkedEpisodes();
    notifyListeners();
  }

  Future<void> loadRecentSearches() async {
    _recentSearches = await RadioStorage().getRecentSearches();
    notifyListeners();
  }

  Future<void> addToRecent(RadioStation station) async {
    await RadioStorage().addRecent(station);
    await loadRecentStations();
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
