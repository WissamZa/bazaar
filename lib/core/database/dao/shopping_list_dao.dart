import 'package:sqflite/sqflite.dart';

import 'package:sqflite/sqflite.dart';

import '../../models/shopping_list.dart';
import '../database_helper.dart';

class ShoppingListDao {
  ShoppingListDao._();
  static final ShoppingListDao instance = ShoppingListDao._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<int> insert(ShoppingList list) async {
    final db = await _db;
    return db.insert('shopping_lists', list.toDb());
  }

  Future<int> upsertByName(ShoppingList list) async {
    final db = await _db;
    final rows = await db.query(
      'shopping_lists',
      where: 'name = ? AND owner = ?',
      whereArgs: [list.name, list.owner],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final existing = ShoppingList.fromDb(rows.first);
      return db.update(
        'shopping_lists',
        list.copyWith(id: existing.id, createdAt: existing.createdAt).toDb(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    }
    return insert(list);
  }

  Future<int> update(ShoppingList list) async {
    final db = await _db;
    return db.update(
      'shopping_lists',
      list.copyWith(updatedAt: DateTime.now()).toDb(),
      where: 'id = ?',
      whereArgs: [list.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete('shopping_lists', where: 'id = ?', whereArgs: [id]);
  }

  Future<ShoppingList?> findById(int id) async {
    final db = await _db;
    final rows =
        await db.query('shopping_lists', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return ShoppingList.fromDb(rows.first);
  }

  Future<List<ShoppingList>> all({String? owner}) async {
    final db = await _db;
    final List<Map<String, dynamic>> rows;
    if (owner != null) {
      rows = await db.query(
        'shopping_lists',
        where: 'owner = ?',
        whereArgs: [owner],
        orderBy: 'updated_at DESC',
      );
    } else {
      rows = await db.query('shopping_lists', orderBy: 'updated_at DESC');
    }
    return rows.map(ShoppingList.fromDb).toList();
  }
}
