import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'core/providers/currency_provider.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/scraping_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/user_provider.dart';
import 'core/services/scraper_service.dart';
import 'core/services/share_service.dart';

/// Method channel for receiving shared files from the Android side
/// (see MainActivity.kt). On iOS / desktop this channel simply never
/// receives any messages, which is fine.
const _kSharingChannel = MethodChannel('receive_sharing_intent');

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

  // Load persisted prefs before first frame so the UI doesn't flash defaults.
  await Future.wait([
    themeProv.load(),
    localeProv.load(),
    currencyProv.load(),
    userProv.load(),
    scrapingProv.load(),
  ]);

  // Inject the scraping config into the singleton scraper so it can use
  // the user's chosen strategy / provider / API keys.
  ScraperService.instance.config = scrapingProv;

  // QUALITY (Finding 6): Wire up receive_sharing_intent so that tapping a
  // .json file in another app (WhatsApp, Files, email) opens Bazaar and
  // imports the file. The MainActivity.kt side forwards the file path via
  // this method channel.
  _kSharingChannel.setMethodCallHandler((call) async {
    if (call.method == 'onShareMediaChanged') {
      final paths = (call.arguments as List?)?.cast<String>() ?? const [];
      if (paths.isNotEmpty) {
        await _importSharedFile(paths.first);
      }
    }
  });
  // Cold-start case: ask the Android side for any pending initial intent.
  if (!kIsWeb && Platform.isAndroid) {
    try {
      final result = await _kSharingChannel.invokeMethod<List>('getInitialMedia');
      if (result != null && result.isNotEmpty) {
        await _importSharedFile(result.first);
      }
    } catch (_) {
      // Channel not available (e.g. desktop) — ignore.
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProv),
        ChangeNotifierProvider.value(value: localeProv),
        ChangeNotifierProvider.value(value: currencyProv),
        ChangeNotifierProvider.value(value: userProv),
        ChangeNotifierProvider.value(value: scrapingProv),
      ],
      child: const BazaarApp(),
    ),
  );
}

/// Import a .json file shared from another app. Best-effort — failures
/// are silently swallowed here because the user has no UI context yet
/// (the app is still booting). A more sophisticated version would queue
/// the path and surface the result once the home screen is mounted.
Future<void> _importSharedFile(String path) async {
  try {
    // ShareService.importFromFile picks its own file via the file picker.
    // For the receive_sharing path we already have a path, so we call
    // the underlying logic directly. We'll add a `importFromPath` helper
    // to ShareService for this.
    await ShareService.instance.importFromPath(path);
  } catch (_) {
    // Swallow — there is no UI yet to show an error to.
  }
}
