// QUALITY (Finding 19): Removed duplicate `import 'package:sqflite/sqflite.dart';`
// line and the unused `import 'item_dao.dart';` (no longer needed after the
// N+1 → JOIN refactor in forListWithItems).
import 'package:sqflite/sqflite.dart';

import '../../constants/currencies.dart';
import '../database_helper.dart';
import '../../models/list_item.dart';
import '../../models/item.dart';

class ListItemDao {
  ListItemDao._();
  static final ListItemDao instance = ListItemDao._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<int> insert(ListItem li) async {
    final db = await _db;
    return db.insert(
      'list_items',
      li.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(ListItem li) async {
    final db = await _db;
    return db.update(
      'list_items',
      li.toDb(),
      where: 'id = ?',
      whereArgs: [li.id],
    );
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
  ///
  /// PERFORMANCE (Finding 14): Previously this method issued one DB query
  /// per list_item (N+1). For a list with 50 items that was 51 round-trips
  /// and 50–150 ms of UI jank on low-end devices. Now done in a single
  /// SQL JOIN.
  Future<List<(Item, ListItem)>> forListWithItems(int listId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        li.id           AS li_id,
        li.list_id      AS li_list_id,
        li.item_id      AS li_item_id,
        li.quantity     AS li_quantity,
        li.is_checked   AS li_is_checked,
        li.preferred_store_id AS li_preferred_store_id,
        li.note         AS li_note,
        i.id            AS i_id,
        i.barcode       AS i_barcode,
        i.brand         AS i_brand,
        i.name_en       AS i_name_en,
        i.name_ar       AS i_name_ar,
        i.note          AS i_note,
        i.price         AS i_price,
        i.currency      AS i_currency,
        i.image_url     AS i_image_url,
        i.category_id   AS i_category_id,
        i.created_at    AS i_created_at,
        i.updated_at    AS i_updated_at
      FROM list_items li
      INNER JOIN items i ON li.item_id = i.id
      WHERE li.list_id = ?
      ORDER BY li.is_checked ASC, i.name_en ASC
    ''', [listId]);

    final result = <(Item, ListItem)>[];
    for (final row in rows) {
      final item = Item(
        id: row['i_id'] as int?,
        barcode: row['i_barcode'] as String?,
        brand: row['i_brand'] as String?,
        nameEn: row['i_name_en'] as String,
        nameAr: row['i_name_ar'] as String?,
        note: row['i_note'] as String?,
        price: (row['i_price'] as num?)?.toDouble(),
        currency: CurrencyExtension.fromCode(
          (row['i_currency'] as String?) ?? 'SAR',
        ),
        imageUrl: row['i_image_url'] as String?,
        categoryId: row['i_category_id'] as int?,
        createdAt: DateTime.parse(row['i_created_at'] as String),
        updatedAt: DateTime.parse(row['i_updated_at'] as String),
      );
      final li = ListItem(
        id: row['li_id'] as int?,
        listId: (row['li_list_id'] as int?) ?? listId,
        itemId: (row['li_item_id'] as int?) ?? 0,
        quantity: (row['li_quantity'] as int?) ?? 1,
        isChecked: ((row['li_is_checked'] as int?) ?? 0) == 1,
        preferredStoreId: row['li_preferred_store_id'] as int?,
        note: row['li_note'] as String?,
      );
      result.add((item, li));
    }
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
