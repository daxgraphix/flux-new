import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../flux_ui/models/podcast.dart';

class DownloadService extends ChangeNotifier {
  final Map<String, double> _progress = {};
  final Set<String> _downloadingIds = {};
  final Map<String, http.Client> _activeClients = {};

  double getDownloadProgress(String id) => _progress[id] ?? 0.0;
  bool isDownloading(String id) => _downloadingIds.contains(id);

  Future<String?> downloadEpisode(Episode episode) async {
    if (_downloadingIds.contains(episode.id)) return null;

    String? filePath;
    try {
      _downloadingIds.add(episode.id);
      _progress[episode.id] = 0.0;
      notifyListeners();

      final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(dir.path, 'FluxRadioDownloads'));
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final fileName = '${episode.id.hashCode}_${p.basename(Uri.parse(episode.audio).path)}';
      filePath = p.join(downloadsDir.path, fileName);
      final file = File(filePath);

      if (await file.exists()) {
        final length = await file.length();
        if (length > 0) {
          _cleanup(episode.id);
          return filePath;
        } else {
          await file.delete();
        }
      }

      final client = http.Client();
      _activeClients[episode.id] = client;

      var request = http.Request('GET', Uri.parse(episode.audio));
      var response = await client.send(request);

      // Handle Redirects manually for StreamedResponse
      int redirectCount = 0;
      while ([301, 302, 303, 307, 308].contains(response.statusCode) && redirectCount < 5) {
        final location = response.headers['location'];
        if (location == null) break;
        
        final uri = Uri.parse(location);
        request = http.Request('GET', uri);
        response = await client.send(request);
        redirectCount++;
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to download file: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      int downloaded = 0;

      final sink = file.openWrite();
      try {
        await response.stream.forEach((chunk) {
          downloaded += chunk.length;
          sink.add(chunk);
          if (contentLength > 0) {
            _progress[episode.id] = downloaded / contentLength;
            notifyListeners();
          }
        });
        await sink.close();
      } catch (e) {
        await sink.close();
        if (await file.exists()) await file.delete();
        rethrow;
      }

      _cleanup(episode.id);
      return filePath;
    } catch (e) {
      debugPrint('Download failed for ${episode.title}: $e');
      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) await file.delete();
      }
      _cleanup(episode.id);
      return null;
    }
  }

  void cancelDownload(String id) {
    if (_activeClients.containsKey(id)) {
      _activeClients[id]?.close();
      _activeClients.remove(id);
      _downloadingIds.remove(id);
      _progress.remove(id);
      notifyListeners();
    }
  }

  void _cleanup(String id) {
    _activeClients[id]?.close();
    _activeClients.remove(id);
    _downloadingIds.remove(id);
    _progress.remove(id);
    notifyListeners();
  }

  Future<void> deleteEpisode(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting episode: $e');
    }
  }

  Future<void> clearAllDownloads() async {
    try {
      final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(dir.path, 'FluxRadioDownloads'));
      if (await downloadsDir.exists()) {
        await downloadsDir.delete(recursive: true);
        await downloadsDir.create(recursive: true);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing all downloads: $e');
    }
  }

  Future<int> getTotalDownloadSize() async {
    try {
      final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(dir.path, 'FluxRadioDownloads'));
      if (!await downloadsDir.exists()) return 0;
      
      int totalBytes = 0;
      await for (final entity in downloadsDir.list(recursive: false)) {
        if (entity is File) {
          totalBytes += await entity.length();
        }
      }
      return totalBytes;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getDownloadCount() async {
    try {
      final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(dir.path, 'FluxRadioDownloads'));
      if (!await downloadsDir.exists()) return 0;
      
      int count = 0;
      await for (final entity in downloadsDir.list(recursive: false)) {
        if (entity is File) count++;
      }
      return count;
    } catch (e) {
      return 0;
    }
  }
}
