import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers/database_provider.dart';
import 'core/providers/settings_providers.dart';
import 'core/services/share_service.dart';

/// Bazaar — local-first shopping lists with barcode price tracking.
///
/// Boot order matters:
///   1. SharedPreferences loads before runApp (providers read it in build).
///   2. flutter_gemma initializes its model registry.
///   3. Providers load persisted settings (locale/theme/scraping config).
///   4. The share-intent listener is wired after the first frame so a cold
///      start with a shared JSON file routes into the importer.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sp = await SharedPreferences.getInstance();
  await FlutterGemma.initialize();

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
  );

  // Load persisted, non-secret settings before the first frame.
  await container.read(scrapingConfigProvider.notifier).load();

  // Best-effort on-device model autoload (fires only when enabled).
  container.read(onDeviceAutoloadProvider);

  runApp(
    UncontrolledProviderScope(container: container, child: const BazaarApp()),
  );

  // Wire the Android "open shared .json" intent flow (Finding 6 in v1).
  if (!kIsWeb) {
    _wireShareIntent(container);
  }
}

void _wireShareIntent(ProviderContainer container) {
  ReceiveSharingIntent.instance.getInitialMedia().then((media) {
    _importSharedFile(container, media);
  });
  ReceiveSharingIntent.instance.getMediaStream().listen((media) {
    _importSharedFile(container, media);
  });
}

Future<void> _importSharedFile(
  ProviderContainer container,
  List<SharedMediaFile> media,
) async {
  for (final m in media) {
    final path = m.path;
    if (path.isEmpty || !path.endsWith('.json')) continue;
    try {
      final summary = await container
          .read(shareServiceProvider)
          .importFromPath(path);
      debugPrint('Bazaar: shared JSON imported (${summary.count} items)');
    } catch (e) {
      debugPrint('Bazaar: shared JSON import failed: $e');
    }
  }
}
