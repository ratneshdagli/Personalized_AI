import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.darkPrimary,
      onPrimary: AppColors.darkPrimaryForeground,
      secondary: AppColors.darkSecondary,
      onSecondary: AppColors.darkSecondaryForeground,
      tertiary: AppColors.darkAccent,
      onTertiary: AppColors.darkForeground,
      error: AppColors.darkDestructive,
      onError: AppColors.darkForeground,
      surface: AppColors.darkBackground,
      onSurface: AppColors.darkForeground,
      surfaceVariant: AppColors.darkCard,
      onSurfaceVariant: AppColors.darkCardForeground,
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkBorder,
      background: AppColors.darkBackground,
      onBackground: AppColors.darkForeground,
      primaryContainer: AppColors.darkPrimary,
      onPrimaryContainer: AppColors.darkPrimaryForeground,
      secondaryContainer: AppColors.darkSecondary,
      onSecondaryContainer: AppColors.darkSecondaryForeground,
      tertiaryContainer: AppColors.darkAccent,
      onTertiaryContainer: AppColors.darkForeground,
      surfaceTint: AppColors.darkPrimary,
      scrim: Colors.black,
      shadow: Colors.black,
      inverseSurface: AppColors.darkForeground,
      onInverseSurface: AppColors.darkBackground,
      inversePrimary: AppColors.darkPrimary,
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    textTheme: GoogleFonts.interTextTheme(
      const TextTheme(
        bodyLarge: TextStyle(color: AppColors.darkForeground),
        bodyMedium: TextStyle(color: AppColors.darkCardForeground),
        bodySmall: TextStyle(color: AppColors.darkCardForeground),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkCard.withOpacity(0.6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkRing),
      ),
      hintStyle: const TextStyle(color: AppColors.darkCardForeground),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.darkCard.withOpacity(0.6),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  static ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.lightPrimary,
      onPrimary: AppColors.lightPrimaryForeground,
      secondary: AppColors.lightSecondary,
      onSecondary: AppColors.lightSecondaryForeground,
      tertiary: AppColors.lightAccent,
      onTertiary: AppColors.lightForeground,
      error: AppColors.lightDestructive,
      onError: AppColors.lightForeground,
      surface: AppColors.lightBackground,
      onSurface: AppColors.lightForeground,
      surfaceVariant: AppColors.lightCard,
      onSurfaceVariant: AppColors.lightCardForeground,
      outline: AppColors.lightBorder,
      outlineVariant: AppColors.lightBorder,
      background: AppColors.lightBackground,
      onBackground: AppColors.lightForeground,
      primaryContainer: AppColors.lightPrimary,
      onPrimaryContainer: AppColors.lightPrimaryForeground,
      secondaryContainer: AppColors.lightSecondary,
      onSecondaryContainer: AppColors.lightSecondaryForeground,
      tertiaryContainer: AppColors.lightAccent,
      onTertiaryContainer: AppColors.lightForeground,
      surfaceTint: AppColors.lightPrimary,
      scrim: Colors.black,
      shadow: Colors.black,
      inverseSurface: AppColors.lightForeground,
      onInverseSurface: AppColors.lightBackground,
      inversePrimary: AppColors.lightPrimary,
    ),
    scaffoldBackgroundColor: AppColors.lightBackground,
    textTheme: GoogleFonts.interTextTheme(
      const TextTheme(
        bodyLarge: TextStyle(color: AppColors.lightForeground),
        bodyMedium: TextStyle(color: AppColors.lightSecondary),
        bodySmall: TextStyle(color: AppColors.lightSecondary),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightInput,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightRing),
      ),
      hintStyle: const TextStyle(color: AppColors.lightSecondary),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.lightCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
