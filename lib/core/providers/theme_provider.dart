import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists theme choice ('light' | 'dark') in SharedPreferences and exposes
/// a [themeMode] to the MaterialApp.
class ThemeProvider extends ChangeNotifier {
  static const _key = 'app_theme';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final value = sp.getString(_key);
    switch (value) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> set(ThemeMode mode) async {
    _themeMode = mode;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _key,
      mode == ThemeMode.dark
          ? 'dark'
          : mode == ThemeMode.light
              ? 'light'
              : 'system',
    );
    notifyListeners();
  }

  Future<void> toggle() async {
    await set(_themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}
