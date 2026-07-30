import 'package:flutter/foundation.dart';
import 'audio_service_handler.dart';
import '../flux_storage/radio_storage.dart';

class AudioEffectsService extends ChangeNotifier {
  final RadioAudioHandler _audioHandler;

  List<double> _equalizerBands = [0.0, 0.0, 0.0, 0.0, 0.0];
  List<int> _equalizerCenterFrequencies = [60, 230, 910, 3600, 14000];
  double _loudnessGain = 0.0;
  double _bassBoostStrength = 0.0;
  double _speed = 1.0;
  double _pitch = 1.0;

  List<double> get equalizerBands => List.unmodifiable(_equalizerBands);
  List<int> get equalizerCenterFrequencies => List.unmodifiable(_equalizerCenterFrequencies);
  double get loudnessGain => _loudnessGain;
  double get bassBoostStrength => _bassBoostStrength;
  double get speed => _speed;
  double get pitch => _pitch;

  AudioEffectsService(this._audioHandler);

  Future<void> initialize() async {
    final equalizer = _audioHandler.equalizer;
    final parameters = await equalizer.parameters;
      
    _equalizerCenterFrequencies = parameters.bands.map((b) => b.centerFrequency.toInt()).toList();
    
    final savedEq = await RadioStorage().getEqualizer();
    final List<dynamic>? savedBands = savedEq['bands'];
    final double? savedLoudness = savedEq['loudness'];
    
    if (savedBands != null && savedBands.length == _equalizerCenterFrequencies.length) {
      _equalizerBands = savedBands.cast<double>();
      for (int i = 0; i < _equalizerBands.length; i++) {
        if (i < parameters.bands.length) {
          parameters.bands[i].setGain(_equalizerBands[i]);
        }
      }
    } else {
      _equalizerBands = parameters.bands.map((b) => b.gain).toList();
    }
    
    final loudness = _audioHandler.loudnessEnhancer;
    if (savedLoudness != null) {
      _loudnessGain = savedLoudness;
      _audioHandler.loudnessEnhancer.setTargetGain(_loudnessGain);
    } else {
      _loudnessGain = loudness.targetGain;
    }

    final savedBass = savedEq['bass_boost'];
    if (savedBass != null) {
      _bassBoostStrength = savedBass;
      // Note: bassBoost integration depends on just_audio_platform_interface support
    }

    _speed = await RadioStorage().getSettings<double>('speed', defaultValue: 1.0) ?? 1.0;
    _pitch = await RadioStorage().getSettings<double>('pitch', defaultValue: 1.0) ?? 1.0;
    
    await _audioHandler.setSpeed(_speed);
    await _audioHandler.player.setPitch(_pitch);
    
    notifyListeners();
  }

  void updateEqualizerBand(int index, double value) {
    if (index >= 0 && index < _equalizerBands.length) {
      _equalizerBands[index] = value;
      _audioHandler.equalizer.parameters.then((parameters) {
        if (index < parameters.bands.length) {
          parameters.bands[index].setGain(value);
          RadioStorage().saveEqualizer(_equalizerBands, _loudnessGain, bass: _bassBoostStrength, speed: _speed, pitch: _pitch);
        }
      });
      notifyListeners();
    }
  }

  Future<void> setSpeed(double value) async {
    _speed = value;
    await _audioHandler.setSpeed(value);
    await RadioStorage().saveSettings('speed', value);
    notifyListeners();
  }

  Future<void> setPitch(double value) async {
    _pitch = value;
    await _audioHandler.player.setPitch(value);
    await RadioStorage().saveSettings('pitch', value);
    notifyListeners();
  }

  Future<void> setLoudness(double value) async {
    _loudnessGain = value;
    await _audioHandler.loudnessEnhancer.setTargetGain(value);
    await RadioStorage().saveEqualizer(_equalizerBands, _loudnessGain, bass: _bassBoostStrength, speed: _speed, pitch: _pitch);
    notifyListeners();
  }

  Future<void> setBassBoostStrength(double value) async {
    _bassBoostStrength = value;
    // Note: bassBoost integration depends on just_audio_platform_interface support
    await RadioStorage().saveEqualizer(_equalizerBands, _loudnessGain, bass: _bassBoostStrength, speed: _speed, pitch: _pitch);
    notifyListeners();
  }

  void resetEqualizer() {
    for (int i = 0; i < _equalizerBands.length; i++) {
      _equalizerBands[i] = 0.0;
      _audioHandler.equalizer.parameters.then((parameters) {
        if (i < parameters.bands.length) {
          parameters.bands[i].setGain(0.0);
        }
      });
    }
    _loudnessGain = 0.0;
    _audioHandler.loudnessEnhancer.setTargetGain(0.0);
    _bassBoostStrength = 0.0;
    _speed = 1.0;
    _audioHandler.setSpeed(1.0);
    _pitch = 1.0;
    _audioHandler.player.setPitch(1.0);
    RadioStorage().saveEqualizer(_equalizerBands, _loudnessGain, bass: 0.0, speed: 1.0, pitch: 1.0);
    notifyListeners();
  }
}
