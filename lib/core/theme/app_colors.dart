import 'package:flutter/material.dart';

/// Raw color palette. Widgets should read colors from [ColorScheme] or
/// `BathWiseTheme`, never from here directly.
abstract final class AppColors {
  // Brand: indigo → teal.
  static const indigo = Color(0xFF4F46E5);
  static const indigoBright = Color(0xFF6366F1);
  static const violet = Color(0xFF7C3AED);
  static const teal = Color(0xFF0D9488);
  static const tealBright = Color(0xFF2DD4BF);

  // Accent for a second chart line (compare mode).
  static const amber = Color(0xFFD97706);
  static const amberBright = Color(0xFFFBBF24);

  // Gain / loss. Dark variants are lighter for contrast on navy.
  static const gainLight = Color(0xFF059669);
  static const lossLight = Color(0xFFDC2626);
  static const gainDark = Color(0xFF34D399);
  static const lossDark = Color(0xFFF87171);
  static const neutralLight = Color(0xFF64748B);
  static const neutralDark = Color(0xFF94A3B8);

  // Dark surfaces: deep navy.
  static const navy950 = Color(0xFF060A18);
  static const navy900 = Color(0xFF0B1126);
  static const navy800 = Color(0xFF131B38);
  static const navy700 = Color(0xFF1E2849);
  static const navy600 = Color(0xFF2B3660);

  // Light surfaces: clean and airy.
  static const mist50 = Color(0xFFF5F7FC);
  static const mist100 = Color(0xFFEDF0F8);
  static const mist200 = Color(0xFFDDE2F0);
  static const ink900 = Color(0xFF0F172A);
  static const ink600 = Color(0xFF475569);
}
