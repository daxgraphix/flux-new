import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../flux_hardware/radio_service.dart';
import '../flux_ui/models/podcast.dart';
import 'package:flutter/foundation.dart';

part 'radio_storage.g.dart';

String _generateStationId(String url, String? uuid) {
  if (uuid != null && uuid.isNotEmpty) {
    return uuid;
  }
  return sha256.convert(utf8.encode(url)).toString().substring(0, 16);
}

@HiveType(typeId: 1)
class FavoriteStation extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String url;
  @HiveField(3)
  final String country;
  @HiveField(4)
  final String genre;
  @HiveField(5)
  final int bitrate;
  @HiveField(6)
  final String favicon;
  @HiveField(7)
  final DateTime addedDate;

  FavoriteStation({
    required this.id,
    required this.name,
    required this.url,
    required this.country,
    required this.genre,
    required this.bitrate,
    required this.favicon,
    required this.addedDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'country': country,
      'genre': genre,
      'bitrate': bitrate,
      'favicon': favicon,
      'addedDate': addedDate.toIso8601String(),
    };
  }

  factory FavoriteStation.fromMap(Map<String, dynamic> map) {
    return FavoriteStation(
      id: map['id'],
      name: map['name'],
      url: map['url'],
      country: map['country'],
      genre: map['genre'],
      bitrate: map['bitrate'],
      favicon: map['favicon'],
      addedDate: DateTime.parse(map['addedDate']),
    );
  }

  RadioStation toRadioStation() {
    return RadioStation(
      name: name,
      url: url,
      country: country,
      language: '',
      genre: genre,
      bitrate: bitrate,
      favicon: favicon,
    );
  }
}

@HiveType(typeId: 2)
class RecentStation extends HiveObject {
  @HiveField(0)
  final RadioStation station;
  @HiveField(1)
  final DateTime playedDate;

  RecentStation({required this.station, required this.playedDate});
}

@HiveType(typeId: 5)
class RadioAlarm extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String stationName;
  @HiveField(2)
  final String stationUrl;
  @HiveField(3)
  final int hour;
  @HiveField(4)
  final int minute;
  @HiveField(5)
  final bool isEnabled;
  @HiveField(6)
  final List<int> daysOfWeek; // 1 = Monday, 7 = Sunday

  RadioAlarm({
    required this.id,
    required this.stationName,
    required this.stationUrl,
    required this.hour,
    required this.minute,
    this.isEnabled = true,
    this.daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
  });
}

class RadioStorage {
  // Singleton Pattern
  static final RadioStorage _instance = RadioStorage._internal();
  factory RadioStorage() => _instance;
  RadioStorage._internal();

  Box<dynamic>? _cacheBox;
  Box<FavoriteStation>? _favoritesBox;
  Box<RecentStation>? _recentBox;
  Box<String>? _searchesBox;
  Box<RadioAlarm>? _alarmsBox;
  Box<Episode>? _downloadsBox;
  Box<Episode>? _progressBox;
  Box<Podcast>? _followedPodcastsBox;
  Box<dynamic>? _settingsBox;
  Box<Map>? _analyticsBox;
  Box<Episode>? _bookmarksBox;
  bool _initialized = false;
  
  // Error reporting
  static Function(String)? onError;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await Hive.initFlutter();
      
      // Register Adapters
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(RadioStationAdapter());
      if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(FavoriteStationAdapter());
      if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(RecentStationAdapter());
      if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(PodcastAdapter());
      if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(EpisodeAdapter());
      if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(RadioAlarmAdapter());
      
      _cacheBox = await _openSafeBox('cache');
      _favoritesBox = await _openSafeBox<FavoriteStation>('favorites');
      _recentBox = await _openSafeBox<RecentStation>('recent');
      _searchesBox = await _openSafeBox<String>('recent_searches');
      _alarmsBox = await _openSafeBox<RadioAlarm>('alarms');
      _downloadsBox = await _openSafeBox<Episode>('downloads');
      _progressBox = await _openSafeBox<Episode>('episode_progress');
      _followedPodcastsBox = await _openSafeBox<Podcast>('followed_podcasts');
      _settingsBox = await _openSafeBox('settings');
      _analyticsBox = await _openSafeBox<Map>('analytics');
      _bookmarksBox = await _openSafeBox<Episode>('bookmarks');
      _initialized = true;
    } catch (e) {
      debugPrint('RadioStorage critical failure: $e');
      onError?.call('Storage initialization failed: $e');
    }
  }

  Future<Box<T>> _openSafeBox<T>(String name) async {
    try {
      return await Hive.openBox<T>(name);
    } catch (e) {
      debugPrint('Box $name is corrupted, recreating...');
      onError?.call('Database corrupted ($name), attempting recovery...');
      try {
        await Hive.deleteBoxFromDisk(name);
        return await Hive.openBox<T>(name);
      } catch (e2) {
        debugPrint('Failed to recover box $name: $e2');
        onError?.call('Critical storage error: Could not recover $name');
        rethrow;
      }
    }
  }

  Future<void> cacheData(String key, dynamic data) async {
    if (!_initialized) await init();
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _cacheBox?.put(key, {'data': data, 'timestamp': timestamp});
    } catch (e) {
      debugPrint('Failed to cache data for $key: $e');
      onError?.call('Failed to save to cache: $e');
    }
  }

  Future<T?> getCachedData<T>(String key, {int minutes = 30}) async {
    if (!_initialized) await init();
    try {
      final result = _cacheBox?.get(key);
      if (result == null) return null;

      final timestamp = result['timestamp'] as int;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;

      if (age > minutes * 60 * 1000) {
        await _cacheBox?.delete(key);
        return null;
      }

      return result['data'] as T?;
    } catch (e) {
      debugPrint('Failed to get cached data for $key: $e');
      return null;
    }
  }

  Future<void> cacheStations(String key, List<RadioStation> stations) async {
    await cacheData(key, stations);
  }

  Future<List<RadioStation>?> getCachedStations(String key, {int minutes = 30}) async {
    return getCachedData<List<dynamic>>(key, minutes: minutes).then((data) {
      return data?.cast<RadioStation>();
    });
  }

  Future<void> clearCache() async {
    await _cacheBox?.clear();
  }

  Future<void> addFavorite(RadioStation station) async {
    if (!_initialized) await init();
    try {
      final favorite = FavoriteStation(
        id: _generateStationId(station.url, station.uuid),
        name: station.name,
        url: station.url,
        country: station.country,
        genre: station.genre,
        bitrate: station.bitrate,
        favicon: station.favicon,
        addedDate: DateTime.now(),
      );
      await _favoritesBox?.put(favorite.id, favorite);
    } catch (e) {
      debugPrint('Failed to add favorite: $e');
      onError?.call('Failed to add to favorites');
    }
  }

  Future<void> removeFavorite(String id) async {
    await _favoritesBox?.delete(id);
  }

  Future<void> clearFavorites() async {
    if (!_initialized) await init();
    await _favoritesBox?.clear();
  }

  Future<void> clearBookmarks() async {
    if (!_initialized) await init();
    await _bookmarksBox?.clear();
  }

  Future<List<FavoriteStation>> getFavorites() async {
    if (!_initialized) await init();
    final list = _favoritesBox?.values.toList() ?? [];
    list.sort((a, b) => b.addedDate.compareTo(a.addedDate));
    return list;
  }

  Future<bool> isFavorite(String id) async {
    if (!_initialized) await init();
    return _favoritesBox?.containsKey(id) ?? false;
  }

  Future<void> addRecent(RadioStation station) async {
    if (!_initialized) await init();
    try {
      final id = _generateStationId(station.url, station.uuid);
      final recent = RecentStation(station: station, playedDate: DateTime.now());
      
      // Sug 4: Efficient cleanup. If key exists, it just updates timestamp.
      await _recentBox?.put(id, recent);

      if ((_recentBox?.length ?? 0) > 20) {
        final entries = _recentBox!.toMap().entries.toList();
        entries.sort((a, b) => a.value.playedDate.compareTo(b.value.playedDate));
        
        final itemsToDelete = entries.length - 20;
        for (var i = 0; i < itemsToDelete; i++) {
          await _recentBox?.delete(entries[i].key);
        }
      }
    } catch (e) {
      debugPrint('Failed to add recent: $e');
      onError?.call('Failed to update history');
    }
  }

  Future<List<RadioStation>> getRecent() async {
    final list = _recentBox?.values.toList() ?? [];
    list.sort((a, b) => b.playedDate.compareTo(a.playedDate));
    return list.map((e) => e.station).toList();
  }

  Future<void> clearRecent() async {
    if (!_initialized) await init();
    await _recentBox?.clear();
  }

  Future<void> addRecentSearch(String query) async {
    if (!_initialized) await init();
    final searches = _searchesBox?.values.toList() ?? [];
    if (searches.contains(query)) {
      // Find the key for the existing query to delete it
      final key = _searchesBox?.keys.firstWhere((k) => _searchesBox?.get(k) == query, orElse: () => null);
      if (key != null) {
        await _searchesBox?.delete(key);
      }
    }
    await _searchesBox?.add(query);
    if ((_searchesBox?.length ?? 0) > 10) {
      await _searchesBox?.deleteAt(0);
    }
  }

  Future<void> removeRecentSearch(String query) async {
    if (!_initialized) await init();
    final key = _searchesBox?.keys.firstWhere(
      (k) => _searchesBox?.get(k) == query,
      orElse: () => null,
    );
    if (key != null) {
      await _searchesBox?.delete(key);
    }
  }

  Future<void> clearRecentSearches() async {
    if (!_initialized) await init();
    await _searchesBox?.clear();
  }

  Future<List<String>> getRecentSearches() async {
    if (!_initialized) await init();
    return _searchesBox?.values.toList().reversed.toList() ?? [];
  }

  Future<Map<String, dynamic>> exportDatabase() async {
    final favorites = await getFavorites();
    final recent = await getRecent();
    final alarms = await getAlarms();
    return {
      'favorites': favorites.map((f) => f.toMap()).toList(),
      'recent': recent.map((r) => r.toJson()).toList(),
      'alarms': alarms.map((a) => {
        'id': a.id,
        'stationName': a.stationName,
        'stationUrl': a.stationUrl,
        'hour': a.hour,
        'minute': a.minute,
        'isEnabled': a.isEnabled,
        'daysOfWeek': a.daysOfWeek,
      }).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> importDatabase(Map<String, dynamic> data) async {
    try {
      if (data.containsKey('favorites')) {
        final List<dynamic> favs = data['favorites'];
        for (var f in favs) {
          final station = FavoriteStation.fromMap(Map<String, dynamic>.from(f));
          await _favoritesBox?.put(station.id, station);
        }
      }
      if (data.containsKey('recent')) {
        final List<dynamic> recent = data['recent'];
        for (var r in recent) {
          final station = RadioStation.fromJson(Map<String, dynamic>.from(r));
          await addRecent(station);
        }
      }
      if (data.containsKey('alarms')) {
        final List<dynamic> alarms = data['alarms'];
        for (var a in alarms) {
          final m = Map<String, dynamic>.from(a);
          final alarm = RadioAlarm(
            id: m['id'],
            stationName: m['stationName'],
            stationUrl: m['stationUrl'],
            hour: m['hour'],
            minute: m['minute'],
            isEnabled: m['isEnabled'],
            daysOfWeek: List<int>.from(m['daysOfWeek']),
          );
          await saveAlarm(alarm);
        }
      }
    } catch (e) {
      debugPrint('Failed to import database: $e');
      onError?.call('Import failed: $e');
      rethrow;
    }
  }

  // --- Alarms ---
  Future<void> saveAlarm(RadioAlarm alarm) async {
    if (!_initialized) await init();
    await _alarmsBox?.put(alarm.id, alarm);
  }

  Future<void> deleteAlarm(String id) async {
    if (!_initialized) await init();
    await _alarmsBox?.delete(id);
  }

  Future<List<RadioAlarm>> getAlarms() async {
    if (!_initialized) await init();
    return _alarmsBox?.values.toList() ?? [];
  }

  // --- Downloads ---
  Future<void> saveDownloadedEpisode(Episode episode) async {
    if (!_initialized) await init();
    await _downloadsBox?.put(episode.id, episode);
  }

  Future<void> removeDownloadedEpisode(String id) async {
    if (!_initialized) await init();
    await _downloadsBox?.delete(id);
  }

  Future<void> clearAllDownloadedEpisodes() async {
    if (!_initialized) await init();
    await _downloadsBox?.clear();
  }

  Future<List<Episode>> getDownloadedEpisodes() async {
    if (!_initialized) await init();
    return _downloadsBox?.values.toList() ?? [];
  }

  Future<List<Episode>> getInProgressEpisodes() async {
    if (!_initialized) await init();
    final episodes = _progressBox?.values.toList() ?? [];
    // Sort by last modified/played would be better, but we don't have that field yet.
    // For now just return those with progress > 0.
    return episodes.where((e) => e.lastPosition > 0).toList();
  }

  Future<Episode?> getDownloadedEpisode(String id) async {
    if (!_initialized) await init();
    return _downloadsBox?.get(id);
  }

  Future<void> updateEpisodePosition(String id, int position, {Episode? episode}) async {
    if (!_initialized) await init();
    
    // Update in downloads box if it exists there
    final downloadedEpisode = _downloadsBox?.get(id);
    if (downloadedEpisode != null) {
      await _downloadsBox?.put(id, downloadedEpisode.copyWith(lastPosition: position));
    }

    // Update in progress box
    final progressEpisode = _progressBox?.get(id) ?? episode;
    if (progressEpisode != null) {
      try {
        await _progressBox?.put(id, progressEpisode.copyWith(lastPosition: position));
      } catch (e) {
        debugPrint('Failed to save episode progress: $e');
      }
    }

    // Optional: Limit progress box size to last 50 episodes
    if ((_progressBox?.length ?? 0) > 50) {
      final keys = _progressBox!.keys.toList();
      await _progressBox?.delete(keys.first);
    }
  }

  Future<int> getEpisodePosition(String id) async {
    if (!_initialized) await init();
    final episode = _progressBox?.get(id) ?? _downloadsBox?.get(id);
    return episode?.lastPosition ?? 0;
  }

  Future<Map<String, dynamic>?> getLastPlayed() async {
    if (!_initialized) await init();
    final data = await getSettings<String>('last_played');
    if (data == null) return null;
    return jsonDecode(data) as Map<String, dynamic>;
  }

  Future<void> saveLastPlayed(String type, Map<String, dynamic> item) async {
    if (!_initialized) await init();
    await saveSettings('last_played', jsonEncode({
      'type': type,
      'item': item,
    }));
  }

  // --- Settings & Equalizer ---
  Future<void> saveSettings(String key, dynamic value) async {
    if (!_initialized) await init();
    await _settingsBox?.put(key, value);
  }

  Future<T?> getSettings<T>(String key, {T? defaultValue}) async {
    if (!_initialized) await init();
    return _settingsBox?.get(key, defaultValue: defaultValue) as T?;
  }

  Future<void> saveEqualizer(List<double> bands, double loudness, {double? bass, double? speed, double? pitch}) async {
    if (!_initialized) await init();
    await _settingsBox?.put('eq_bands', bands);
    await _settingsBox?.put('eq_loudness', loudness);
    if (bass != null) await _settingsBox?.put('eq_bass', bass);
    if (speed != null) await _settingsBox?.put('eq_speed', speed);
    if (pitch != null) await _settingsBox?.put('eq_pitch', pitch);
  }

  Future<Map<String, dynamic>> getEqualizer() async {
    if (!_initialized) await init();
    return {
      'bands': _settingsBox?.get('eq_bands')?.cast<double>(),
      'loudness': _settingsBox?.get('eq_loudness') as double?,
      'bass_boost': _settingsBox?.get('eq_bass') as double?,
      'speed': _settingsBox?.get('eq_speed') as double?,
      'pitch': _settingsBox?.get('eq_pitch') as double?,
    };
  }

  Future<void> recordEpisodePlay(String episodeId, {String? podcastId}) async {
    if (!_initialized) await init();
    final key = 'ep_$episodeId';
    final current = _analyticsBox?.get(key) ?? {};
    final playCount = (current['play_count'] as int? ?? 0) + 1;
    current['play_count'] = playCount;
    current['last_played'] = DateTime.now().millisecondsSinceEpoch;
    current['podcast_id'] = podcastId;
    await _analyticsBox?.put(key, current);
  }

  Future<int> getEpisodePlayCount(String episodeId) async {
    if (!_initialized) await init();
    final current = _analyticsBox?.get('ep_$episodeId');
    return current?['play_count'] as int? ?? 0;
  }

  Future<Map<String, int>> getPodcastPlayCounts() async {
    if (!_initialized) await init();
    final counts = <String, int>{};
    for (final key in _analyticsBox?.keys ?? []) {
      final strKey = key as String;
      if (strKey.startsWith('ep_')) {
        final data = _analyticsBox?.get(key);
        final podcastId = data?['podcast_id'] as String?;
        final playCount = data?['play_count'] as int? ?? 0;
        if (podcastId != null) {
          counts[podcastId] = (counts[podcastId] ?? 0) + playCount;
        }
      }
    }
    return counts;
  }

  Future<void> toggleBookmark(Episode episode) async {
    if (!_initialized) await init();
    final existing = await getBookmarkedEpisode(episode.id);
    if (existing != null) {
      await _bookmarksBox?.delete(episode.id);
    } else {
      await _bookmarksBox?.put(episode.id, episode);
    }
  }

  Future<Episode?> getBookmarkedEpisode(String id) async {
    if (!_initialized) await init();
    return _bookmarksBox?.get(id);
  }

  Future<List<Episode>> getBookmarkedEpisodes() async {
    if (!_initialized) await init();
    return _bookmarksBox?.values.toList() ?? [];
  }

  Future<bool> isBookmarked(String id) async {
    if (!_initialized) await init();
    return _bookmarksBox?.containsKey(id) ?? false;
  }

  // --- Followed Podcasts ---
  Future<void> toggleFollowPodcast(Podcast podcast) async {
    if (!_initialized) await init();
    if (_followedPodcastsBox?.containsKey(podcast.id) ?? false) {
      await _followedPodcastsBox?.delete(podcast.id);
    } else {
      await _followedPodcastsBox?.put(podcast.id, podcast);
    }
  }

  Future<List<Podcast>> getFollowedPodcasts() async {
    if (!_initialized) await init();
    return _followedPodcastsBox?.values.toList() ?? [];
  }

  Future<void> updateFollowedPodcast(Podcast podcast) async {
    if (!_initialized) await init();
    await _followedPodcastsBox?.put(podcast.id, podcast);
  }
}

