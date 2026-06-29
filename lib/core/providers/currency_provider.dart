import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/currencies.dart';

/// Persists the active display currency in SharedPreferences.
class CurrencyProvider extends ChangeNotifier {
  static const _key = 'app_currency';

  AppCurrency _currency = AppCurrency.sar;

  AppCurrency get currency => _currency;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final code = sp.getString(_key);
    if (code != null) {
      _currency = CurrencyExtension.fromCode(code);
    }
    notifyListeners();
  }

  Future<void> set(AppCurrency currency) async {
    _currency = currency;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, currency.code);
    notifyListeners();
  }

  String format(double? amount) {
    if (amount == null) return '—';
    return _currency.format(amount);
  }

  /// Convert from any currency to the active one (e.g. when showing prices
  /// scraped in USD while the user prefers SAR).
  double convertToActive(double amount, AppCurrency from) =>
      from.convertTo(amount, _currency);
}
