import 'package:flutter/material.dart';

// Semantic color tokens mapped from the React CSS variables (globals/index.css)
// The oklch variables are approximated to sRGB hex values for Flutter.
class AppColors {
  // Dark Theme (from .dark)
  static const Color darkBackground = Color(0xFF18181B); // near slate-900/950
  static const Color darkForeground = Color(0xFFFCFCFC);
  static const Color darkCard = Color(0xFF0F172A); // slate-900
  static const Color darkCardForeground = Color(0xFFE5E7EB); // slate-200
  static const Color darkMuted = Color(0xFF1F2937); // slate-800 equivalent
  static const Color darkPrimary = Color(0xFF3B82F6); // blue-500
  static const Color darkPrimaryForeground = Color(0xFF1F2937); // slate-800
  static const Color darkSecondary = Color(0xFFEC4899); // pink-500
  static const Color darkSecondaryForeground = Color(0xFF1F2937);
  static const Color darkAccent = Color(0xFF3B82F6); // blue-500
  static const Color darkDestructive = Color(0xFFEF4444); // red-500
  static const Color darkBorder = Color(0x1AFFFFFF); // white/10
  static const Color darkInput = Color(0x99334155); // slate-700 with opacity
  static const Color darkRing = Color(0x663B82F6); // blue-500/40

  // Dark charts (semantic equivalents of --chart-* in CSS)
  static const Color darkChart1Start = Color(0xFF3B82F6); // blue-500
  static const Color darkChart1End = Color(0xFF2563EB);   // blue-600/700
  static const Color darkChart2Start = Color(0xFF3B82F6); // blue-500
  static const Color darkChart2End = Color(0xFF2563EB);   // blue-600
  static const Color darkChart3Start = Color(0xFFF59E0B); // amber-500
  static const Color darkChart3End = Color(0xFFD97706);   // amber-600
  static const Color darkChart4Start = Color(0xFFEC4899); // pink-500
  static const Color darkChart4End = Color(0xFFE11D48);   // rose-600
  static const Color darkChart5Start = Color(0xFF22C55E); // green-500
  static const Color darkChart5End = Color(0xFF16A34A);   // green-600

  // Dark time-of-day gradients (semantic tokens)
  static const Color darkNightStart = Color(0xFF1E1B4B);   // indigo-950
  static const Color darkNightMid = Color(0xFF3B0764);     // purple-950
  static const Color darkMorningStart = Color(0xFF1E3A8A); // blue-900
  static const Color darkAfternoonStart = Color(0xFF7C2D12); // orange-900
  static const Color darkEveningStart = Color(0xFF581C87); // purple-900

  // Light Theme (from :root)
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightForeground = Color(0xFF111827); // slate-900
  static const Color lightCard = Color(0xFFF8FAFC); // slate-50/100
  static const Color lightCardForeground = Color(0xFF111827);
  static const Color lightMuted = Color(0xFFF1F5F9); // slate-100
  static const Color lightPrimary = Color(0xFF3B82F6); // blue-500
  static const Color lightPrimaryForeground = Color(0xFFFFFFFF);
  static const Color lightSecondary = Color(0xFF334155); // slate-700
  static const Color lightSecondaryForeground = Color(0xFFFFFFFF);
  static const Color lightAccent = Color(0xFF3B82F6);
  static const Color lightDestructive = Color(0xFFB91C1C); // red-700
  static const Color lightBorder = Color(0xFFE5E7EB); // slate-200
  static const Color lightInput = Color(0xFFF1F5F9); // slate-100
  static const Color lightRing = Color(0xFF3B82F6); // blue-500

  // Light charts
  static const Color lightChart1Start = Color(0xFF8B5CF6); // violet-500
  static const Color lightChart1End = Color(0xFF7C3AED);   // violet-600
  static const Color lightChart2Start = Color(0xFF3B82F6); // blue-500
  static const Color lightChart2End = Color(0xFF2563EB);   // blue-600
  static const Color lightChart3Start = Color(0xFFF59E0B); // amber-500
  static const Color lightChart3End = Color(0xFFD97706);   // amber-600
  static const Color lightChart4Start = Color(0xFFEC4899); // pink-500
  static const Color lightChart4End = Color(0xFFE11D48);   // rose-600
  static const Color lightChart5Start = Color(0xFF22C55E); // green-500
  static const Color lightChart5End = Color(0xFF16A34A);   // green-600

  // Legacy Tailwind scale (kept for components expecting these tokens)
  static const slate950 = Color(0xFF020617);
  static const slate900 = Color(0xFF0F172A);
  static const slate800 = Color(0xFF1F2937);
  static const slate700 = Color(0xFF334155);
  static const slate600 = Color(0xFF475569);
  static const slate500 = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate200 = Color(0xFFE5E7EB);
  static const purple500 = Color(0xFFA855F7);
}
