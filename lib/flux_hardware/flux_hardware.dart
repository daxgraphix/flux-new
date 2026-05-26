// ignore_for_file: depend_on_referenced_packages

import 'dart:ffi';
import 'radio_bindings.dart' as bindings;
import 'package:ffi/ffi.dart';

class RadioHardware {
  int? _fd;
  bool _isMock = false;

  bool get isOpen => _fd != null || _isMock;
  bool get isMock => _isMock;

  // Open the radio device
  bool open() {
    if (isOpen) return true;
    _fd = bindings.open_radio();
    if (_fd! >= 0) {
      return true;
    } else {
      // Fallback to mock mode
      _isMock = true;
      return true;
    }
  }

  // Close the radio device
  void close() {
    if (_isMock) {
      _isMock = false;
    } else if (_fd != null) {
      bindings.close_radio(_fd!);
      _fd = null;
    }
  }

  // Get capabilities
  bindings.v4l2_capability? getCapabilities() {
    if (_isMock) {
      // Mock capabilities
      final cap = calloc<bindings.v4l2_capability>();
      cap.ref.capabilities = 0x00000001; // Mock
      return cap.ref;
    }
    if (!isOpen) return null;
    final cap = calloc<bindings.v4l2_capability>();
    final result = bindings.get_capabilities(_fd!, cap);
    if (result < 0) {
      calloc.free(cap);
      return null;
    }
    final capability = cap.ref;
    calloc.free(cap);
    return capability;
  }

  // Get tuner
  Pointer<bindings.v4l2_tuner>? getTuner() {
    if (!isOpen) return null;
    final tuner = calloc<bindings.v4l2_tuner>();
    final result = bindings.get_tuner(_fd!, tuner);
    if (result < 0) {
      calloc.free(tuner);
      return null;
    }
    return tuner;
  }

  // Set tuner
  bool setTuner(bindings.v4l2_tuner tuner) {
    if (!isOpen) return false;
    final t = calloc<bindings.v4l2_tuner>()..ref = tuner;
    final result = bindings.set_tuner(_fd!, t);
    calloc.free(t);
    return result >= 0;
  }

  // Get frequency
  Pointer<bindings.v4l2_frequency>? getFrequency() {
    if (!isOpen) return null;
    final freq = calloc<bindings.v4l2_frequency>();
    final result = bindings.get_frequency(_fd!, freq);
    if (result < 0) {
      calloc.free(freq);
      return null;
    }
    return freq;
  }

  // Set frequency
  bool setFrequency(Pointer<bindings.v4l2_frequency> freqPtr) {
    if (!isOpen) return false;
    final result = bindings.set_frequency(_fd!, freqPtr);
    return result >= 0;
  }

  // Hardware seek
  bool hwSeek(Pointer<bindings.v4l2_hw_freq_seek> seekPtr) {
    if (!isOpen) return false;
    final result = bindings.hw_seek(_fd!, seekPtr);
    return result >= 0;
  }

  // Get audio
  bindings.v4l2_audio? getAudio() {
    if (!isOpen) return null;
    final audio = calloc<bindings.v4l2_audio>();
    final result = bindings.get_audio(_fd!, audio);
    if (result < 0) {
      calloc.free(audio);
      return null;
    }
    final a = audio.ref;
    calloc.free(audio);
    return a;
  }

  // Set audio (for mute)
  bool setAudio(Pointer<bindings.v4l2_audio> audioPtr) {
    if (!isOpen) return false;
    final result = bindings.set_audio(_fd!, audioPtr);
    return result >= 0;
  }
}
