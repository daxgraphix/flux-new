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
  Box<dynamic>? _settingsBox;
  bool _initialized = false;

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
      _settingsBox = await _openSafeBox('settings');
      _initialized = true;
    } catch (e) {
      debugPrint('RadioStorage critical failure: $e');
    }
  }

  Future<Box<T>> _openSafeBox<T>(String name) async {
    try {
      return await Hive.openBox<T>(name);
    } catch (e) {
      debugPrint('Box $name is corrupted, recreating...');
      await Hive.deleteBoxFromDisk(name);
      return await Hive.openBox<T>(name);
    }
  }

  Future<void> cacheData(String key, dynamic data) async {
    if (!_initialized) await init();
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _cacheBox?.put(key, {'data': data, 'timestamp': timestamp});
    } catch (e) {
      debugPrint('Failed to cache data for $key: $e');
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
    }
  }

  Future<void> removeFavorite(String id) async {
    await _favoritesBox?.delete(id);
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
    }
  }

  Future<List<RadioStation>> getRecent() async {
    final list = _recentBox?.values.toList() ?? [];
    list.sort((a, b) => b.playedDate.compareTo(a.playedDate));
    return list.map((e) => e.station).toList();
  }

  Future<void> addRecentSearch(String query) async {
    if (!_initialized) await init();
    final searches = _searchesBox?.values.toList() ?? [];
    if (searches.contains(query)) {
      await _searchesBox?.delete(searches.indexOf(query));
    }
    await _searchesBox?.add(query);
    if ((_searchesBox?.length ?? 0) > 10) {
      await _searchesBox?.deleteAt(0);
    }
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

  Future<List<Episode>> getDownloadedEpisodes() async {
    if (!_initialized) await init();
    return _downloadsBox?.values.toList() ?? [];
  }

  Future<Episode?> getDownloadedEpisode(String id) async {
    if (!_initialized) await init();
    return _downloadsBox?.get(id);
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

  Future<void> saveEqualizer(List<double> bands, double loudness) async {
    if (!_initialized) await init();
    await _settingsBox?.put('eq_bands', bands);
    await _settingsBox?.put('eq_loudness', loudness);
  }

  Future<Map<String, dynamic>> getEqualizer() async {
    if (!_initialized) await init();
    return {
      'bands': _settingsBox?.get('eq_bands') as List<double>?,
      'loudness': _settingsBox?.get('eq_loudness') as double?,
    };
  }
}

