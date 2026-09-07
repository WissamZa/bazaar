import 'package:flutter/material.dart';

/// The Bazaar "souk" palette — warm charcoal surfaces, gold accents, and
/// cream text in dark mode; warm stone paper, gold and terracotta in light
/// mode. Tokens are extracted from the approved design renders in
/// `docs/screenshots/` (01_home.html light, 06_home_ar_dark.html dark).
///
/// Every color the UI uses must come from [AppColors] or the Material 3
/// [ColorScheme] built from it in `app_theme.dart` — no raw `Colors.*` in
/// widgets.
abstract final class AppColors {
  // ── Dark theme (primary look) ──────────────────────────────────────────
  static const Color darkBackground = Color(0xFF1A1815); // warm charcoal
  static const Color darkSurface = Color(0xFF25221D); // elevated card
  static const Color darkSurfaceHigh = Color(0xFF2E2A23); // inputs, sheets
  static const Color darkBorder = Color(0xFF3D3A30);
  static const Color darkGold = Color(0xFFD6B85D); // primary accent
  static const Color darkOnGold = Color(0xFF2A2110);
  static const Color darkText = Color(0xFFEEEEED); // warm off-white
  static const Color darkTextMuted = Color(0xFF908E87);
  static const Color darkSuccess = Color(0xFF7BC393);
  static const Color darkDanger = Color(0xFFC47B74); // terracotta
  static const Color darkOnDanger = Color(0xFF2A1512);
  static const Color darkInfo = Color(0xFF85B4CC);

  // ── Light theme ────────────────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF5F5F4); // warm stone
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceHigh = Color(0xFFEDEBE7);
  static const Color lightBorder = Color(0xFFD2CCBC);
  static const Color lightGold = Color(0xFF8A7227); // deep gold on paper
  static const Color lightOnGold = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF22211F);
  static const Color lightTextMuted = Color(0xFF8C8A83);
  static const Color lightSuccess = Color(0xFF459D62);
  static const Color lightDanger = Color(0xFF9C443C);
  static const Color lightOnDanger = Color(0xFFFFFFFF);
  static const Color lightInfo = Color(0xFF3D6B80);

  // ── Status accents (same hue families, tuned per brightness) ──────────
  static Color success(Brightness b) =>
      b == Brightness.dark ? darkSuccess : lightSuccess;
  static Color danger(Brightness b) =>
      b == Brightness.dark ? darkDanger : lightDanger;
  static Color info(Brightness b) =>
      b == Brightness.dark ? darkInfo : lightInfo;
}
