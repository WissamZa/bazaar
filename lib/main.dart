import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'core/database/dao/store_dao.dart';
import 'core/providers/currency_provider.dart';
import 'core/providers/data_change_notifier.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/scraping_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/user_provider.dart';
import 'core/services/scraper_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // sqflite only ships a native factory for Android/iOS. On desktop (Linux,
  // Windows, macOS) we must install the FFI factory before any DB call.
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final themeProv = ThemeProvider();
  final localeProv = LocaleProvider();
  final currencyProv = CurrencyProvider();
  final userProv = UserProvider();
  final scrapingProv = ScrapingProvider();
  final dataChangeProv = DataChangeNotifier.instance;

  // Load persisted prefs before first frame so the UI doesn't flash defaults.
  await Future.wait([
    themeProv.load(),
    localeProv.load(),
    currencyProv.load(),
    userProv.load(),
    scrapingProv.load(),
  ]);

  // Ensure the Default store exists from the very first launch. This way:
  //   - The Stores screen never shows "No stores yet" on a fresh install.
  //   - Items saved without a selected store always have somewhere to live.
  //   - The user can always rename / delete it; it'll be re-created on the
  //     next item save if needed.
  try {
    await StoreDao.instance.getOrCreateDefault();
  } catch (e) {
    // Don't crash the app if the DB isn't ready yet — the Default store
    // will be created on-demand by ensureDefaultStoreLink later.
    debugPrint('Could not pre-create Default store: $e');
  }

  // Inject the scraping config into the singleton scraper so it can use
  // the user's chosen strategy / provider / API keys.
  ScraperService.instance.config = scrapingProv;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProv),
        ChangeNotifierProvider.value(value: localeProv),
        ChangeNotifierProvider.value(value: currencyProv),
        ChangeNotifierProvider.value(value: userProv),
        ChangeNotifierProvider.value(value: scrapingProv),
        ChangeNotifierProvider.value(value: dataChangeProv),
      ],
      child: const BazaarApp(),
    ),
  );
}
