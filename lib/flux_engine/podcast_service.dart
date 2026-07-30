import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import '../flux_ui/models/podcast.dart';

class PodcastService {
  static const String _podcastsCacheBox = 'podcasts_cache';
  static const String _episodesCacheBox = 'episodes_cache';
  static const String _lastCheckedBox = 'podcast_last_checked';

  Future<void> init() async {
    await Hive.openBox(_podcastsCacheBox);
    await Hive.openBox(_episodesCacheBox);
    await Hive.openBox('podcast_updates');
    await Hive.openBox(_lastCheckedBox);
  }

  Future<Map<String, bool>> validateStaticPodcastFeeds() async {
    final results = <String, bool>{};
    try {
      final String response = await rootBundle.loadString('assets/data/podcasts.json');
      final data = json.decode(response) as Map<String, dynamic>;
      
      for (final category in data.values) {
        final List<dynamic> list = category as List<dynamic>;
        for (final item in list) {
          final rss = item['rss'] as String? ?? '';
          if (rss.isEmpty || results.containsKey(rss)) continue;
          
          try {
            final uri = Uri.parse(rss);
            final response = await http.head(uri).timeout(const Duration(seconds: 8));
            results[rss] = response.statusCode == 200;
          } catch (e) {
            results[rss] = false;
          }
        }
      }
    } catch (e) {
      debugPrint('Error validating podcast feeds: $e');
    }
    return results;
  }

  Future<List<Podcast>> searchPodcasts(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final url = Uri.parse('https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&media=podcast&limit=50');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        
        final podcasts = results.map((item) => Podcast(
          id: item['collectionId'].toString(),
          title: item['collectionName'] ?? '',
          publisher: item['artistName'] ?? '',
          image: item['artworkUrl600'] ?? item['artworkUrl100'] ?? '',
          description: '', // iTunes doesn't provide full description in search
          rss: item['feedUrl'] ?? '',
          genres: List<String>.from(item['genres'] ?? []),
        )).where((p) => p.rss.isNotEmpty).toList();

        // If it's a category search, we might want to inject static ones
        final staticPodcasts = await getStaticPodcastsByCategory(query.toLowerCase());
        if (staticPodcasts.isNotEmpty) {
          // Merge and avoid duplicates by RSS
          final seenRss = <String>{};
          for (var p in staticPodcasts) {
            seenRss.add(p.rss);
          }
          final filteredFetched = podcasts.where((p) => !seenRss.contains(p.rss)).toList();
          return [...staticPodcasts, ...filteredFetched];
        }
        
        return podcasts;
      }
    } catch (e) {
      debugPrint('Error searching podcasts: $e');
    }
    return getStaticPodcastsByCategory(query.toLowerCase());
  }

  static Future<List<Podcast>> getStaticPodcastsByCategory(String category) async {
    try {
      final String response = await rootBundle.loadString('assets/data/podcasts.json');
      final data = await json.decode(response) as Map<String, dynamic>;
      
      if (data.containsKey(category)) {
        final list = data[category] as List;
        return list.map((item) => Podcast.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Error loading static podcasts: $e');
    }
    return [];
  }

  Future<List<Podcast>> fetchTrendingPodcasts({int limit = 20}) async {
    try {
      final url = Uri.parse('https://itunes.apple.com/us/rss/toppodcasts/limit=$limit/json');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final entries = data['feed']['entry'] as List;
        
        return entries.map((item) {
          final id = item['id']['attributes']['im:id'].toString();
          final title = item['im:name']['label'] ?? '';
          final publisher = item['im:artist']['label'] ?? '';
          final images = item['im:image'] as List;
          final image = images.last['label'] ?? '';
          final description = item['summary']?['label'] ?? '';
          
          return Podcast(
            id: id,
            title: title,
            publisher: publisher,
            image: image,
            description: description,
            rss: '', 
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching trending podcasts: $e');
    }
    return [];
  }

  Future<String?> lookupPodcastRss(String collectionId) async {
    try {
      final url = Uri.parse('https://itunes.apple.com/lookup?id=$collectionId');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          return results.first['feedUrl'];
        }
      }
    } catch (e) {
      debugPrint('Error looking up podcast: $e');
    }
    return null;
  }

  Future<List<Episode>> fetchEpisodes(String rssUrl, {bool forceRefresh = false}) async {
    if (rssUrl.isEmpty) return [];
    
    final box = Hive.box(_episodesCacheBox);
    final lastCheckedBox = Hive.box(_lastCheckedBox);
    
    // Check cache first if not forcing refresh
    if (!forceRefresh) {
      try {
        final cached = box.get(rssUrl);
        final lastChecked = lastCheckedBox.get(rssUrl) as int?;
        
        if (cached != null && lastChecked != null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          // Use 1 hour as stale period for SWR
          if (now - lastChecked < 3600000) {
            final List<dynamic> list = json.decode(cached);
            return list.map((item) => Episode.fromJson(item)).toList();
          }
          
          // If stale, return cached but fetch in background (SWR)
          _fetchAndCacheInBackground(rssUrl);
          final List<dynamic> list = json.decode(cached);
          return list.map((item) => Episode.fromJson(item)).toList();
        }
      } catch (e) {
        debugPrint('Error reading episodes from cache: $e');
      }
    }

    return _performFetch(rssUrl);
  }

  Future<void> _fetchAndCacheInBackground(String rssUrl) async {
    try {
      await _performFetch(rssUrl);
    } catch (e) {
      debugPrint('Background fetch failed for $rssUrl: $e');
    }
  }

  Future<List<Episode>> _performFetch(String rssUrl) async {
    try {
      final response = await http.get(Uri.parse(rssUrl)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        XmlDocument document;
        try {
          document = XmlDocument.parse(body);
        } catch (e) {
          debugPrint('Malformed XML for $rssUrl');
          rethrow;
        }
        final items = document.findAllElements('item');
        
        final channelImage = document.findAllElements('channel').isNotEmpty && 
                document.findAllElements('channel').first.findElements('itunes:image').isNotEmpty 
            ? document.findAllElements('channel').first.findElements('itunes:image').first.getAttribute('href') ?? ''
            : '';

        final episodes = <Episode>[];
        for (final node in items) {
          try {
            final title = node.findElements('title').isNotEmpty 
                ? node.findElements('title').first.innerText 
                : 'Untitled Episode';
            final description = node.findElements('description').isNotEmpty 
                ? node.findElements('description').first.innerText 
                : (node.findElements('itunes:summary').isNotEmpty ? node.findElements('itunes:summary').first.innerText : '');
            
            final enclosures = node.findElements('enclosure');
            if (enclosures.isEmpty) continue;
            
            final enclosure = enclosures.first;
            final audioUrl = enclosure.getAttribute('url') ?? '';
            if (audioUrl.isEmpty) continue;

            String durationStr = '0';
            final itunesDuration = node.findElements('itunes:duration');
            if (itunesDuration.isNotEmpty) {
              durationStr = itunesDuration.first.innerText;
            }

            final pubDateStr = node.findElements('pubDate').isNotEmpty 
                ? node.findElements('pubDate').first.innerText 
                : '';
            
            String imageUrl = '';
            final itunesImage = node.findElements('itunes:image');
            if (itunesImage.isNotEmpty) {
              imageUrl = itunesImage.first.getAttribute('href') ?? '';
            }
            if (imageUrl.isEmpty) imageUrl = channelImage;

            episodes.add(Episode(
              id: audioUrl, 
              title: title,
              description: _stripHtml(description),
              audio: audioUrl,
              duration: _parseDuration(durationStr),
              pubDate: _parsePubDate(pubDateStr),
              image: imageUrl,
            ));
          } catch (e) {
            continue;
          }
        }

        // Cache the episodes
        final box = Hive.box(_episodesCacheBox);
        final lastCheckedBox = Hive.box(_lastCheckedBox);
        await box.put(rssUrl, json.encode(episodes.map((e) => e.toJson()).toList()));
        await lastCheckedBox.put(rssUrl, DateTime.now().millisecondsSinceEpoch);

        return episodes;
      }
    } catch (e) {
      debugPrint('Error performing fetch: $e');
    }
    return [];
  }

  Future<DateTime?> getLastUpdated(String rssUrl) async {
    final box = Hive.box('podcast_updates');
    final timestamp = box.get(rssUrl) as int?;
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  Future<void> setLastUpdated(String rssUrl, DateTime dateTime) async {
    final box = Hive.box('podcast_updates');
    await box.put(rssUrl, dateTime.millisecondsSinceEpoch);
  }

  Future<int> checkNewEpisodes(String rssUrl) async {
    final lastUpdated = await getLastUpdated(rssUrl);
    if (lastUpdated == null) {
      // First time checking, fetch and set last updated
      final episodes = await fetchEpisodes(rssUrl);
      if (episodes.isNotEmpty) {
        await setLastUpdated(rssUrl, episodes.first.pubDate);
      }
      return 0;
    }

    try {
      final response = await http.get(Uri.parse(rssUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        XmlDocument document;
        try {
          document = XmlDocument.parse(body);
        } catch (e) {
          debugPrint('Malformed XML for $rssUrl check: $e');
          return 0;
        }
        final items = document.findAllElements('item');
        
        int newCount = 0;
        DateTime? newestDate;

        for (final node in items) {
          final pubDateStr = node.findElements('pubDate').isNotEmpty 
              ? node.findElements('pubDate').first.innerText 
              : '';
          if (pubDateStr.isEmpty) continue;

          final pubDate = _parsePubDate(pubDateStr);
          
          if (newestDate == null || pubDate.isAfter(newestDate)) {
            newestDate = pubDate;
          }

          if (pubDate.isAfter(lastUpdated)) {
            newCount++;
          } else {
            // Items are usually ordered by date descending
            break;
          }
        }

        if (newestDate != null && newestDate.isAfter(lastUpdated)) {
          await setLastUpdated(rssUrl, newestDate);
        }

        return newCount;
      }
    } catch (e) {
      debugPrint('Error checking for new episodes: $e');
    }
    return 0;
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ').trim();
  }

  int _parseDuration(String duration) {
    if (duration.contains(':')) {
      final parts = duration.split(':');
      try {
        if (parts.length == 3) {
          return int.parse(parts[0]) * 3600 + int.parse(parts[1]) * 60 + int.parse(parts[2]);
        } else if (parts.length == 2) {
          return int.parse(parts[0]) * 60 + int.parse(parts[1]);
        }
      } catch (e) {
        return 0;
      }
    }
    return int.tryParse(duration) ?? 0;
  }

  DateTime _parsePubDate(String date) {
    try {
      return DateFormat("EEE, d MMM yyyy HH:mm:ss Z").parse(date);
    } catch (e) {
      try {
        return DateFormat("EEE, d MMM yyyy HH:mm:ss zzz").parse(date);
      } catch (e2) {
        try {
          return DateTime.parse(date);
        } catch (e3) {
          return DateTime.now();
        }
      }
    }
  }
}
