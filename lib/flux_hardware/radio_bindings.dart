// ignore_for_file: camel_case_types, non_constant_identifier_names

import 'dart:ffi';
import 'dart:io';

// Load the library
final DynamicLibrary _radioLib = Platform.isAndroid
    ? DynamicLibrary.open('libradio.so')
    : throw UnsupportedError('Platform not supported');

// Struct definitions (simplified, based on v4l2)
final class v4l2_capability extends Struct {
  @Uint32()
  external int capabilities;
  @Array(32)
  external Array<Uint8> card;
  @Array(32)
  external Array<Uint8> driver;
  @Array(32)
  external Array<Uint8> bus_info;
  @Uint32()
  external int version;
  @Array(32)
  external Array<Uint8> reserved;
}

final class v4l2_tuner extends Struct {
  @Uint32()
  external int index;
  @Array(32)
  external Array<Uint8> name;
  @Uint32()
  external int type;
  @Uint32()
  external int capability;
  @Uint32()
  external int rangelow;
  @Uint32()
  external int rangehigh;
  @Uint32()
  external int rxsubchans;
  @Uint32()
  external int audmode;
  @Int32()
  external int signal;
  @Int32()
  external int afc;
  @Uint32()
  external int reserved;
}

final class v4l2_frequency extends Struct {
  @Uint32()
  external int tuner;
  @Uint32()
  external int type;
  @Uint32()
  external int frequency;
  @Uint32()
  external int reserved;
}

final class v4l2_hw_freq_seek extends Struct {
  @Uint32()
  external int tuner;
  @Uint32()
  external int type;
  @Uint32()
  external int seek_upward;
  @Uint32()
  external int wrap_around;
  @Uint32()
  external int spacing;
  @Uint32()
  external int rangelow;
  @Uint32()
  external int rangehigh;
  @Uint32()
  external int reserved;
}

final class v4l2_audio extends Struct {
  @Uint32()
  external int index;
  @Array(32)
  external Array<Uint8> name;
  @Uint32()
  external int capability;
  @Uint32()
  external int mode;
  @Uint32()
  external int reserved;
}

// Function signatures
typedef open_radio_func = Int32 Function();
typedef close_radio_func = Void Function(Int32);
typedef get_capabilities_func = Int32 Function(Int32, Pointer<v4l2_capability>);
typedef get_tuner_func = Int32 Function(Int32, Pointer<v4l2_tuner>);
typedef set_tuner_func = Int32 Function(Int32, Pointer<v4l2_tuner>);
typedef get_frequency_func = Int32 Function(Int32, Pointer<v4l2_frequency>);
typedef set_frequency_func = Int32 Function(Int32, Pointer<v4l2_frequency>);
typedef hw_seek_func = Int32 Function(Int32, Pointer<v4l2_hw_freq_seek>);
typedef get_audio_func = Int32 Function(Int32, Pointer<v4l2_audio>);
typedef set_audio_func = Int32 Function(Int32, Pointer<v4l2_audio>);

// Dart function pointers
final open_radio = _radioLib.lookupFunction<open_radio_func, int Function()>(
  'open_radio',
);
final close_radio = _radioLib
    .lookupFunction<close_radio_func, void Function(int)>('close_radio');
final get_capabilities = _radioLib
    .lookupFunction<
      get_capabilities_func,
      int Function(int, Pointer<v4l2_capability>)
    >('get_capabilities');
final get_tuner = _radioLib
    .lookupFunction<get_tuner_func, int Function(int, Pointer<v4l2_tuner>)>(
      'get_tuner',
    );
final set_tuner = _radioLib
    .lookupFunction<set_tuner_func, int Function(int, Pointer<v4l2_tuner>)>(
      'set_tuner',
    );
final get_frequency = _radioLib
    .lookupFunction<
      get_frequency_func,
      int Function(int, Pointer<v4l2_frequency>)
    >('get_frequency');
final set_frequency = _radioLib
    .lookupFunction<
      set_frequency_func,
      int Function(int, Pointer<v4l2_frequency>)
    >('set_frequency');
final hw_seek = _radioLib
    .lookupFunction<
      hw_seek_func,
      int Function(int, Pointer<v4l2_hw_freq_seek>)
    >('hw_seek');
final get_audio = _radioLib
    .lookupFunction<get_audio_func, int Function(int, Pointer<v4l2_audio>)>(
      'get_audio',
    );
final set_audio = _radioLib
    .lookupFunction<set_audio_func, int Function(int, Pointer<v4l2_audio>)>(
      'set_audio',
    );
