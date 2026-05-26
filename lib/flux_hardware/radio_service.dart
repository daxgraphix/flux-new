import 'dart:convert';
import 'package:http/http.dart' as http;

class RadioStation {
  final String name;
  final String url;
  final String country;
  final String language;
  final String genre;
  final int bitrate;
  final String favicon;

  RadioStation({
    required this.name,
    required this.url,
    required this.country,
    required this.language,
    required this.genre,
    required this.bitrate,
    required this.favicon,
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
    );
  }
}

class RadioService {
  static const String _baseUrl = 'https://de1.api.radio-browser.info';

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
    int limit = 100,
    double? lat,
    double? lon,
    double? radius,
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
    queryParams['hidebroken'] = 'true';

    final uri = Uri.parse(
      '$_baseUrl/json/stations/search',
    ).replace(queryParameters: queryParams);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => RadioStation.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load stations');
    }
  }

  Future<List<String>> getCountries() async {
    final uri = Uri.parse('$_baseUrl/json/countries');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => json['name'] as String).toList();
    } else {
      throw Exception('Failed to load countries');
    }
  }

  Future<List<String>> getTags() async {
    final uri = Uri.parse('$_baseUrl/json/tags');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => json['name'] as String).toList();
    } else {
      throw Exception('Failed to load tags');
    }
  }

  Future<List<String>> getLanguages() async {
    final uri = Uri.parse('$_baseUrl/json/languages');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => json['name'] as String).toList();
    } else {
      throw Exception('Failed to load languages');
    }
  }

  Future<List<RadioStation>> getTopStations({int limit = 100}) async {
    return searchStations(limit: limit, order: 'votes', reverse: true);
  }

  Future<List<RadioStation>> getTrendingStations({int limit = 100}) async {
    return searchStations(limit: limit, order: 'clicktrend', reverse: true);
  }

  Future<List<RadioStation>> getStationsByCountry(String country, {int limit = 100}) async {
    return searchStations(country: country, limit: limit, order: 'votes', reverse: true);
  }

  Future<List<RadioStation>> getStationsByGenre(String genre, {int limit = 100}) async {
    return searchStations(tag: genre, limit: limit, order: 'votes', reverse: true);
  }

  Future<List<RadioStation>> getStationsByLanguage(String language, {int limit = 100}) async {
    return searchStations(language: language, limit: limit, order: 'votes', reverse: true);
  }

  Future<List<RadioStation>> getMusicStations({int limit = 100}) async {
    final musicGenres = ['pop', 'rock', 'jazz', 'classical', 'electronic', 'hip hop', 'country', 'reggae'];
    final List<RadioStation> allStations = [];
    for (final genre in musicGenres) {
      final stations = await searchStations(tag: genre, limit: (limit / musicGenres.length).round(), order: 'votes', reverse: true);
      allStations.addAll(stations);
    }
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
    final List<RadioStation> allStations = [];
    for (final tag in talkTags) {
      final stations = await searchStations(tag: tag, limit: (limit / talkTags.length).round(), order: 'votes', reverse: true);
      allStations.addAll(stations);
    }
    return allStations.take(limit).toList();
  }

  Future<List<RadioStation>> getLiveStations({int limit = 200}) async {
    return searchStations(tag: 'live', limit: limit, order: 'votes', reverse: true);
  }

  Future<List<RadioStation>> getGlobalAmFmStations({int limit = 500}) async {
    final List<RadioStation> allStations = [];

    // Get stations from multiple sources for better variety
    final amStations = await searchStations(
      tag: 'am',
      limit: (limit / 4).round(),
      order: 'clicktrend',
      reverse: true,
      hasGeoInfo: false,
    );

    final fmStations = await searchStations(
      tag: 'fm',
      limit: (limit / 4).round(),
      order: 'clicktrend',
      reverse: true,
      hasGeoInfo: false,
    );

    // Get additional stations by country for global coverage
    final usStations = await searchStations(
      country: 'United States',
      tag: 'fm',
      limit: (limit / 4).round(),
      order: 'votes',
      reverse: true,
    );

    final ukStations = await searchStations(
      country: 'United Kingdom',
      tag: 'fm',
      limit: (limit / 8).round(),
      order: 'votes',
      reverse: true,
    );

    final germanStations = await searchStations(
      country: 'Germany',
      tag: 'fm',
      limit: (limit / 8).round(),
      order: 'votes',
      reverse: true,
    );

    allStations.addAll(amStations);
    allStations.addAll(fmStations);
    allStations.addAll(usStations);
    allStations.addAll(ukStations);
    allStations.addAll(germanStations);

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

  Future<List<RadioStation>> getTanzaniaStations({int limit = 100}) async {
    return searchStations(country: 'Tanzania', limit: limit, order: 'votes', reverse: true);
  }

  Future<List<RadioStation>> getNearbyStations({required double lat, required double lon, int limit = 50}) async {
    return getStationsByLocation(lat: lat, lon: lon, limit: limit);
  }
}
