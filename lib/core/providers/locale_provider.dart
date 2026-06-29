import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the active locale (en | ar) and persists it. Defaults to the device
/// locale on first launch.
class LocaleProvider extends ChangeNotifier {
  static const _key = 'app_locale';

  Locale? _locale;
  Locale? get locale => _locale;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final code = sp.getString(_key);
    if (code != null) {
      _locale = Locale(code);
    }
    notifyListeners();
  }

  Future<void> set(Locale locale) async {
    _locale = locale;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, locale.languageCode);
    notifyListeners();
  }

  Future<void> toggle() async {
    final next =
        (_locale?.languageCode ?? 'en') == 'en' ? const Locale('ar') : const Locale('en');
    await set(next);
  }

  bool get isRtl => _locale?.languageCode == 'ar';

  TextDirection get textDirection =>
      isRtl ? TextDirection.rtl : TextDirection.ltr;
}
