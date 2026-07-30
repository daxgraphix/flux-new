import 'dart:async';
import 'dart:io';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'flux_engine/theme_provider.dart';
import 'flux_engine/audio_service_handler.dart';
import 'flux_ui/navigation_wrapper.dart';
import 'flux_ui/onboarding_widget.dart';

import 'flux_engine/recording_service.dart';
import 'flux_engine/alarm_service.dart';
import 'flux_engine/station_provider.dart';
import 'flux_engine/download_service.dart';
import 'flux_hardware/radio_service.dart';
import 'flux_engine/playback_controller.dart';
import 'flux_engine/audio_effects_service.dart';
import 'flux_engine/library_manager.dart';
import 'flux_engine/settings_service.dart';
import 'flux_storage/radio_storage.dart';
import 'flux_ui/route_observer.dart';

late RadioAudioHandler _audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  _audioHandler = await _createAudioHandler();
  
  if (Platform.isAndroid) {
    await AndroidAlarmManager.initialize();
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  runApp(const FluxApp());
}

Future<RadioAudioHandler> _createAudioHandler() async {
  try {
    return await initAudioService().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('Audio service initialization failed or timed out: $e');
  }
  return RadioAudioHandler();
}

class FluxApp extends StatefulWidget {
  const FluxApp({super.key});

  @override
  State<FluxApp> createState() => _FluxAppState();
}

class _FluxAppState extends State<FluxApp> {
  late ThemeProvider _themeProvider;
  late RecordingService _recordingService;
  late AlarmService _alarmService;
  late StationProvider _stationProvider;
  late DownloadService _downloadService;
  late PlaybackController _playbackController;
  late AudioEffectsService _audioEffectsService;
  late LibraryManager _libraryManager;
  late SettingsService _settingsService;
  AppState _appState = AppState.splash;

  @override
  void initState() {
    super.initState();
    _recordingService = RecordingService();
    _alarmService = AlarmService();
    _stationProvider = StationProvider();
    _downloadService = DownloadService();
    _playbackController = PlaybackController(_audioHandler);
    _audioEffectsService = AudioEffectsService(_audioHandler);
    _libraryManager = LibraryManager();
    _settingsService = SettingsService();
    _themeProvider = ThemeProvider();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await RadioStorage().init();
      await _stationProvider.initialize();
      await _alarmService.initialize();
      await _playbackController.initialize();
      await _settingsService.loadSettings();
      await _audioEffectsService.initialize();
      await _libraryManager.loadLibrary();
      await _recordingService.loadSavedRecordings();
    } catch (e) {
      debugPrint('Initialization failed: $e');
    }
  }

  @override
  void dispose() {
    _playbackController.dispose();
    _recordingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: _themeProvider),
        ChangeNotifierProvider<RecordingService>.value(value: _recordingService),
        ChangeNotifierProvider<AlarmService>.value(value: _alarmService),
        ChangeNotifierProvider<StationProvider>.value(value: _stationProvider),
        ChangeNotifierProvider<DownloadService>.value(value: _downloadService),
        ChangeNotifierProvider<PlaybackController>.value(value: _playbackController),
        ChangeNotifierProvider<AudioEffectsService>.value(value: _audioEffectsService),
        ChangeNotifierProvider<LibraryManager>.value(value: _libraryManager),
        ChangeNotifierProvider<SettingsService>.value(value: _settingsService),
        Provider<RadioService>(create: (_) => RadioService()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Flux Radio',
            theme: themeProvider.theme,
            themeMode: ThemeMode.light,
            navigatorObservers: [routeObserver],
            builder: (context, child) {
              return DefaultTextStyle.merge(
                style: const TextStyle(decoration: TextDecoration.none),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: _buildHome(),
          );
        },
      ),
    );
  }

  Widget _buildHome() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: _getCurrentScreen(),
    );
  }

  Widget _getCurrentScreen() {
    switch (_appState) {
      case AppState.splash:
        return SplashScreen(
          key: const ValueKey('splash'),
          onComplete: () => setState(() => _appState = AppState.main),
        );
      case AppState.main:
        return const NavigationWrapper(key: ValueKey('main'));
    }
  }
}

enum AppState {
  splash,
  main,
}
