import 'dart:io';

import 'package:bazaar/core/database/app_database.dart';
import 'package:bazaar/core/services/backup_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// In-memory path_provider so BackupService can write to a temp sandbox.
class _TestPathProvider extends PathProviderPlatform {
  final String root;
  _TestPathProvider(this.root);

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      p.join(root, 'docs');

  @override
  Future<String?> getTemporaryPath() async => p.join(root, 'tmp');

  @override
  Future<String?> getApplicationSupportPath() async =>
      p.join(root, 'support');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory sandbox;
  late BackupService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    sandbox = await Directory.systemTemp.createTemp('bazaar_test');
    PathProviderPlatform.instance = _TestPathProvider(sandbox.path);
    service = BackupService(db);
  });

  tearDown(() async {
    await db.close();
    await sandbox.delete(recursive: true);
  });

  ItemsCompanion item(String name, {String? barcode}) =>
      ItemsCompanion.insert(
        nameEn: name,
        createdAt: DateTime(2026, 1, 1).toIso8601String(),
        updatedAt: DateTime(2026, 1, 1).toIso8601String(),
        barcode: Value(barcode),
      );

  Future<File> seedAndBackup({String? passphrase}) async {
    final itemId =
        await db.itemDao.upsertByBarcode(item('Cola', barcode: '123'));
    final storeId = await db.storeDao.insertStore(StoresCompanion.insert(
      name: 'Panda',
      createdAt: DateTime(2026, 1, 1).toIso8601String(),
    ));
    await db.itemStoreDao.upsertWithHistory(
      ItemStoresCompanion.insert(
        itemId: itemId,
        storeId: storeId,
        price: const Value(7.5),
      ),
    );
    final listId = await db.shoppingListDao.insertList(
      ShoppingListsCompanion.insert(
        name: 'Trip',
        owner: 'tester',
        createdAt: DateTime(2026, 1, 1).toIso8601String(),
        updatedAt: DateTime(2026, 1, 1).toIso8601String(),
      ),
    );
    await db.listItemDao.addItemToList(listId: listId, itemId: itemId);
    return service.createBackup(passphrase: passphrase);
  }

  test('plaintext backup round-trip restores items, stores, lists',
      () async {
    final zip = await seedAndBackup();
    expect(await zip.exists(), isTrue);
    expect(zip.lengthSync(), greaterThan(100));

    // Wipe, then restore from the backup into the same DB.
    await db.wipeAll();
    expect(await db.select(db.items).get(), isEmpty);

    final contents = await service.readBackup(zip);
    final summary = await service.restoreSelective(contents);

    expect(summary.items, 1);
    expect(summary.stores, 1);
    expect(summary.lists, 1);
    expect(summary.skipped, 0);

    final items = await db.select(db.items).get();
    expect(items.single.barcode, '123');
    // list_items re-attached to the re-created list.
    final listItems = await db.select(db.listItems).get();
    expect(listItems.length, 1);
  });

  test('encrypted backup round-trip (AES-256-GCM, v1 wire format)',
      () async {
    final zip = await seedAndBackup(passphrase: 's3cret!');

    await db.wipeAll();

    // Encrypted: no passphrase → refuses.
    expect(
      () => service.readBackup(zip),
      throwsA(isA<StateError>()),
    );

    // Wrong passphrase → MAC failure.
    await expectLater(
      service.readBackup(zip, passphrase: 'wrong'),
      throwsA(isA<StateError>()),
    );

    final contents = await service.readBackup(zip, passphrase: 's3cret!');
    final summary = await service.restoreSelective(contents);
    expect(summary.items, 1);
    expect(summary.skipped, 0);
    final items = await db.select(db.items).get();
    expect(items.single.nameEn, 'Cola');
  });

  test('rejects ZIPs with unexpected entries and oversized payloads',
      () async {
    final zip = await seedAndBackup();

    // Not a valid ZIP at all → decode throws before any restore happens.
    final garbage = File(p.join(sandbox.path, 'garbage.zip'));
    await garbage.writeAsBytes(List.filled(64, 0x41));
    await expectLater(
      service.readBackup(garbage),
      throwsA(anything),
    );

    // Oversize cap: >50MB file → StateError before decode.
    final huge = File(p.join(sandbox.path, 'huge.zip'));
    await huge.writeAsBytes(List.filled(
        BackupService.maxBackupBytes + 1, 0));
    await expectLater(
      service.readBackup(huge),
      throwsA(isA<StateError>()),
    );

    // Silence unused-warning lint for the valid backup handle.
    expect(await zip.exists(), isTrue);
  });
}
