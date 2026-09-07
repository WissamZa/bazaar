import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../constants/currencies.dart';

/// The one way to render a money amount anywhere in the app.
///
/// SAR is shown as the official Saudi Riyal symbol (bundled SVG, tinted to
/// the text color — the SAMA glyph has no Unicode codepoint so system fonts
/// would render tofu). USD renders as "$". Amounts use a stable decimal
/// layout so AR and EN locales show identical digits.
class PriceText extends StatelessWidget {
  final double? amount;
  final AppCurrency currency;
  final TextStyle? style;
  final bool showZero;

  const PriceText(
    this.amount, {
    super.key,
    this.currency = AppCurrency.sar,
    this.style,
    this.showZero = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle =
        style ?? Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final color =
        effectiveStyle.color ??
        Theme.of(context).textTheme.bodyMedium?.color ??
        Colors.white;

    if (amount == null && !showZero) {
      return Text('—', style: effectiveStyle);
    }

    final value = amount ?? 0.0;
    final formatted = NumberFormat('#,##0.00').format(value);

    if (currency == AppCurrency.sar) {
      return Semantics(
        label: 'SAR $formatted',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textBaseline: TextBaseline.alphabetic,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          children: [
            Flexible(
              child: Text(
                formatted,
                style: effectiveStyle,
                overflow: TextOverflow.fade,
              ),
            ),
            const SizedBox(width: 3),
            _SarSymbol(
              height: _symbolHeight(effectiveStyle.fontSize),
              color: color,
            ),
          ],
        ),
      );
    }

    return Text('\$$formatted', style: effectiveStyle);
  }

  static double _symbolHeight(double? fontSize) => (fontSize ?? 14) * 0.9;
}

class _SarSymbol extends StatelessWidget {
  final double height;
  final Color color;

  const _SarSymbol({required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/sar_symbol.svg',
      height: height,
      width: height * 1.4,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
