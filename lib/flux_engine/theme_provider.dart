import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  ThemeData get theme => _isDarkMode ? _darkTheme : _lightTheme;

  static const Color _primaryLight = Color(0xFF4F46E5); // Indigo 600
  static const Color _primaryDark = Color(0xFFA5B4FC); // Indigo 300 (Higher contrast)
  static const Color _accent = Color(0xFFF43F5E); // Rose 500

  static final TextTheme _textTheme = TextTheme(
    displayLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.0),
    displayMedium: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8),
    displaySmall: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
    headlineMedium: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    headlineSmall: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    titleSmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    bodyLarge: const TextStyle(fontSize: 16, height: 1.6),
    bodyMedium: const TextStyle(fontSize: 14, height: 1.5),
    bodySmall: const TextStyle(fontSize: 12, height: 1.4),
    labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5),
  );

  static final ThemeData _lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryLight,
      primary: _primaryLight,
      onPrimary: Colors.white,
      secondary: _accent,
      onSecondary: Colors.white,
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF0F172A), // Slate 900 for better readability than pure black
      surfaceContainerHighest: const Color(0xFFF1F5F9),
      onSurfaceVariant: const Color(0xFF475569), // Slate 600
      outline: const Color(0xFFE2E8F0), // Slate 200
      outlineVariant: const Color(0xFFCBD5E1),
      error: const Color(0xFFDC2626),
    ),
    scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Slight off-white for depth
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF8FAFC),
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: TextStyle(color: Color(0xFF0F172A), fontSize: 22, fontWeight: FontWeight.w900),
      iconTheme: IconThemeData(color: Color(0xFF0F172A)),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
    ),
    textTheme: _textTheme.apply(
      bodyColor: const Color(0xFF0F172A),
      displayColor: const Color(0xFF0F172A),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: _primaryLight,
      unselectedLabelColor: Color(0xFF64748B),
      indicatorColor: _primaryLight,
      labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      indicatorSize: TabBarIndicatorSize.label,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 10,
      indicatorColor: _primaryLight.withValues(alpha: 0.1),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: _primaryLight, size: 28);
        }
        return const IconThemeData(color: Color(0xFF64748B));
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: _primaryLight, fontWeight: FontWeight.w900, fontSize: 12);
        }
        return const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700, fontSize: 12);
      }),
    ),
  );

  static final ThemeData _darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryDark,
      brightness: Brightness.dark,
      primary: _primaryDark,
      onPrimary: const Color(0xFF0F172A),
      secondary: _accent,
      onSecondary: Colors.white,
      surface: const Color(0xFF0F172A), // Slate 900
      onSurface: const Color(0xFFF8FAFC), // Slate 50
      surfaceContainerHighest: const Color(0xFF1E293B), // Slate 800
      onSurfaceVariant: const Color(0xFF94A3B8), // Slate 400
      outline: const Color(0xFF334155), // Slate 700
      outlineVariant: const Color(0xFF475569),
      error: const Color(0xFFF87171),
    ),
    scaffoldBackgroundColor: const Color(0xFF020617), // Very dark slate/black
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF020617),
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: TextStyle(color: Color(0xFFF8FAFC), fontSize: 22, fontWeight: FontWeight.w900),
      iconTheme: IconThemeData(color: Color(0xFFF8FAFC)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF1E293B)),
      ),
      color: const Color(0xFF0F172A),
    ),
    textTheme: _textTheme.apply(
      bodyColor: const Color(0xFFF8FAFC),
      displayColor: const Color(0xFFF8FAFC),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: _primaryDark,
      unselectedLabelColor: Color(0xFF94A3B8),
      indicatorColor: _primaryDark,
      labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      indicatorSize: TabBarIndicatorSize.label,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0F172A),
      elevation: 10,
      indicatorColor: _primaryDark.withValues(alpha: 0.15),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: _primaryDark, size: 28);
        }
        return const IconThemeData(color: Color(0xFF94A3B8));
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: _primaryDark, fontWeight: FontWeight.w900, fontSize: 12);
        }
        return const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w700, fontSize: 12);
      }),
    ),
  );

}

