import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  final Color _primaryColor = const Color(0xFFE53935);
  final Color _secondaryColor = const Color(0xFFFF5252);

  Color get primaryColor => _primaryColor;
  Color get secondaryColor => _secondaryColor;

  ThemeData get theme => _lightTheme;

  static final TextTheme _textTheme = TextTheme(
    displayLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E), letterSpacing: -0.5),
    displayMedium: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E), letterSpacing: -0.5),
    displaySmall: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
    headlineMedium: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1A1C1E)),
    headlineSmall: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1C1E)),
    titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
    titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1C1E)),
    titleSmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1C1E)),
    bodyLarge: const TextStyle(fontSize: 16, color: Color(0xFF1A1C1E), height: 1.5),
    bodyMedium: TextStyle(fontSize: 14, color: const Color(0xFF1A1C1E).withValues(alpha: 0.8), height: 1.5),
    bodySmall: TextStyle(fontSize: 12, color: const Color(0xFF1A1C1E).withValues(alpha: 0.6), height: 1.4),
    labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
  );

  static final ThemeData _lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFE53935),
      primary: const Color(0xFFE53935),
      onPrimary: Colors.white,
      secondary: const Color(0xFFD32F2F),
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: const Color(0xFF1A1C1E),
      surfaceContainerHighest: const Color(0xFFF1F3F4),
      outline: const Color(0xFFE0E0E0),
      outlineVariant: const Color(0xFFEEEEEE),
    ),
    scaffoldBackgroundColor: const Color(0xFFFFFFFF),
    dividerTheme: DividerThemeData(
      color: const Color(0xFF1A1C1E).withValues(alpha: 0.08),
      thickness: 1,
      space: 1,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Color(0xFFE53935),
      unselectedLabelColor: Color(0x991A1C1E),
      indicatorColor: Color(0xFFE53935),
      labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      indicatorSize: TabBarIndicatorSize.label,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: const Color(0xFF1A1C1E),
      elevation: 0,
      centerTitle: true,
      titleTextStyle: _textTheme.titleLarge?.copyWith(color: const Color(0xFF1A1C1E)),
      iconTheme: const IconThemeData(color: Color(0xFF1A1C1E), size: 24),
    ),
    iconTheme: const IconThemeData(color: Color(0xFF1A1C1E), size: 24),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: const Color(0xFF1A1C1E).withValues(alpha: 0.05)),
      ),
    ),
    textTheme: _textTheme,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF8F9FA),
      side: BorderSide(color: const Color(0xFF1A1C1E).withValues(alpha: 0.05)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: _textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF1A1C1E)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      selectedColor: const Color(0xFFE53935),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8F9FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
      ),
      labelStyle: const TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w600),
      hintStyle: TextStyle(color: const Color(0xFF1A1C1E).withValues(alpha: 0.4)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      height: 72,
      indicatorColor: const Color(0xFFE53935).withValues(alpha: 0.08),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Color(0xFFE53935), size: 28);
        }
        return IconThemeData(color: const Color(0xFF1A1C1E).withValues(alpha: 0.6), size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold, fontSize: 12);
        }
        return TextStyle(color: const Color(0xFF1A1C1E).withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w500);
      }),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: const Color(0xFFE53935),
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
