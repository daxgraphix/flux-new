import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:intl/intl.dart';
import '../flux_ui/models/podcast.dart';

class PodcastService {
  Future<List<Podcast>> searchPodcasts(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final url = Uri.parse('https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&media=podcast&limit=25');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        
        return results.map((item) => Podcast(
          id: item['collectionId'].toString(),
          title: item['collectionName'] ?? '',
          publisher: item['artistName'] ?? '',
          image: item['artworkUrl600'] ?? item['artworkUrl100'] ?? '',
          description: '', // iTunes doesn't provide full description in search
          rss: item['feedUrl'] ?? '',
          genres: List<String>.from(item['genres'] ?? []),
        )).where((p) => p.rss.isNotEmpty).toList();
      }
    } catch (e) {
      debugPrint('Error searching podcasts: $e');
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

  Future<List<Episode>> fetchEpisodes(String rssUrl) async {
    if (rssUrl.isEmpty) return [];
    
    try {
      final response = await http.get(Uri.parse(rssUrl)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        final document = XmlDocument.parse(body);
        final items = document.findAllElements('item');
        
        final channelImage = document.findAllElements('channel').first.findElements('itunes:image').isNotEmpty 
            ? document.findAllElements('channel').first.findElements('itunes:image').first.getAttribute('href') ?? ''
            : '';

        return items.map((node) {
          final title = node.findElements('title').isNotEmpty 
              ? node.findElements('title').first.innerText 
              : 'Untitled Episode';
          final description = node.findElements('description').isNotEmpty 
              ? node.findElements('description').first.innerText 
              : (node.findElements('itunes:summary').isNotEmpty ? node.findElements('itunes:summary').first.innerText : '');
          
          final enclosures = node.findElements('enclosure');
          if (enclosures.isEmpty) return null;
          
          final enclosure = enclosures.first;
          final audioUrl = enclosure.getAttribute('url') ?? '';
          if (audioUrl.isEmpty) return null;

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

          return Episode(
            id: audioUrl, 
            title: title,
            description: _stripHtml(description),
            audio: audioUrl,
            duration: _parseDuration(durationStr),
            pubDate: _parsePubDate(pubDateStr),
            image: imageUrl,
          );
        }).whereType<Episode>().toList();
      }
    } catch (e) {
      debugPrint('Error fetching episodes: $e');
    }
    return [];
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
