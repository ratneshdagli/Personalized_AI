import 'package:flutter/material.dart';
import 'colors.dart';

// Centralized gradients matching Tailwind classes (from-*/via-*/to-*)
class AppGradients {
  static bool _isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  // Background base
  static LinearGradient background(BuildContext context) {
    final dark = _isDark(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        dark ? AppColors.darkBackground : AppColors.lightBackground,
        dark ? AppColors.darkMuted : AppColors.lightMuted,
        dark ? AppColors.darkBackground : AppColors.lightBackground,
      ],
    );
  }

  // Category/Type gradients
  static LinearGradient email(BuildContext context) {
    final dark = _isDark(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        dark ? AppColors.darkChart2Start : AppColors.lightChart2Start,
        dark ? AppColors.darkChart2End : AppColors.lightChart2End,
      ],
    );
  }

  static LinearGradient message(BuildContext context) {
    final dark = _isDark(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        dark ? AppColors.darkChart1Start : AppColors.lightChart1Start,
        dark ? AppColors.darkChart1End : AppColors.lightChart1End,
      ],
    );
  }

  static LinearGradient news(BuildContext context) {
    final dark = _isDark(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        dark ? AppColors.darkChart3Start : AppColors.lightChart3Start,
        dark ? AppColors.darkChart3End : AppColors.lightChart3End,
      ],
    );
  }



  static LinearGradient urgent(BuildContext context) {
    final dark = _isDark(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        dark ? AppColors.darkDestructive : AppColors.lightDestructive,
        dark ? AppColors.darkSecondary : AppColors.lightSecondary,
      ],
    );
  }

  // Onboarding slides
  static LinearGradient slide1(BuildContext context) {
    final dark = _isDark(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        dark ? AppColors.darkChart2Start : AppColors.lightChart2Start,
        dark ? AppColors.darkChart1Start : AppColors.lightChart1Start,
      ],
    );
  }

  static LinearGradient slide2(BuildContext context) {
    final dark = _isDark(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        dark ? AppColors.darkChart1Start : AppColors.lightChart1Start,
        dark ? AppColors.darkChart4Start : AppColors.lightChart4Start,
      ],
    );
  }

  static LinearGradient slide3(BuildContext context) {
    final dark = _isDark(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        dark ? AppColors.darkChart4Start : AppColors.lightChart4Start,
        dark ? AppColors.darkSecondary : AppColors.lightSecondary,
      ],
    );
  }

  // Time-of-day header (Calendar)
  static LinearGradient night(BuildContext context) {
    final dark = _isDark(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        dark ? AppColors.darkNightStart : AppColors.lightChart1End,
        dark ? AppColors.darkNightMid : AppColors.lightChart4End,
        dark ? AppColors.darkBackground : AppColors.lightBackground,
      ],
    );
  }

  static LinearGradient morning(BuildContext context) {
    final dark = _isDark(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        dark ? AppColors.darkMorningStart : AppColors.lightChart2End,
        dark ? AppColors.darkNightMid : AppColors.lightChart1End,
        dark ? AppColors.darkBackground : AppColors.lightBackground,
      ],
    );
  }

  static LinearGradient afternoon(BuildContext context) {
    final dark = _isDark(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        dark ? AppColors.darkAfternoonStart : AppColors.lightChart3Start,
        dark ? AppColors.darkChart4End : AppColors.lightChart4End,
        dark ? AppColors.darkBackground : AppColors.lightBackground,
      ],
    );
  }

  static LinearGradient evening(BuildContext context) {
    final dark = _isDark(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        dark ? AppColors.darkEveningStart : AppColors.lightChart1End,
        dark ? AppColors.darkChart4End : AppColors.lightChart4End,
        dark ? AppColors.darkBackground : AppColors.lightBackground,
      ],
    );
  }
}
