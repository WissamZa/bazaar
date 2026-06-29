import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'core/providers/currency_provider.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/user_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // sqflite only ships a native factory for Android/iOS. On desktop (Linux,
  // Windows, macOS) we must install the FFI factory before any DB call.
  if (!kIsWeb &&
      (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final themeProv = ThemeProvider();
  final localeProv = LocaleProvider();
  final currencyProv = CurrencyProvider();
  final userProv = UserProvider();

  // Load persisted prefs before first frame so the UI doesn't flash defaults.
  await Future.wait([
    themeProv.load(),
    localeProv.load(),
    currencyProv.load(),
    userProv.load(),
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProv),
        ChangeNotifierProvider.value(value: localeProv),
        ChangeNotifierProvider.value(value: currencyProv),
        ChangeNotifierProvider.value(value: userProv),
      ],
      child: const BazaarApp(),
    ),
  );
}
