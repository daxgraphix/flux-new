import 'package:audio_session/audio_session.dart';
import 'radio_engine.dart';

class BackgroundAudioService {
  static final BackgroundAudioService _instance = BackgroundAudioService._internal();
  factory BackgroundAudioService() => _instance;
  BackgroundAudioService._internal();

  bool _isConfigured = false;

  Future<void> configure() async {
    if (_isConfigured) return;
    
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _isConfigured = true;
  }

  Future<void> ensurePlaying(RadioEngine engine) async {
    if (engine.currentStation != null && !engine.isPlaying) {
      try {
        await engine.player.play();
      } catch (_) {}
    }
  }
}