import 'package:flutter/material.dart';

/// Centralised colour palette for the Bazaar app.
///
/// The light palette is a warm cream + deep green + gold scheme that nods to
/// Saudi visual culture. The dark palette uses elevated surfaces with a
/// brighter green and warmer gold to keep contrast accessible.
class AppColors {
  AppColors._();

  // ───────────────────────── Light theme ─────────────────────────
  static const Color lightBackground = Color(0xFFF8F4EF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF1B5E20); // deep green
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightAccent = Color(0xFFD4A017); // gold
  static const Color lightText = Color(0xFF1C1B1F);
  static const Color lightTextMuted = Color(0xFF5B5B5B);
  static const Color lightBorder = Color(0xFFE3DDCF);

  // ───────────────────────── Dark theme ──────────────────────────
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkPrimary = Color(0xFF4CAF50); // lighter green
  static const Color darkOnPrimary = Color(0xFF00210A);
  static const Color darkAccent = Color(0xFFFFD54F); // warm gold
  static const Color darkText = Color(0xFFE6E1E5);
  static const Color darkTextMuted = Color(0xFFB0B0B0);
  static const Color darkBorder = Color(0xFF2C2C2C);
}
