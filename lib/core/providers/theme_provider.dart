import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists theme choice ('light' | 'dark' | 'system') in SharedPreferences
/// and exposes a [themeMode] to the MaterialApp.
///
/// The [isDark] getter resolves the EFFECTIVE dark state — it returns true
/// when the user has explicitly chosen dark, OR when the user chose "system"
/// AND the host platform is in dark mode. This is what every UI widget that
/// wants to know "is the app currently showing dark?" should call.
class ThemeProvider extends ChangeNotifier {
  static const _key = 'app_theme';

  ThemeMode _themeMode = ThemeMode.system;
  Brightness _platformBrightness = Brightness.light;

  ThemeMode get themeMode => _themeMode;

  /// The host platform's current brightness. Updated whenever the app
  /// detects a platform brightness change (see [updatePlatformBrightness]).
  /// Used to resolve [isDark] when [themeMode] is `system`.
  Brightness get platformBrightness => _platformBrightness;

  /// EFFECTIVE dark state — what UI widgets should consult.
  ///
  /// - `ThemeMode.dark` → true
  /// - `ThemeMode.light` → false
  /// - `ThemeMode.system` → follows [platformBrightness]
  bool get isDark {
    switch (_themeMode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return _platformBrightness == Brightness.dark;
    }
  }

  /// Call this from the root widget whenever the platform brightness
  /// changes (e.g. via MediaQuery.platformBrightness). Triggers a
  /// notifyListeners so widgets depending on [isDark] rebuild.
  void updatePlatformBrightness(Brightness brightness) {
    if (brightness == _platformBrightness) return;
    _platformBrightness = brightness;
    // Only notify if we're in system mode — otherwise the effective dark
    // state didn't actually change.
    if (_themeMode == ThemeMode.system) {
      notifyListeners();
    }
  }

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

  /// Toggle between dark and light based on the EFFECTIVE current state.
  ///
  /// If the app is currently showing dark (whether because the user picked
  /// dark OR because the system is dark and the user is on "system"),
  /// toggle to light. Otherwise toggle to dark. This makes the first tap
  /// always do something visible.
  Future<void> toggle() async {
    await set(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}
