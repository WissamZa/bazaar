import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the local username (no password, no auth — pure identity string).
/// Shown once on first launch via [UsernameScreen].
class UserProvider extends ChangeNotifier {
  static const _key = 'app_username';

  String? _username;
  String? get username => _username;

  bool get hasUser => (_username?.isNotEmpty ?? false);

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _username = sp.getString(_key);
    notifyListeners();
  }

  Future<void> set(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return;
    _username = trimmed;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, trimmed);
    notifyListeners();
  }

  Future<void> clear() async {
    _username = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key);
    notifyListeners();
  }
}
