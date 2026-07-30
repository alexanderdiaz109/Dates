import 'package:flutter/material.dart';

const Color brandPrimary  = Color(0xFFE74C3C);
const Color brandSeedColor = Color(0xFF1A252F);

class AppTheme {
  // ── Clásico (Blanco) ──────────────────────────────────
  static final ThemeData classic = ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      brightness: Brightness.light,
      seedColor: brandSeedColor,
      primary: brandPrimary,
      surface: const Color(0xFFF8F9FA),
      onSurface: const Color(0xFF2C3E50),
    ),
    scaffoldBackgroundColor: const Color(0xFFF2F4F5),
    cardColor: Colors.white,
    useMaterial3: true,
    fontFamily: 'Roboto',
  );

  // ── Oscuro (Gris elegante, estilo Discord/Twitter) ────
  static final ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: brandSeedColor,
      primary: brandPrimary,
      surface: const Color(0xFF1E1E2E),
      onSurface: const Color(0xFFE0E0E0),
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1E1E2E),
    useMaterial3: true,
    fontFamily: 'Roboto',
  );

  // ── OLED (Negro puro) ─────────────────────────────────
  static final ThemeData oled = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: brandSeedColor,
      primary: brandPrimary,
      surface: const Color(0xFF0D0D0D),
      onSurface: const Color(0xFFEEEEEE),
    ),
    scaffoldBackgroundColor: Colors.black,
    cardColor: const Color(0xFF0D0D0D),
    useMaterial3: true,
    fontFamily: 'Roboto',
  );

  static ThemeData getTheme(String? mode) {
    switch (mode) {
      case 'dark': return dark;
      case 'oled': return oled;
      default:     return classic;
    }
  }
}
