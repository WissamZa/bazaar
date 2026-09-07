import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves the SQLite database path per platform.
///
/// COMPATIBILITY: on Android the v1 app stored `bazaar.db` inside the
/// system databases dir (`/data/data/<pkg>/databases/`, sqflite's default).
/// We resolve that exact path via a platform-channel call to
/// `Context.getDatabasePath()` so v2 opens the same file with zero
/// migration or copying. On iOS the sqflite default was the Documents
/// directory; on desktop we use the app-support directory.
class PlatformPaths {
  static const _channel = MethodChannel('io.github.wissamza.bazaar/platform');

  static String? _cached;

  static Future<String> databasePath() async {
    if (_cached != null) return _cached!;
    final dbPath = await _resolve();
    _cached = dbPath;
    return dbPath;
  }

  static Future<String> _resolve() async {
    if (Platform.isAndroid) {
      try {
        final path = await _channel.invokeMethod<String>('getDatabasePath', {
          'name': 'bazaar.db',
        });
        if (path != null && path.isNotEmpty) return path;
      } on PlatformException {
        // fall through to the support-dir default
      }
    }
    if (Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      return p.join(dir.path, 'bazaar.db');
    }
    final support = await getApplicationSupportDirectory();
    return p.join(support.path, 'bazaar.db');
  }
}
