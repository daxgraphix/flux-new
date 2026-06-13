import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../flux_hardware/radio_service.dart';

String _generateStationId(String url, String? uuid) {
  if (uuid != null && uuid.isNotEmpty) {
    return uuid;
  }
  return sha256.convert(utf8.encode(url)).toString().substring(0, 16);
}

class FavoriteStation {
  final String id;
  final String name;
  final String url;
  final String country;
  final String genre;
  final int bitrate;
  final String favicon;
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

class RadioStorage {
  static Box<dynamic>? _cacheBox;
  static Box<dynamic>? _favoritesBox;
  static Box<dynamic>? _recentBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _cacheBox = await Hive.openBox('cache');
    _favoritesBox = await Hive.openBox('favorites');
    _recentBox = await Hive.openBox('recent');
  }

  Future<void> cacheStations(String key, List<RadioStation> stations) async {
    final data = jsonEncode(stations.map((s) => s.toJson()).toList());
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _cacheBox?.put(key, {'data': data, 'timestamp': timestamp});
  }

  Future<List<RadioStation>?> getCachedStations(String key, {int minutes = 30}) async {
    final result = _cacheBox?.get(key);
    if (result == null) return null;

    final timestamp = result['timestamp'] as int;
    final data = result['data'] as String;
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;

    if (age > minutes * 60 * 1000) {
      await _cacheBox?.delete(key);
      return null;
    }

    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((e) => RadioStation.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> clearCache() async {
    await _cacheBox?.clear();
  }

  Future<void> addFavorite(RadioStation station) async {
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
    await _favoritesBox?.put(favorite.id, favorite.toMap());
  }

  Future<void> removeFavorite(String id) async {
    await _favoritesBox?.delete(id);
  }

  Future<List<FavoriteStation>> getFavorites() async {
    final List<Map<String, dynamic>> maps = _favoritesBox?.values
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    maps.sort((a, b) => (a['addedDate'] as String).compareTo(b['addedDate'] as String));
    return maps.reversed.map((e) => FavoriteStation.fromMap(e)).toList();
  }

  Future<bool> isFavorite(String id) async {
    return _favoritesBox?.containsKey(id) ?? false;
  }

  Future<void> addRecent(RadioStation station) async {
    final id = _generateStationId(station.url, station.uuid);
    final recent = {
      'id': id,
      'name': station.name,
      'url': station.url,
      'country': station.country,
      'genre': station.genre,
      'bitrate': station.bitrate,
      'favicon': station.favicon,
      'playedDate': DateTime.now().toIso8601String(),
    };
    await _recentBox?.put(id, recent);

    final keys = _recentBox?.keys.toList() ?? [];
    if (keys.length > 20) {
      final sortedKeys = keys.sublist(0, keys.length - 20);
      for (final key in sortedKeys) {
        await _recentBox?.delete(key);
      }
    }
  }

  Future<List<RadioStation>> getRecent() async {
    final List<Map<String, dynamic>> maps = _recentBox?.values
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    maps.sort((a, b) => (a['playedDate'] as String).compareTo(b['playedDate'] as String));
    return maps.reversed.take(20).map((e) {
      return RadioStation(
        name: e['name'] as String,
        url: e['url'] as String,
        country: e['country'] as String,
        language: e['language'] as String? ?? '',
        genre: e['genre'] as String,
        bitrate: e['bitrate'] as int,
        favicon: e['favicon'] as String,
      );
    }).toList();
  }

  Future<Map<String, dynamic>> exportDatabase() async {
    final favorites = await getFavorites();
    final recent = await getRecent();
    return {
      'favorites': favorites.map((f) => f.toMap()).toList(),
      'recent': recent.map((r) => r.toJson()).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }
}