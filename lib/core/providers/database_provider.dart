import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../services/barcode_service.dart';
import '../services/backup_service.dart';
import '../services/platform_paths.dart';
import '../services/share_service.dart';

/// Opens the drift database on the correct platform path, running all
/// queries on a background isolate (UI never blocks on SQLite).
///
/// Keep-alive: one connection for the whole app lifetime.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(
    LazyDatabase(() async {
      final path = await PlatformPaths.databasePath();
      return NativeDatabase.createInBackground(File(path));
    }),
  );
  ref.onDispose(db.close);
  return db;
});

/// Stateful services that need the database.
final barcodeServiceProvider = Provider<BarcodeService>(
  (ref) => BarcodeService(ref.watch(databaseProvider)),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(databaseProvider)),
);

final shareServiceProvider = Provider<ShareService>(
  (ref) => ShareService(ref.watch(databaseProvider)),
);
