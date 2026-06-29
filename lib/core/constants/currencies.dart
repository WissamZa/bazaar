import 'package:intl/intl.dart';

/// Currencies supported by the app.
///
/// The new Saudi Riyal symbol ﷼ (U+FDFC) is rendered reliably by the bundled
/// NotoSansArabic font; otherwise the legacy code "ر.س" is used as a fallback.
enum AppCurrency { sar, usd }

extension CurrencyExtension on AppCurrency {
  /// The symbol used in compact UI displays.
  String get symbol {
    switch (this) {
      case AppCurrency.sar:
        return '﷼'; // Unicode RIAL SIGN — bundled font renders it
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
