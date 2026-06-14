import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true;
  final Color _primaryColor = Colors.red;
  final Color _secondaryColor = const Color(0xFFFF6B6B);

  bool get isDarkMode => _isDarkMode;
  Color get primaryColor => _primaryColor;
  Color get secondaryColor => _secondaryColor;

  ThemeData get theme => _darkTheme;

  ThemeProvider() {
    _isDarkMode = true;
  }

  Future<void> loadTheme() async {
    _isDarkMode = true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('flux_dark_mode', _isDarkMode);
  }

  static final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.red,
    scaffoldBackgroundColor: const Color(0xFF0A0A0A),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0A0A0A),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardColor: const Color(0xFF1C1C1C),
    buttonTheme: const ButtonThemeData(
      buttonColor: Colors.red,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Colors.red,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF1C1C1C),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red),
      ),
      labelStyle: TextStyle(color: Colors.red),
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: Colors.transparent,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.grey,
    ),
splashFactory: NoSplash.splashFactory,
  );
}