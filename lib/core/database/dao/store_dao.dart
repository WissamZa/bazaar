import 'package:sqflite/sqflite.dart';

import '../../models/store.dart';
import '../database_helper.dart';

class StoreDao {
  StoreDao._();
  static final StoreDao instance = StoreDao._();

  /// Special name used for the default store. Items with no explicit store
  /// link are shown inside this store so they're never orphaned.
  static const defaultStoreName = 'Default';
  static const defaultStoreNameAr = 'افتراضي';

  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<int> insert(Store store) async {
    final db = await _db;
    return db.insert('stores', store.toDb());
  }

  Future<int> upsertByName(Store store) async {
    final db = await _db;
    final rows = await db.query(
      'stores',
      where: 'name = ?',
      whereArgs: [store.name],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final existing = Store.fromDb(rows.first);
      return db.update(
        'stores',
        store.copyWith(id: existing.id, createdAt: existing.createdAt).toDb(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    }
    return insert(store);
  }

  Future<int> update(Store store) async {
    final db = await _db;
    return db.update(
      'stores',
      store.toDb(),
      where: 'id = ?',
      whereArgs: [store.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete('stores', where: 'id = ?', whereArgs: [id]);
  }

  Future<Store?> findById(int id) async {
    final db = await _db;
    final rows = await db.query('stores', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Store.fromDb(rows.first);
  }

  Future<List<Store>> all() async {
    final db = await _db;
    final rows = await db.query('stores', orderBy: 'name ASC');
    return rows.map(Store.fromDb).toList();
  }

  // ───────────────────────── Default store ────────────────────────────

  /// Returns the id of the special "Default" store, creating it if it
  /// doesn't exist yet. Safe to call any number of times — the upsert is
  /// idempotent.
  Future<int> getOrCreateDefault() async {
    final db = await _db;
    final rows = await db.query(
      'stores',
      where: 'name = ?',
      whereArgs: [defaultStoreName],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id'] as int;
    return await db.insert('stores', {
      'name': defaultStoreName,
      'name_ar': defaultStoreNameAr,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// True if [storeId] is the default store. Used by the store detail
  /// screen to decide whether to also show items with no store link.
  Future<bool> isDefaultStore(int storeId) async {
    final db = await _db;
    final rows = await db.query(
      'stores',
      where: 'id = ? AND name = ?',
      whereArgs: [storeId, defaultStoreName],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Convenience: get the default store as a [Store] object.
  Future<Store> defaultStore() async {
    final id = await getOrCreateDefault();
    final s = await findById(id);
    // findById can only return null if the row was deleted between calls —
    // extremely unlikely, but handle it gracefully.
    return s ??
        Store(
          id: id,
          name: defaultStoreName,
          nameAr: defaultStoreNameAr,
          createdAt: DateTime.now(),
        );
  }
}
