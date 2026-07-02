import 'package:sqflite/sqflite.dart';

import '../database_helper.dart';
import '../../models/item_store.dart';
import '../../models/item_price_history.dart';
import 'item_price_history_dao.dart';

class ItemStoreDao {
  ItemStoreDao._();
  static final ItemStoreDao instance = ItemStoreDao._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<int> upsert(ItemStore is_) async {
    final db = await _db;

    // Look up the existing record (if any) so we can:
    //   1. Preserve the existing `id` (so REPLACE doesn't allocate a new one
    //      and orphan the price-history FK).
    //   2. Compare prices and record a price-history entry when changed.
    final existing = await findByItemAndStore(is_.itemId, is_.storeId);

    // Preserve the existing ID so REPLACE updates in place rather than
    // delete+insert (which would orphan the price-history FK).
    final toWrite = existing != null ? is_.copyWith(id: existing.id) : is_;

    final id = await db.insert(
      'item_store',
      toWrite.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Record price history entries:
    //   - If new record → record the initial price.
    //   - If existing record AND price changed → record the OLD price
    //     (as a "before" snapshot) AND the NEW price (as the "after").
    //     The history table is append-only, so each entry is a point-in-time
    //     observation. The most recent entry always reflects the current
    //     price.
    if (existing == null) {
      // Brand new — record the initial price.
      final rows = await db.query(
        'item_store',
        where: 'item_id = ? AND store_id = ?',
        whereArgs: [is_.itemId, is_.storeId],
      );
      final insertedId = rows.first['id'] as int;
      await ItemPriceHistoryDao.instance.insert(
        ItemPriceHistory(
          itemStoreId: insertedId,
          price: is_.price ?? 0.0,
          currency: is_.currency,
          recordedAt: DateTime.now(),
        ),
      );
    } else if (existing.price != is_.price) {
      // Price changed — record BOTH the old price (as the "before") and
      // the new price (as the "after"). Both reference the SAME item_store
      // row (existing.id), so the history stays attached even though
      // REPLACE may have rewritten the row.
      await ItemPriceHistoryDao.instance.insert(
        ItemPriceHistory(
          itemStoreId: existing.id!,
          price: existing.price ?? 0.0,
          currency: existing.currency,
          recordedAt: DateTime.now().subtract(const Duration(milliseconds: 1)),
        ),
      );
      await ItemPriceHistoryDao.instance.insert(
        ItemPriceHistory(
          itemStoreId: existing.id!,
          price: is_.price ?? 0.0,
          currency: is_.currency,
          recordedAt: DateTime.now(),
        ),
      );
    }

    return id;
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete('item_store', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteByItemId(int itemId) async {
    final db = await _db;
    return db.delete('item_store', where: 'item_id = ?', whereArgs: [itemId]);
  }

  Future<List<ItemStore>> forItem(int itemId) async {
    final db = await _db;
    final rows = await db.query(
      'item_store',
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
    return rows.map(ItemStore.fromDb).toList();
  }

  Future<List<ItemStore>> forStore(int storeId) async {
    final db = await _db;
    final rows = await db.query(
      'item_store',
      where: 'store_id = ?',
      whereArgs: [storeId],
    );
    return rows.map(ItemStore.fromDb).toList();
  }

  Future<ItemStore?> findByItemAndStore(int itemId, int storeId) async {
    final db = await _db;
    final rows = await db.query(
      'item_store',
      where: 'item_id = ? AND store_id = ?',
      whereArgs: [itemId, storeId],
    );
    return rows.isEmpty ? null : ItemStore.fromDb(rows.first);
  }
}
