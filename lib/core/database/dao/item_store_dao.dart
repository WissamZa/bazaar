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

    // Record price history if the price has changed
    final existing = await findByItemAndStore(is_.itemId, is_.storeId);
    if (existing != null && existing.price != is_.price) {
      await ItemPriceHistoryDao.instance.insert(
        ItemPriceHistory(
          itemStoreId: existing.id!,
          price: existing.price ?? 0.0,
          currency: existing.currency,
          recordedAt: DateTime.now(),
        ),
      );
    }

    final id = await db.insert(
      'item_store',
      is_.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // If it was a new record, we might want to record the initial price too
    if (existing == null) {
      // We need to get the inserted ID
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
