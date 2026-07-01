import 'package:sqflite/sqflite.dart';

import '../database_helper.dart';
import '../../models/item_price_history.dart';

class ItemPriceHistoryDao {
  ItemPriceHistoryDao._();
  static final ItemPriceHistoryDao instance = ItemPriceHistoryDao._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<int> insert(ItemPriceHistory history) async {
    final db = await _db;
    return db.insert('item_price_history', history.toDb());
  }

  Future<List<ItemPriceHistory>> forItemStore(int itemStoreId) async {
    final db = await _db;
    final rows = await db.query(
      'item_price_history',
      where: 'item_store_id = ?',
      whereArgs: [itemStoreId],
      orderBy: 'recorded_at DESC',
    );
    return rows.map(ItemPriceHistory.fromDb).toList();
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete('item_price_history', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteByItemStoreId(int itemStoreId) async {
    final db = await _db;
    return db.delete('item_price_history',
        where: 'item_store_id = ?', whereArgs: [itemStoreId]);
  }
}
