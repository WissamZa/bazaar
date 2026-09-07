import 'package:flutter/material.dart';

/// Bundled type ramp for the app. Noto Sans + Noto Sans Arabic are declared
/// in pubspec.yaml and ship inside the APK, so text renders identically on
/// every device from the very first launch (no google_fonts runtime fetch,
/// no font flash, works fully offline).
///
/// Flutter's automatic font fallback resolves Arabic glyphs to the bundled
/// `NotoSansArabic` family, and monospace spans (barcodes, JSON dumps) use
/// `AppMono` (JetBrains Mono) directly via [mono].
abstract final class AppTypography {
  static const String _family = 'NotoSans';

  /// Apply to the MaterialApp theme. Sizes and weights follow a compact M3
  /// ramp tuned for dense list UIs.
  static TextTheme textTheme(TextTheme base) => base.copyWith(
    displaySmall: _w(base.displaySmall, 600),
    headlineMedium: _w(base.headlineMedium, 700),
    headlineSmall: _w(base.headlineSmall, 700),
    titleLarge: _w(base.titleLarge, 600, size: 20),
    titleMedium: _w(base.titleMedium, 600),
    titleSmall: _w(base.titleSmall, 600),
    bodyLarge: _w(base.bodyLarge, 400, size: 16),
    bodyMedium: _w(base.bodyMedium, 400),
    bodySmall: _w(base.bodySmall, 400, size: 12.5),
    labelLarge: _w(base.labelLarge, 600),
    labelMedium: _w(base.labelMedium, 500),
    labelSmall: _w(base.labelSmall, 500, size: 11),
  );

  static TextStyle? _w(TextStyle? s, double weight, {double? size}) =>
      s?.copyWith(
        fontFamily: _family,
        fontWeight: () {
          switch (weight) {
            case 700:
              return FontWeight.w700;
            case 600:
              return FontWeight.w600;
            case 500:
              return FontWeight.w500;
            default:
              return FontWeight.w400;
          }
        }(),
        fontSize: size ?? s.fontSize,
      );

  /// Monospace style for barcodes, JSON output, timings.
  static TextStyle mono(BuildContext context, {double? size}) => Theme.of(
    context,
  ).textTheme.bodySmall!.copyWith(fontFamily: 'AppMono', fontSize: size ?? 12);
}
