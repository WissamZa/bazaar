import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
///
/// When [amount] is null (price unknown), we show `<symbol> 0.00` instead
/// of `—` so the user always sees the currency symbol and a numeric shape.
///
/// The Saudi Riyal symbol is rendered as a bundled SVG icon
/// (`assets/icons/sar_symbol.svg`) rather than a Unicode codepoint because
/// the SAMA-unveiled symbol doesn't have an official Unicode assignment
/// yet — system fonts (Roboto, SF, DejaVu) don't have a glyph for any
/// candidate codepoint, so users would see a "tofu" missing-glyph box.
/// Using SVG guarantees identical rendering across all platforms.
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

    // Treat null as 0 — always show the symbol + numeric shape.
    final displayAmount = overrideCurrency == null
        ? (amount ?? 0)
        : overrideCurrency!.convertTo(amount ?? 0, displayCurrency);

    final String formatted = displayAmount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+\.)'),
          (m) => '${m[1]},',
        );

    // Use the inherited text style for the number; pick up its color so
    // the SAR icon matches the surrounding text in light/dark mode.
    final inheritedStyle = style ?? DefaultTextStyle.of(context).style;
    final iconColor = inheritedStyle.color ??
        Theme.of(context).colorScheme.onSurface;

    // Build the symbol widget depending on the currency.
    Widget symbolWidget;
    if (displayCurrency == AppCurrency.sar) {
      // SAR: use the bundled SVG icon. Sized to roughly match the height
      // of a capital letter in the current text style.
      final fontSize = inheritedStyle.fontSize ?? 14;
      symbolWidget = SvgPicture.asset(
        'assets/icons/sar_symbol.svg',
        width: fontSize * 0.85, // slightly smaller than a capital letter
        height: fontSize * 0.85,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      );
    } else {
      // USD: just a "$" character — every font has this glyph.
      symbolWidget = Text('\$', style: inheritedStyle);
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          symbolWidget,
          const SizedBox(width: 3),
          Text(
            formatted,
            style: inheritedStyle,
            locale: locale.locale,
          ),
        ],
      ),
    );
  }
}
