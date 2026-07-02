import 'package:intl/intl.dart';

/// Currencies supported by the app.
///
/// The Saudi Riyal is shown using the new Saudi Riyal Sign U+20C1 ⃁.
/// If the system font on the user's device doesn't have a glyph for this
/// codepoint (older Android / Linux desktops), the bundled NotoSansArabic
/// font (declared in pubspec.yaml) renders it instead.
enum AppCurrency { sar, usd }

extension CurrencyExtension on AppCurrency {
  /// The symbol used in TEXT contexts (CSV exports, JSON, backup filenames,
  /// accessibility labels).
  ///
  /// For SAR we use the ISO 4217 code "SAR" as a text symbol because the
  /// SAMA-unveiled Saudi Riyal symbol doesn't have an official Unicode
  /// codepoint yet — system fonts (Roboto, SF, DejaVu) don't have a glyph
  /// for any candidate codepoint, so users would see a "tofu" missing-glyph
  /// box. The actual Saudi Riyal SYMBOL (as an SVG icon) is rendered only
  /// in the UI via [CurrencyDisplay], which uses `assets/icons/sar_symbol.svg`.
  ///
  /// For USD we use "$" which every font supports.
  String get symbol {
    switch (this) {
      case AppCurrency.sar:
        return 'SAR';
      case AppCurrency.usd:
        return '\$';
    }
  }

  /// ISO 4217 currency code.
  String get code {
    switch (this) {
      case AppCurrency.sar:
        return 'SAR';
      case AppCurrency.usd:
        return 'USD';
    }
  }

  /// Approximate conversion rate to SAR (offline fallback).
  /// USD↔SAR is pegged at 3.75 by SAMA.
  double get toSarRate {
    switch (this) {
      case AppCurrency.sar:
        return 1.0;
      case AppCurrency.usd:
        return 3.75;
    }
  }

  /// Convert an amount in this currency to [target].
  double convertTo(double amount, AppCurrency target) {
    if (this == target) return amount;
    final inSar = amount * toSarRate;
    return inSar / target.toSarRate;
  }

  /// Format [amount] using a stable decimal layout (no locale-aware grouping)
  /// so the display is identical across AR and EN locales.
  String format(double amount) {
    final formatted = NumberFormat('#,##0.00').format(amount);
    return '$symbol $formatted';
  }

  /// Same as [format] but used when the amount is unknown — shows
  /// `<symbol> 0.00` instead of `—` so the user always sees the currency
  /// symbol and a numeric shape.
  String formatOrZero(double? amount) {
    return format(amount ?? 0);
  }

  /// Lookup constructor used by settings persistence.
  static AppCurrency fromCode(String code) {
    switch (code.toUpperCase()) {
      case 'USD':
        return AppCurrency.usd;
      case 'SAR':
      default:
        return AppCurrency.sar;
    }
  }
}
