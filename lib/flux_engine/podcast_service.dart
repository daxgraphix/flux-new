import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:intl/intl.dart';
import '../flux_ui/models/podcast.dart';

class PodcastService {
  Future<List<Episode>> fetchEpisodes(String rssUrl) async {
    if (rssUrl.isEmpty) return [];
    
    try {
      final response = await http.get(Uri.parse(rssUrl)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');
        
        return items.map((node) {
          final title = node.findElements('title').isNotEmpty 
              ? node.findElements('title').first.innerText 
              : 'Untitled Episode';
          final description = node.findElements('description').isNotEmpty 
              ? node.findElements('description').first.innerText 
              : '';
          final enclosures = node.findElements('enclosure');
          if (enclosures.isEmpty) return null;
          
          final enclosure = enclosures.first;
          final audioUrl = enclosure.getAttribute('url') ?? '';
          if (audioUrl.isEmpty) return null;

          final durationStr = node.findElements('itunes:duration').isNotEmpty 
              ? node.findElements('itunes:duration').first.innerText 
              : '0';
          final pubDateStr = node.findElements('pubDate').isNotEmpty 
              ? node.findElements('pubDate').first.innerText 
              : '';
          final image = node.findElements('itunes:image').isNotEmpty 
              ? node.findElements('itunes:image').first.getAttribute('href') ?? ''
              : '';

          return Episode(
            id: audioUrl, // Using audio URL as ID for now
            title: title,
            description: _stripHtml(description),
            audio: audioUrl,
            duration: _parseDuration(durationStr),
            pubDate: _parsePubDate(pubDateStr),
            image: image,
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
      if (parts.length == 3) {
        return int.parse(parts[0]) * 3600 + int.parse(parts[1]) * 60 + int.parse(parts[2]);
      } else if (parts.length == 2) {
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      }
    }
    return int.tryParse(duration) ?? 0;
  }

  DateTime _parsePubDate(String date) {
    try {
      // Common RFC 822 format: "Mon, 02 Jan 2006 15:04:05 -0700"
      // Note: Some feeds might vary, so we try multiple formats or use intl
      final format = DateFormat("EEE, dd MMM yyyy HH:mm:ss Z");
      return format.parse(date);
    } catch (e) {
      try {
         return DateTime.parse(date);
      } catch (e2) {
        return DateTime.now();
      }
    }
  }
}
