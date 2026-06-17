import 'dart:async';
import 'dart:io';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'flux_engine/radio_engine.dart';
import 'flux_engine/theme_provider.dart';
import 'flux_engine/audio_service_handler.dart';
import 'flux_ui/main_screen.dart';
import 'flux_ui/onboarding_widget.dart';

late AudioHandler _audioHandler;

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

Future<AudioHandler> _createAudioHandler() async {
  try {
    return await initAudioService().timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('Audio service initialization failed or timed out: $e');
    return RadioAudioHandler();
  }
}

class FluxApp extends StatefulWidget {
  const FluxApp({super.key});

  @override
  State<FluxApp> createState() => _FluxAppState();
}

class _FluxAppState extends State<FluxApp> {
  late RadioEngine _engine;
  late ThemeProvider _themeProvider;
  AppState _appState = AppState.splash;

  @override
  void initState() {
    super.initState();
    _engine = RadioEngine(_audioHandler);
    _themeProvider = ThemeProvider();
    _themeProvider.loadTheme();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await _engine.initialize().timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('Engine initialization failed or timed out: $e');
    }
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<RadioEngine>(create: (_) => _engine),
        ChangeNotifierProvider<ThemeProvider>.value(value: _themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Flux Radio',
            theme: themeProvider.theme,
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
        return const MainScreen(key: ValueKey('main'));
    }
  }
}

enum AppState {
  splash,
  main,
}
