import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../flux_ui/models/podcast.dart';

class DownloadService extends ChangeNotifier {
  final Map<String, double> _progress = {};
  final Set<String> _downloadingIds = {};

  double getDownloadProgress(String id) => _progress[id] ?? 0.0;
  bool isDownloading(String id) => _downloadingIds.contains(id);

  Future<String?> downloadEpisode(Episode episode) async {
    if (_downloadingIds.contains(episode.id)) return null;

    try {
      _downloadingIds.add(episode.id);
      _progress[episode.id] = 0.0;
      notifyListeners();

      final dir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(dir.path, 'downloads'));
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final fileName = '${episode.id.hashCode}_${p.basename(Uri.parse(episode.audio).path)}';
      final filePath = p.join(downloadsDir.path, fileName);
      final file = File(filePath);

      if (await file.exists()) {
        _cleanup(episode.id);
        return filePath;
      }

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(episode.audio));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Failed to download file: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      int downloaded = 0;

      final sink = file.openWrite();
      await response.stream.forEach((chunk) {
        downloaded += chunk.length;
        sink.add(chunk);
        if (contentLength > 0) {
          _progress[episode.id] = downloaded / contentLength;
          notifyListeners();
        }
      });

      await sink.close();
      _cleanup(episode.id);
      return filePath;
    } catch (e) {
      debugPrint('Download failed: $e');
      _cleanup(episode.id);
      return null;
    }
  }

  void _cleanup(String id) {
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
}
