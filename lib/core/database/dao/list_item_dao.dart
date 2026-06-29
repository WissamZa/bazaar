import 'package:sqflite/sqflite.dart';

import '../database_helper.dart';
import '../../models/list_item.dart';
import '../../models/item.dart';
import 'item_dao.dart';

class ListItemDao {
  ListItemDao._();
  static final ListItemDao instance = ListItemDao._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<int> insert(ListItem li) async {
    final db = await _db;
    return db.insert('list_items', li.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(ListItem li) async {
    final db = await _db;
    return db.update('list_items', li.toDb(),
        where: 'id = ?', whereArgs: [li.id]);
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete('list_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ListItem>> forList(int listId) async {
    final db = await _db;
    final rows = await db.query(
      'list_items',
      where: 'list_id = ?',
      whereArgs: [listId],
      orderBy: 'id ASC',
    );
    return rows.map(ListItem.fromDb).toList();
  }

  /// Returns a future of (item, list_item) pairs for [listId], sorted by
  /// checked-last so the user always sees pending items at the top.
  Future<List<(Item, ListItem)>> forListWithItems(int listId) async {
    final items = await forList(listId);
    final result = <(Item, ListItem)>[];
    for (final li in items) {
      final item = await ItemDao.instance.findById(li.itemId);
      if (item != null) {
        result.add((item, li));
      }
    }
    result.sort((a, b) {
      if (a.$2.isChecked != b.$2.isChecked) {
        return a.$2.isChecked ? 1 : -1;
      }
      return a.$1.nameEn.compareTo(b.$1.nameEn);
    });
    return result;
  }

  Future<void> setChecked(int id, bool checked) async {
    final db = await _db;
    await db.update(
      'list_items',
      {'is_checked': checked ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setQuantity(int id, int qty) async {
    final db = await _db;
    await db.update(
      'list_items',
      {'quantity': qty < 1 ? 1 : qty},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
