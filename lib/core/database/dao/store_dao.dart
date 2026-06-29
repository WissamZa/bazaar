import 'package:sqflite/sqflite.dart';

import '../../models/store.dart';
import '../database_helper.dart';

class StoreDao {
  StoreDao._();
  static final StoreDao instance = StoreDao._();

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
}
