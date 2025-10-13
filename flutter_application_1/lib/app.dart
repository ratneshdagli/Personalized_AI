import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemes {
  AppThemes._();

  static const Color _primaryNavy = Color(0xFF0B1220); // deep navy/charcoal
  static const Color _surfaceGlassDark = Color(0x66FFFFFF); // white with opacity
  static const Color _surfaceGlassLight = Color(0x33FFFFFF); // lighter translucency
  static const Color _accentCyan = Color(0xFF22D3EE);
  static const Color _accentPurple = Color(0xFF8B5CF6);
  static const Color _accentPink = Color(0xFFEC4899);

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accentPurple,
        brightness: Brightness.dark,
        primary: _accentPurple,
        secondary: _accentCyan,
        surface: const Color(0xFF0E1628),
        background: _primaryNavy,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: _primaryNavy,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: _surfaceGlassDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.all(12),
      ),
      bottomNavigationBarTheme: base.bottomNavigationBarTheme.copyWith(
        backgroundColor: const Color(0x33000000),
        elevation: 0,
        selectedItemColor: _accentCyan,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: _surfaceGlassDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: const Color(0x1AFFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0x33FFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0x33FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _accentCyan, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentCyan,
          foregroundColor: _primaryNavy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0x26FFFFFF),
        labelStyle: const TextStyle(color: Colors.white),
      ),
      dividerColor: const Color(0x1FFFFFFF),
      splashColor: const Color(0x26FFFFFF),
      highlightColor: const Color(0x1AFFFFFF),
      indicatorColor: _accentPink,
    );
  }

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accentCyan,
        brightness: Brightness.light,
        primary: _accentCyan,
        secondary: _accentPurple,
        surface: const Color(0xFFF7FAFC),
        background: const Color(0xFFF2F6FB),
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF2F6FB),
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: _surfaceGlassLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.all(12),
      ),
      bottomNavigationBarTheme: base.bottomNavigationBarTheme.copyWith(
        backgroundColor: const Color(0x14FFFFFF),
        elevation: 0,
        selectedItemColor: _accentPurple,
        unselectedItemColor: Colors.black54,
        type: BottomNavigationBarType.fixed,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: _surfaceGlassLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: const Color(0x21FFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0x1F000000)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0x1F000000)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _accentPurple, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0x14FFFFFF),
        labelStyle: const TextStyle(color: Colors.black87),
      ),
      dividerColor: const Color(0x14000000),
      splashColor: const Color(0x14000000),
      highlightColor: const Color(0x0F000000),
      indicatorColor: _accentPink,
    );
  }
}
