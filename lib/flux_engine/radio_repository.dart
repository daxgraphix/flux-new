import 'package:flutter/foundation.dart';
import '../flux_hardware/radio_service.dart';
import '../flux_storage/radio_storage.dart';

class RadioRepository {
  final RadioService _service;
  final RadioStorage _storage;

  RadioRepository({
    RadioService? service,
    RadioStorage? storage,
  })  : _service = service ?? RadioService(),
        _storage = storage ?? RadioStorage();

  /// Returns cached stations if available, then fetches fresh data from network.
  /// If [forceRefresh] is true, it skips the cache.
  Stream<List<RadioStation>> getTopStations({bool forceRefresh = false}) async* {
    const cacheKey = 'top_stations';
    
    if (!forceRefresh) {
      final cached = await _storage.getCachedStations(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        yield cached;
      }
    }

    try {
      final fresh = await _service.getTopStations();
      await _storage.cacheStations(cacheKey, fresh);
      yield fresh;
    } catch (e) {
      // If network fails and we haven't yielded cached data yet, rethrow or yield empty
      debugPrint('Repository error: $e');
    }
  }

  Future<List<RadioStation>> searchStations(String query) async {
    final cacheKey = 'search_$query';
    final cached = await _storage.getCachedStations(cacheKey, minutes: 10);
    if (cached != null) return cached;

    final fresh = await _service.searchStations(name: query);
    await _storage.cacheStations(cacheKey, fresh);
    return fresh;
  }

  Future<List<RadioStation>> getRecentStations() => _storage.getRecent();

  Future<List<FavoriteStation>> getFavorites() => _storage.getFavorites();

  Future<void> toggleFavorite(RadioStation station) async {
    final id = station.uuid ?? station.url; // Use consistent ID logic
    if (await _storage.isFavorite(id)) {
      await _storage.removeFavorite(id);
    } else {
      await _storage.addFavorite(station);
    }
  }

  Future<void> addToRecent(RadioStation station) => _storage.addRecent(station);
}
