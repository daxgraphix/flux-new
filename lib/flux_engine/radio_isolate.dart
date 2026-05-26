// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:isolate';
import 'dart:ffi';
import '../flux_hardware/flux_hardware.dart';
import 'package:ffi/ffi.dart';

class RadioIsolate {
  ReceivePort? _receivePort;
  SendPort? _sendPort;
  Isolate? _isolate;
  bool _running = false;

  Future<void> start() async {
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_isolateEntry, _receivePort!.sendPort);
    _sendPort = await _receivePort!.first as SendPort;
    _running = true;
  }

  static void _isolateEntry(SendPort sendPort) {
    final hardware = RadioHardware();
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      if (message is String) {
        switch (message) {
          case 'poll':
            if (hardware.isOpen) {
              final tuner = hardware.getTuner();
              if (tuner != null) {
                sendPort.send({
                  'rssi': tuner.ref.signal,
                  'frequency': hardware.getFrequency()?.ref.frequency ?? 0,
                });
                calloc.free(tuner);
              }
            }
            break;
          case 'stop':
            receivePort.close();
            break;
        }
      }
    });
  }

  Stream<Map<String, dynamic>> poll() async* {
    if (!_running) return;
    _sendPort?.send('poll');
    await for (final message in _receivePort!) {
      if (message is Map<String, dynamic>) {
        yield message;
        break;
      }
    }
  }

  Future<void> stop() async {
    _running = false;
    _sendPort?.send('stop');
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort?.close();
  }
}
