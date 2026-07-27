import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../flux_hardware/radio_service.dart';

class RecordingService extends ChangeNotifier {
  bool _isRecording = false;
  String? _recordingPath;
  DateTime? _recordingStartTime;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  HttpClient? _recordingClient;
  HttpClientRequest? _recordingRequest;
  HttpClientResponse? _recordingResponse;
  IOSink? _recordingSink;

  bool get isRecording => _isRecording;
  String? get recordingPath => _recordingPath;
  Duration get recordingDuration => _recordingDuration;
  DateTime? get recordingStartTime => _recordingStartTime;

  Future<bool> startRecording(RadioStation station) async {
    if (_isRecording) return false;

    // Request permission first
    var status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    
    if (!status.isGranted) return false;

    try {
      Directory? recordingsDir;
      if (Platform.isAndroid) {
        recordingsDir = Directory('/storage/emulated/0/Music/FluxRecordings');
      } else {
        final dir = await getApplicationDocumentsDirectory();
        recordingsDir = Directory('${dir.path}/Recordings');
      }
      
      if (!await recordingsDir.exists()) await recordingsDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cleanName = station.name.replaceAll(RegExp(r'[^\w\s]+'), '_').replaceAll(' ', '_');
      _recordingPath = '${recordingsDir.path}/${cleanName}_$timestamp.mp3';
      
      _isRecording = true;
      _recordingStartTime = DateTime.now();
      _recordingDuration = Duration.zero;

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_recordingStartTime != null) {
          _recordingDuration = DateTime.now().difference(_recordingStartTime!);
          notifyListeners();
        }
      });

      _recordingClient = HttpClient();
      _recordingRequest = await _recordingClient!.getUrl(Uri.parse(station.url));
      _recordingResponse = await _recordingRequest!.close();
      _recordingSink = File(_recordingPath!).openWrite();
      
      _recordingResponse!.listen(
        (chunk) => _recordingSink?.add(chunk),
        onError: (e) => stopRecording(),
        onDone: () => stopRecording(),
        cancelOnError: true,
      );
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Recording failed: $e');
      _isRecording = false;
      _cleanup();
      return false;
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;
    
    _isRecording = false;
    _recordingTimer?.cancel();
    await _recordingSink?.close();
    _recordingClient?.close();
    _cleanup();
    notifyListeners();
  }

  void _cleanup() {
    _recordingTimer = null;
    _recordingSink = null;
    _recordingClient = null;
    _recordingRequest = null;
    _recordingResponse = null;
  }

  Future<List<String>> getSavedRecordings() async {
    Directory? recordingsDir;
    if (Platform.isAndroid) {
      recordingsDir = Directory('/storage/emulated/0/Music/FluxRecordings');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      recordingsDir = Directory('${dir.path}/Recordings');
    }

    if (await recordingsDir.exists()) {
      final recordings = recordingsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.mp3'))
          .map((f) => f.path)
          .toList();
      recordings.sort((a, b) => b.compareTo(a)); // Newest first
      return recordings;
    }
    return [];
  }

  @override
  void dispose() {
    stopRecording();
    super.dispose();
  }
}
