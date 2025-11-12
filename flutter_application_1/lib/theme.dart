import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RNColorTokens {
  // Light
  static const Color primaryLight = Color(0xFF6366F1);
  static const Color accentLight = Color(0xFF10B981);
  static const Color bgLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceElevatedLight = Color(0xFFF8FAFC);
  static const Color textLight = Color(0xFF1F2937);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color borderLight = Color(0xFFE5E7EB);

  // Dark
  static const Color primaryDark = Color(0xFF8B5CF6);
  static const Color accentDark = Color(0xFF34D399);
  static const Color bgDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceElevatedDark = Color(0xFF334155);
  static const Color textDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFFCBD5E1);
  static const Color borderDark = Color(0xFF334155);
}

class RNTheme {
  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: RNColorTokens.primaryLight,
        brightness: Brightness.light,
        primary: RNColorTokens.primaryLight,
        secondary: RNColorTokens.accentLight,
        surface: RNColorTokens.surfaceElevatedLight,
        background: RNColorTokens.bgLight,
      ),
      scaffoldBackgroundColor: RNColorTokens.bgLight,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: RNColorTokens.textLight,
        displayColor: RNColorTokens.textLight,
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
      cardTheme: base.cardTheme.copyWith(
        color: RNColorTokens.surfaceElevatedLight,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(12),
      ),
      bottomNavigationBarTheme: base.bottomNavigationBarTheme.copyWith(
        backgroundColor: const Color(0x14FFFFFF),
        elevation: 0,
        selectedItemColor: RNColorTokens.primaryLight,
        unselectedItemColor: Colors.black54,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: const Color(0x21FFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x1F000000)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x1F000000)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: RNColorTokens.primaryLight, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RNColorTokens.primaryLight,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      dividerColor: RNColorTokens.borderLight.withOpacity(0.5),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: RNColorTokens.primaryDark,
        brightness: Brightness.dark,
        primary: RNColorTokens.primaryDark,
        secondary: RNColorTokens.accentDark,
        surface: RNColorTokens.surfaceDark,
        background: RNColorTokens.bgDark,
      ),
      scaffoldBackgroundColor: RNColorTokens.bgDark,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: RNColorTokens.textDark,
        displayColor: RNColorTokens.textDark,
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
      cardTheme: base.cardTheme.copyWith(
        color: RNColorTokens.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(12),
      ),
      bottomNavigationBarTheme: base.bottomNavigationBarTheme.copyWith(
        backgroundColor: const Color(0x33000000),
        elevation: 0,
        selectedItemColor: RNColorTokens.accentDark,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: const Color(0x1AFFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x33FFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x33FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: RNColorTokens.accentDark, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RNColorTokens.accentDark,
          foregroundColor: RNColorTokens.bgDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      dividerColor: RNColorTokens.borderDark.withOpacity(0.5),
    );
  }
}


