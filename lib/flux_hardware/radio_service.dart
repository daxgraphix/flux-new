import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:crypto/crypto.dart';

part 'radio_service.g.dart';

@HiveType(typeId: 0)
class RadioStation {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final String url;
  @HiveField(2)
  final String country;
  @HiveField(3)
  final String language;
  @HiveField(4)
  final String genre;
  @HiveField(5)
  final int bitrate;
  @HiveField(6)
  final String favicon;
  @HiveField(7)
  final String? uuid;

  RadioStation({
    required this.name,
    required this.url,
    required this.country,
    required this.language,
    required this.genre,
    required this.bitrate,
    required this.favicon,
    this.uuid,
  });

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    return RadioStation(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      country: json['country'] ?? '',
      language: json['language'] ?? '',
      genre: json['tags'] ?? '',
      bitrate: json['bitrate'] ?? 128,
      favicon: json['favicon'] ?? '',
      uuid: json['stationuuid'] ?? json['uuid'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'country': country,
      'language': language,
      'genre': genre,
      'bitrate': bitrate,
      'favicon': favicon,
      'uuid': uuid,
    };
  }

  String get id {
    if (uuid != null && uuid!.isNotEmpty) return uuid!;
    return sha256.convert(utf8.encode(url)).toString().substring(0, 16);
  }
}

class RadioService {
  static const List<String> _baseUrls = [
    'https://de1.api.radio-browser.info',
    'https://at1.api.radio-browser.info',
    'https://fr1.api.radio-browser.info',
    'https://nl1.api.radio-browser.info',
  ];
  static String _baseUrl = _baseUrls[0];
  static const String _streemaUrl = 'https://streema.com/radios/country/';
  static const Duration _requestTimeout = Duration(seconds: 10);

  static final List<RadioStation> _staticTanzaniaStations = [
    RadioStation(
      name: 'Clouds FM',
      url: 'http://173.249.21.17:8000/cloudsfm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Entertainment, Music',
      bitrate: 128,
      favicon: 'https://cmg.co.tz/wp-content/uploads/2021/05/Clouds-FM-Logo.png',
    ),
    RadioStation(
      name: 'Wasafi FM',
      url: 'https://stream.wasafifm.co.tz/radio/8000/radio.mp3',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Entertainment, Music',
      bitrate: 128,
      favicon: 'https://wasafifm.co.tz/wp-content/uploads/2023/07/wasafi-fm-logo.png',
    ),
    RadioStation(
      name: 'Radio One Stereo',
      url: 'http://41.222.181.187:8000/radioone',
      country: 'Tanzania',
      language: 'sw',
      genre: 'News, Talk',
      bitrate: 128,
      favicon: 'https://www.ippmedia.com/sites/default/files/styles/medium/public/radio-one-logo.jpg',
    ),
    RadioStation(
      name: 'E-FM Radio',
      url: 'http://197.250.35.210:8000/efm',
      country: 'Tanzania',
      language: 'sw',
      genre: 'Music, Sports',
      bitrate: 128,
      favicon: 'https://efm.co.tz/wp-content/uploads/2019/08/efm-logo.png',
    ),
    RadioStation(
      name: 'Radio Free Africa',
      url: 'http://41.222.176.162:8000/rfa',
      country: 'Tanzania',
      language: 'sw',
      genre: 'News, Music',
      bitrate: 128,
      favicon: 'https://radiofreeafrica.co.tz/wp-content/uploads/2020/06/RFA-Logo.png',
    ),
    RadioStation(
      name: 'TBC Taifa',
      url: 'http://41.59.225.234:8000/tbctaifa',
      country: 'Tanzania',
      language: 'sw',
      genre: 'News, National',
      bitrate: 128,
      favicon: 'https://www.tbc.go.tz/images/logo.png',
    ),
    RadioStation(
      name: 'BBC Swahili',
      url: 'https://www.radiofeeds.co.uk/bbcswahili.asp',
      country: 'Tanzania',
      language: 'sw',
      genre: 'News',
      bitrate: 128,
      favicon: 'https://www.bbc.co.uk/favicon.ico',
    ),
    RadioStation(
      name: 'East African Radio',
      url: 'http://41.222.181.187:8000/eastafricanradio',
      country: 'Tanzania',
      language: 'en',
      genre: 'Music, Culture',
      bitrate: 128,
      favicon: 'https://www.ippmedia.com/sites/default/files/styles/medium/public/ear-logo.jpg',
    ),
  ];

  static List<RadioStation> getStaticTanzaniaStations() {
    return List.unmodifiable(_staticTanzaniaStations);
  }

  Future<List<RadioStation>> searchStations({
    String? name,
    String? country,
    String? language,
    String? tag,
    int? bitrateMin,
    int? bitrateMax,
    bool hasGeoInfo = false,
    String? order = 'votes',
    bool reverse = true,
    int limit = 50,
    double? lat,
    double? lon,
    double? radius,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{};
    if (name != null) queryParams['name'] = name;
    if (country != null) queryParams['country'] = country;
    if (language != null) queryParams['language'] = language;
    if (tag != null) queryParams['tag'] = tag;
    if (bitrateMin != null) queryParams['bitrateMin'] = bitrateMin.toString();
    if (bitrateMax != null) queryParams['bitrateMax'] = bitrateMax.toString();
    if (hasGeoInfo) queryParams['hasGeoInfo'] = 'true';
    if (lat != null) queryParams['lat'] = lat.toString();
    if (lon != null) queryParams['lon'] = lon.toString();
    if (radius != null) queryParams['radius'] = radius.toString();
    if (order != null) queryParams['order'] = order;
    queryParams['reverse'] = reverse.toString();
    queryParams['limit'] = limit.toString();
    queryParams['offset'] = offset.toString();
    queryParams['hidebroken'] = 'true';

    // Try multiple mirrors in parallel or sequence for reliability
    for (final baseUrl in _baseUrls) {
      try {
        final uri = Uri.parse(
          '$baseUrl/json/stations/search',
        ).replace(queryParameters: queryParams);
        final response = await http.get(uri).timeout(_requestTimeout);

        if (response.statusCode == 200) {
          _baseUrl = baseUrl; // Update to currently working mirror
          final List<dynamic> data = json.decode(response.body);
          return data.map((json) => RadioStation.fromJson(json)).toList();
        }
      } catch (e) {
        debugPrint('Mirror $baseUrl failed: $e');
        continue;
      }
    }
    throw Exception('Failed to load stations from all mirrors');
  }

  Future<List<String>> getCountries() async {
    for (final baseUrl in _baseUrls) {
      try {
        final uri = Uri.parse('$baseUrl/json/countries');
        final response = await http.get(uri).timeout(_requestTimeout);
        if (response.statusCode == 200) {
          _baseUrl = baseUrl;
          final List<dynamic> data = json.decode(response.body);
          return data.map((json) => json['name'] as String).toList();
        }
      } catch (e) {
        continue;
      }
    }
    throw Exception('Failed to load countries from mirrors');
  }

  Future<List<String>> getTags({int limit = 500}) async {
    final queryParams = {
      'hidebroken': 'true',
      'order': 'stationcount',
      'reverse': 'true',
    };
    for (final baseUrl in _baseUrls) {
      try {
        final uri = Uri.parse('$baseUrl/json/tags').replace(queryParameters: queryParams);
        final response = await http.get(uri).timeout(_requestTimeout);
        if (response.statusCode == 200) {
          _baseUrl = baseUrl;
          final List<dynamic> data = json.decode(response.body);
          return data.take(limit).map((json) => json['name'] as String).toList();
        }
      } catch (e) {
        continue;
      }
    }
    return ['Pop', 'Rock', 'Jazz', 'News', 'Classical', 'Dance'];
  }

  /// Generates a Streema search URL for global aggregation
  String getStreemaSearchUrl(String query) {
    final encodedQuery = Uri.encodeComponent(query);
    return 'https://streema.com/radios/search/?q=$encodedQuery';
  }

  Future<List<String>> getLanguages() async {
    for (final baseUrl in _baseUrls) {
      try {
        final uri = Uri.parse('$baseUrl/json/languages');
        final response = await http.get(uri).timeout(_requestTimeout);
        if (response.statusCode == 200) {
          _baseUrl = baseUrl;
          final List<dynamic> data = json.decode(response.body);
          return data.map((json) => json['name'] as String).toList();
        }
      } catch (e) {
        continue;
      }
    }
    throw Exception('Failed to load languages');
  }

  Future<List<RadioStation>> getTopStations({int limit = 250, int? bitrateMin}) async {
    return searchStations(limit: limit, order: 'votes', reverse: true, bitrateMin: bitrateMin);
  }

  Future<List<RadioStation>> getTrendingStations({int limit = 250, int? bitrateMin}) async {
    return searchStations(limit: limit, order: 'clicktrend', reverse: true, bitrateMin: bitrateMin);
  }

  Future<List<RadioStation>> getStationsByCountry(String country, {int limit = 250, int? bitrateMin}) async {
    return searchStations(country: country, limit: limit, order: 'votes', reverse: true, bitrateMin: bitrateMin);
  }

  Future<List<RadioStation>> getStationsByGenre(String genre, {int limit = 250, int? bitrateMin}) async {
    return searchStations(tag: genre, limit: limit, order: 'votes', reverse: true, bitrateMin: bitrateMin);
  }

  Future<List<RadioStation>> getStationsByLanguage(String language, {int limit = 100, int? bitrateMin}) async {
    return searchStations(language: language, limit: limit, order: 'votes', reverse: true, bitrateMin: bitrateMin);
  }

  Future<List<RadioStation>> getMusicStations({int limit = 100}) async {
    final musicGenres = ['pop', 'rock', 'jazz', 'classical', 'electronic', 'hip hop', 'country', 'reggae'];
    final int limitPerGenre = (limit / musicGenres.length).round();
    
    final futures = musicGenres.map((genre) => searchStations(
      tag: genre, 
      limit: limitPerGenre, 
      order: 'votes', 
      reverse: true,
    ));

    final results = await Future.wait(futures);
    final List<RadioStation> allStations = results.expand((stations) => stations).toList();
    
    return allStations.take(limit).toList();
  }

  Future<List<RadioStation>> getNewsStations({int limit = 100}) async {
    return searchStations(tag: 'news', limit: limit, order: 'votes', reverse: true);
  }

  Future<List<RadioStation>> getSportsStations({int limit = 100}) async {
    return searchStations(tag: 'sports', limit: limit, order: 'votes', reverse: true);
  }

  Future<List<RadioStation>> getTalkStations({int limit = 100}) async {
    final talkTags = ['talk', 'comedy', 'business', 'tech', 'politics'];
    final int limitPerTag = (limit / talkTags.length).round();

    final futures = talkTags.map((tag) => searchStations(
      tag: tag, 
      limit: limitPerTag, 
      order: 'votes', 
      reverse: true,
    ));

    final results = await Future.wait(futures);
    final List<RadioStation> allStations = results.expand((stations) => stations).toList();
    
    return allStations.take(limit).toList();
  }

  Future<List<RadioStation>> getLiveStations({int limit = 200}) async {
    return searchStations(tag: 'live', limit: limit, order: 'votes', reverse: true);
  }

  Future<List<RadioStation>> getGlobalAmFmStations({int limit = 500}) async {
    final int quarterLimit = (limit / 4).round();
    final int eighthLimit = (limit / 8).round();

    final futures = [
      searchStations(tag: 'am', limit: quarterLimit, order: 'clicktrend', reverse: true, hasGeoInfo: false),
      searchStations(tag: 'fm', limit: quarterLimit, order: 'clicktrend', reverse: true, hasGeoInfo: false),
      searchStations(country: 'United States', tag: 'fm', limit: quarterLimit, order: 'votes', reverse: true),
      searchStations(country: 'United Kingdom', tag: 'fm', limit: eighthLimit, order: 'votes', reverse: true),
      searchStations(country: 'Germany', tag: 'fm', limit: eighthLimit, order: 'votes', reverse: true),
    ];

    final results = await Future.wait(futures);
    final List<RadioStation> allStations = results.expand((stations) => stations).toList();

    // Remove duplicates and limit results
    final uniqueStations = <String, RadioStation>{};
    for (final station in allStations) {
      final key = '${station.name}_${station.url}';
      if (!uniqueStations.containsKey(key)) {
        uniqueStations[key] = station;
      }
    }

    return uniqueStations.values.take(limit).toList();
  }

  Future<List<RadioStation>> getStationsByLocation({double? lat, double? lon, double radius = 100, int limit = 50}) async {
    return searchStations(lat: lat, lon: lon, radius: radius, limit: limit, order: 'distance', reverse: false);
  }

  Future<List<RadioStation>> getTanzaniaStations({int limit = 100, int? bitrateMin}) async {
    return searchStations(country: 'Tanzania', limit: limit, order: 'votes', reverse: true, bitrateMin: bitrateMin);
  }

  Future<List<RadioStation>> getNearbyStations({required double lat, required double lon, int limit = 50}) async {
    return getStationsByLocation(lat: lat, lon: lon, limit: limit);
  }

  Future<bool> reportStation(String uuid) async {
    try {
      final uri = Uri.parse('$_baseUrl/json/report/$uuid');
      final response = await http.get(uri).timeout(_requestTimeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Failed to report station: $e');
      return false;
    }
  }

  Future<void> clickStation(String uuid) async {
    try {
      final uri = Uri.parse('$_baseUrl/json/url/$uuid');
      await http.get(uri).timeout(_requestTimeout);
    } catch (e) {
      // Ignore click tracking errors
    }
  }

  /// Note: Streema doesn't have a public API for direct station fetching in the same format.
  /// This method is a placeholder or for potential future scraping/integration.
  String getStreemaCountryUrl(String countryName) {
    final slug = countryName.toLowerCase().replaceAll(' ', '_');
    return '$_streemaUrl$slug';
  }
}
