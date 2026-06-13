import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'flux_engine/radio_engine.dart';
import 'flux_engine/theme_provider.dart';
import 'flux_ui/main_screen.dart';
import 'flux_ui/onboarding_widget.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FluxApp());
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
  bool _onboardingCompleted = false;

  @override
  void initState() {
    super.initState();
    _engine = RadioEngine();
    _themeProvider = ThemeProvider();
    _themeProvider.loadTheme();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Hive.initFlutter();
    await _engine.storage.init();

    final prefs = await SharedPreferences.getInstance();
    _onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

    final initFuture = _engine.initialize();
    final preloadFuture = _onboardingCompleted ? _engine.loadTopStations() : Future.value();

    await Future.wait([initFuture, preloadFuture]);

    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        _appState = _onboardingCompleted ? AppState.main : AppState.onboarding;
      });
    }
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
          onComplete: () => setState(() => _appState = AppState.onboarding),
        );
      case AppState.onboarding:
        return OnboardingScreen(
          key: const ValueKey('onboarding'),
          onComplete: _onOnboardingComplete,
        );
      case AppState.main:
        return const MainScreen(key: ValueKey('main'));
    }
  }

  Future<void> _onOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    setState(() {
      _onboardingCompleted = true;
      _appState = AppState.main;
    });
  }
}

enum AppState {
  splash,
  onboarding,
  main,
}