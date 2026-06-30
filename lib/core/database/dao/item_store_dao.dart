import 'package:sqflite/sqflite.dart';

import 'package:sqflite/sqflite.dart';

import '../database_helper.dart';
import '../../models/item_store.dart';

class ItemStoreDao {
  ItemStoreDao._();
  static final ItemStoreDao instance = ItemStoreDao._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<int> upsert(ItemStore is_) async {
    final db = await _db;
    return db.insert(
      'item_store',
      is_.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
