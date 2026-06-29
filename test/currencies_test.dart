import 'package:flutter_test/flutter_test.dart';

import 'package:bazaar/core/constants/currencies.dart';

void main() {
  group('CurrencyExtension', () {
    test('codes round-trip', () {
      for (final c in AppCurrency.values) {
        expect(CurrencyExtension.fromCode(c.code), c);
      }
    });

    test('SAR symbol is U+FDFC', () {
      expect(AppCurrency.sar.symbol, '\uFDFC');
    });

    test('USD symbol is dollar sign', () {
      expect(AppCurrency.usd.symbol, '\$');
    });

    test('USD→SAR conversion uses the 3.75 peg', () {
      expect(AppCurrency.usd.convertTo(1.0, AppCurrency.sar), 3.75);
    });

    test('SAR→SAR is identity', () {
      expect(AppCurrency.sar.convertTo(100.0, AppCurrency.sar), 100.0);
    });

    test('format adds grouping separators', () {
      final s = AppCurrency.sar.format(1234.5);
      expect(s, contains('1,234.50'));
      expect(s, contains('\uFDFC'));
    });
  });
}
