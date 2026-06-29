import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/currencies.dart';
import '../core/providers/currency_provider.dart';
import '../core/providers/locale_provider.dart';

/// Displays an amount with the active currency symbol.
///
/// If [overrideCurrency] is provided, the [amount] is interpreted as being
/// in that currency and converted to the user's active currency before
/// display. If null, [amount] is assumed to already be in the active
/// currency and is shown as-is.
class CurrencyDisplay extends StatelessWidget {
  final double? amount;
  final AppCurrency? overrideCurrency;
  final TextStyle? style;

  const CurrencyDisplay({
    super.key,
    required this.amount,
    this.overrideCurrency,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final currencyProv = context.watch<CurrencyProvider>();
    final locale = context.watch<LocaleProvider>();
    final displayCurrency = currencyProv.currency;

    if (amount == null) {
      return Text('—', style: style);
    }

    final displayAmount = overrideCurrency == null
        ? amount!
        : overrideCurrency!.convertTo(amount!, displayCurrency);

    final symbol = displayCurrency == AppCurrency.sar ? '﷼' : '\$';
    final formatted = displayAmount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+\.'),
          (m) => '${m[1]},',
        );

    // Both AR and EN use LTR numerals to keep grouping stable. The symbol
    // is on the left per common Saudi convention.
    final text = '$symbol $formatted';

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        text,
        style: style,
        locale: locale.locale,
      ),
    );
  }
}
