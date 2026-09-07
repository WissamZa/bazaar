import 'package:bazaar/core/database/app_database.dart';
import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase createTestDatabase() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  ItemStoresCompanion price({
    required int itemId,
    required int storeId,
    double? amount,
    String currency = 'SAR',
  }) =>
      ItemStoresCompanion.insert(
        itemId: itemId,
        storeId: storeId,
        price: Value(amount),
        currency: Value(currency),
      );

  ItemsCompanion item(String name, {String? barcode}) =>
      ItemsCompanion.insert(
        nameEn: name,
        createdAt: DateTime(2026, 1, 1).toIso8601String(),
        updatedAt: DateTime(2026, 1, 1).toIso8601String(),
        barcode: Value(barcode),
      );

  ShoppingListsCompanion list(String name) => ShoppingListsCompanion.insert(
        name: name,
        owner: 'tester',
        createdAt: DateTime(2026, 1, 1).toIso8601String(),
        updatedAt: DateTime(2026, 1, 1).toIso8601String(),
      );

  group('schema', () {
    test('creates the legacy v6 table set', () async {
      final tables = await db
          .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
          .get();
      final names = tables.map((r) => r.data['name'] as String).toSet();
      expect(names, containsAll([
        'users',
        'stores',
        'categories',
        'items',
        'item_store', // legacy singular name, not item_stores
        'shopping_lists',
        'list_items',
        'item_price_history',
      ]));
    });

    test('schema version is 6 (drop-in with v1 installs)', () {
      expect(db.schemaVersion, 6);
    });
  });

  group('ItemDao.upsertByBarcode', () {
    test('inserts then updates by barcode without duplicating', () async {
      final first = await db.itemDao.upsertByBarcode(
          item('Cola', barcode: '1234567890123'));
      final second = await db.itemDao.upsertByBarcode(ItemsCompanion.insert(
        nameEn: 'Cola Zero',
        createdAt: DateTime(2026, 1, 2).toIso8601String(),
        updatedAt: DateTime(2026, 1, 2).toIso8601String(),
        barcode: const Value('1234567890123'),
        brand: const Value('Coca-Cola'),
      ));
      expect(second, first); // same row id — updated in place

      final all = await db.select(db.items).get();
      expect(all.length, 1);
      expect(all.single.nameEn, 'Cola Zero');
      expect(all.single.brand, 'Coca-Cola');
    });
  });

  group('ItemStoreDao.upsertWithHistory', () {
    test('REGRESSION: price edits preserve history (no cascade wipe)',
        () async {
      final itemId = await db.itemDao.insertItem(item('Rice'));
      final storeId = await db.storeDao.insertStore(StoresCompanion.insert(
        name: 'Panda',
        createdAt: DateTime(2026, 1, 1).toIso8601String(),
      ));

      await db.itemStoreDao.upsertWithHistory(price(
          itemId: itemId, storeId: storeId, amount: 10.0));
      // Verify the first history entry exists.
      expect(await _historyCount(db, itemId), 1);

      // BUGFIX check: v1 used REPLACE which deleted + re-inserted the
      // item_store row, cascading away its history. Update must keep the
      // row id and append a second entry.
      await db.itemStoreDao.upsertWithHistory(price(
          itemId: itemId, storeId: storeId, amount: 12.5));
      expect(await _historyCount(db, itemId), 2);

      final links = await db.itemStoreDao.forItem(itemId);
      expect(links.single.id, greaterThan(0));
      expect(links.single.price, 12.5);

      // Re-saving the SAME price must not append another entry.
      await db.itemStoreDao.upsertWithHistory(price(
          itemId: itemId, storeId: storeId, amount: 12.5));
      expect(await _historyCount(db, itemId), 2);
    });
  });

  group('ShoppingListDao.watchAllWithStats', () {
    test('aggregates counts, checked counts and totals in one query',
        () async {
      final listId = await db.shoppingListDao.insertList(list('Weekly'));
      final riceId = await db.itemDao.insertItem(item('Rice'));
      final colaId = await db.itemDao.insertItem(item('Cola'));
      final storeId = await db.storeDao.insertStore(StoresCompanion.insert(
        name: 'Panda',
        createdAt: DateTime(2026, 1, 1).toIso8601String(),
      ));
      await db.itemStoreDao
          .upsertWithHistory(price(itemId: riceId, storeId: storeId, amount: 10));
      await db.itemStoreDao
          .upsertWithHistory(price(itemId: colaId, storeId: storeId, amount: 5));

      await db.listItemDao.addItemToList(listId: listId, itemId: riceId);
      await db.listItemDao.addItemToList(listId: listId, itemId: colaId);
      // Bump rice quantity to 2 → 2 × 10 + 1 × 5 = 25 SAR.
      final riceRowId =
          (await db.listItemDao.watchForList(listId).first)
              .singleWhere((r) => r.item.id == riceId)
              .listItem
              .id!;
      await db.listItemDao.setQuantity(riceRowId, 2);
      final rows = await db.shoppingListDao.watchAllWithStats().first;
      expect(rows.single.itemCount, 2);
      expect(rows.single.checkedCount, 0);
      expect(rows.single.totalSar, closeTo(25, 0.001));

      // Check cola off: checked total becomes 5, all-total stays 25.
      final liRows = await db.listItemDao.watchForList(listId).first;
      final colaRow =
          liRows.singleWhere((r) => r.item.id == colaId);
      await db.listItemDao.setChecked(colaRow.listItem.id!, true);
      final after = await db.shoppingListDao.watchAllWithStats().first;
      expect(after.single.checkedCount, 1);
      expect(after.single.checkedTotalSar, closeTo(5, 0.001));
      expect(after.single.totalSar, closeTo(25, 0.001));
    });

    test('preferred store price wins over cheapest', () async {
      final listId = await db.shoppingListDao.insertList(list('Dual'));
      final itemId = await db.itemDao.insertItem(item('Milk'));
      final cheap = await db.storeDao.insertStore(StoresCompanion.insert(
        name: 'CheapMart',
        createdAt: DateTime(2026, 1, 1).toIso8601String(),
      ));
      const preferredStoreName = 'NearStore';
      final near = await db.storeDao.insertStore(StoresCompanion.insert(
        name: preferredStoreName,
        createdAt: DateTime(2026, 1, 1).toIso8601String(),
      ));
      await db.itemStoreDao
          .upsertWithHistory(price(itemId: itemId, storeId: cheap, amount: 4));
      await db.itemStoreDao
          .upsertWithHistory(price(itemId: itemId, storeId: near, amount: 6));

      await db.listItemDao.addItemToList(listId: listId, itemId: itemId);
      final rowId =
          (await db.listItemDao.watchForList(listId).first).single.listItem.id!;
      await db.listItemDao.setPreferredStore(rowId, near);

      // Row-level effective price = 6 (preferred), list total = 6.
      final liRows = await db.listItemDao.watchForList(listId).first;
      expect(liRows.single.effectivePrice, 6);
      expect(liRows.single.preferredStore?.name, preferredStoreName);
      final stats = await db.shoppingListDao.watchAllWithStats().first;
      expect(stats.single.totalSar, closeTo(6, 0.001));
    });
  });

  group('ItemDao.watchAll', () {
    test('effective price prefers cheapest store price', () async {
      final itemId = await db.itemDao.insertItem(item('Tea'));
      final s1 = await db.storeDao.insertStore(StoresCompanion.insert(
        name: 'A',
        createdAt: DateTime(2026, 1, 1).toIso8601String(),
      ));
      final s2 = await db.storeDao.insertStore(StoresCompanion.insert(
        name: 'B',
        createdAt: DateTime(2026, 1, 1).toIso8601String(),
      ));
      await db.itemStoreDao
          .upsertWithHistory(price(itemId: itemId, storeId: s1, amount: 9));
      await db.itemStoreDao
          .upsertWithHistory(price(itemId: itemId, storeId: s2, amount: 7.25));

      final rows = await db.itemDao.watchAll().first;
      expect(rows.single.displayPrice, closeTo(7.25, 0.001));
      expect(rows.single.effectiveCurrency, 'SAR');
    });

    test('search matches EN and AR names', () async {
      await db.itemDao.insertItem(ItemsCompanion.insert(
        nameEn: 'Rice',
        createdAt: DateTime(2026, 1, 1).toIso8601String(),
        updatedAt: DateTime(2026, 1, 1).toIso8601String(),
        nameAr: const Value('أرز'),
      ));
      await db.itemDao.insertItem(item('Sugar'));

      final ar = await db.itemDao.watchAll(search: 'أرز').first;
      expect(ar.length, 1);
      expect(ar.single.item.nameEn, 'Rice');
      final en = await db.itemDao.watchAll(search: 'sug').first;
      expect(en.single.item.nameEn, 'Sugar');
    });
  });
}

Future<int> _historyCount(AppDatabase db, int itemId) async {
  final rows = await db
      .customSelect(
          'SELECT COUNT(*) AS c FROM item_price_history h '
          'JOIN item_store s ON s.id = h.item_store_id WHERE s.item_id = ?',
          variables: [Variable(itemId)])
      .get();
  return rows.first.data['c'] as int;
}
