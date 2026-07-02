import 'package:sqflite/sqflite.dart';

import 'package:sqflite/sqflite.dart';

import '../../models/item.dart';
import '../database_helper.dart';

class ItemDao {
  ItemDao._();
  static final ItemDao instance = ItemDao._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<int> insert(Item item) async {
    final db = await _db;
    return db.insert(
      'items',
      item.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> upsertByBarcode(Item item) async {
    final db = await _db;
    if (item.barcode != null && item.barcode!.isNotEmpty) {
      final existing = await findByBarcode(item.barcode!);
      if (existing != null) {
        return db.update(
          'items',
          {
            ...item.toDb(),
            'id': existing.id,
            'created_at': existing.createdAt.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [existing.id],
        );
      }
    }
    return insert(item);
  }

  Future<int> update(Item item) async {
    final db = await _db;
    return db.update(
      'items',
      item.copyWith(updatedAt: DateTime.now()).toDb(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  Future<Item?> findById(int id) async {
    final db = await _db;
    final rows = await db.query('items', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Item.fromDb(rows.first);
  }

  Future<Item?> findByBarcode(String barcode) async {
    final db = await _db;
    final rows = await db.query(
      'items',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Item.fromDb(rows.first);
  }

  Future<List<Item>> all() async {
    final db = await _db;
    final rows = await db.query('items', orderBy: 'updated_at DESC');
    return rows.map(Item.fromDb).toList();
  }

  Future<List<Item>> search(String query) async {
    final db = await _db;
    final q = '%$query%';
    final rows = await db.query(
      'items',
      where:
          'name_en LIKE ? OR name_ar LIKE ? OR barcode LIKE ? OR brand LIKE ?',
      whereArgs: [q, q, q, q],
      orderBy: 'updated_at DESC',
    );
    return rows.map(Item.fromDb).toList();
  }

  /// Returns the "effective" price for an item — the price the user wants
  /// shown in lists when there's no room to show all per-store prices.
  ///
  /// Resolution order:
  ///   1. If `item.preferredStoreId` is set AND a corresponding item_store
  ///      row exists with a non-null price → return that price.
  ///   2. Otherwise, return the LOWEST non-null price across all stores
  ///      that carry this item.
  ///   3. If no store has a price → return null (the UI shows `⃁ 0.00`).
  Future<double?> effectivePriceFor(Item item) async {
    final db = await _db;
    if (item.id == null) return item.price;

    // 1. Preferred store's price.
    if (item.preferredStoreId != null) {
      final rows = await db.query(
        'item_store',
        where: 'item_id = ? AND store_id = ? AND price IS NOT NULL',
        whereArgs: [item.id, item.preferredStoreId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final p = (rows.first['price'] as num?)?.toDouble();
        if (p != null) return p;
      }
    }

    // 2. Lowest non-null price across all stores.
    final rows = await db.query(
      'item_store',
      columns: ['MIN(price) AS min_price'],
      where: 'item_id = ? AND price IS NOT NULL',
      whereArgs: [item.id],
    );
    if (rows.isNotEmpty) {
      final minPrice = (rows.first['min_price'] as num?)?.toDouble();
      if (minPrice != null) return minPrice;
    }

    // 3. Fall back to the legacy item.price field (set by older app versions
    //    before per-store prices were introduced).
    return item.price;
  }
}
