import 'package:intl/intl.dart';

/// Currencies supported by the app.
///
/// The Saudi Riyal is rendered in the UI as the official SAMA symbol via a
/// bundled SVG (see [PriceText]) because the glyph has no Unicode codepoint;
/// `symbol` is for text-only contexts (JSON exports, accessibility).
enum AppCurrency { sar, usd }

extension CurrencyExtension on AppCurrency {
  /// Symbol used in TEXT contexts (exports, JSON, labels).
  String get symbol => this == AppCurrency.usd ? r'$' : 'SAR';

  /// ISO 4217 currency code.
  String get code => this == AppCurrency.usd ? 'USD' : 'SAR';

  /// Conversion rate to SAR (USD↔SAR is pegged at 3.75 by SAMA).
  double get toSarRate => this == AppCurrency.usd ? 3.75 : 1.0;

  /// Convert an amount in this currency to [target].
  double convertTo(double amount, AppCurrency target) {
    if (this == target) return amount;
    return amount * toSarRate / target.toSarRate;
  }

  /// Stable decimal layout — identical digits across AR and EN locales.
  String format(double amount) =>
      '$symbol ${NumberFormat('#,##0.00').format(amount)}';

  String formatOrZero(double? amount) => format(amount ?? 0);
}

/// Constructor-like lookup used by settings persistence and JSON imports.
AppCurrency currencyFromCode(String code) =>
    code.toUpperCase() == 'USD' ? AppCurrency.usd : AppCurrency.sar;
