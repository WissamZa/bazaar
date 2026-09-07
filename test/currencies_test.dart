import 'package:bazaar/core/constants/currencies.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('USD↔SAR conversion uses the SAMA peg (3.75)', () {
    expect(AppCurrency.usd.toSarRate, 3.75);
    expect(AppCurrency.sar.convertTo(37.5, AppCurrency.usd), closeTo(10, 0.001));
    expect(AppCurrency.usd.convertTo(10, AppCurrency.sar), closeTo(37.5, 0.001));
    expect(AppCurrency.sar.convertTo(5, AppCurrency.sar), 5);
  });

  test('formatting is locale-stable', () {
    expect(AppCurrency.sar.format(1234.5), 'SAR 1,234.50');
    expect(AppCurrency.usd.format(9.99), r'$ 9.99');
    expect(AppCurrency.sar.formatOrZero(null), 'SAR 0.00');
  });

  test('code lookup is tolerant of case and unknown codes', () {
    expect(currencyFromCode('usd'), AppCurrency.usd);
    expect(currencyFromCode('USD'), AppCurrency.usd);
    expect(currencyFromCode('SAR'), AppCurrency.sar);
    expect(currencyFromCode('EUR'), AppCurrency.sar); // default
  });
}
