import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'shopping_list_dao.g.dart';

/// Aggregated stats for one list, computed entirely in SQL (the v1
/// dashboard ran one query per list and one per item — N+1).
///
/// Effective line price = preferred-store price, else the cheapest
/// recorded store price, else the legacy `items.price`. All amounts are
/// converted to SAR inside SQL (`CASE currency WHEN 'USD' THEN 3.75 …`)
/// so mixed-currency lists sum correctly; the UI divides by the display
/// currency rate.
class ListStats {
  final int listId;
  final int itemCount;
  final int checkedCount;
  final double totalSar;
  final double checkedTotalSar;

  const ListStats({
    required this.listId,
    required this.itemCount,
    required this.checkedCount,
    required this.totalSar,
    required this.checkedTotalSar,
  });
}

/// A list row joined with its [ListStats].
class ListWithStats {
  final ShoppingListRow list;
  final ListStats? stats;

  const ListWithStats({required this.list, this.stats});

  int get itemCount => stats?.itemCount ?? 0;
  int get checkedCount => stats?.checkedCount ?? 0;
  double get totalSar => stats?.totalSar ?? 0;
  double get checkedTotalSar => stats?.checkedTotalSar ?? 0;
}

/// Data access for `shopping_lists`.
@DriftAccessor(tables: [ShoppingLists, ListItems, Items, ItemStores])
class ShoppingListDao extends DatabaseAccessor<AppDatabase>
    with _$ShoppingListDaoMixin {
  ShoppingListDao(super.db);

  // Table shortcuts (the generated mixin no longer forwards these).
  $ShoppingListsTable get shoppingLists => attachedDatabase.shoppingLists;
  $ListItemsTable get listItems => attachedDatabase.listItems;
  $ItemsTable get items => attachedDatabase.items;
  $ItemStoresTable get itemStores => attachedDatabase.itemStores;

  /// Watch all lists with live aggregated stats — one streamed query.
  Stream<List<ListWithStats>> watchAllWithStats({int? limit}) {
    return customSelect(
      '''
      SELECT l.*,
             COALESCE(s.cnt, 0) AS cnt,
             COALESCE(s.done, 0) AS done,
             COALESCE(s.total_all, 0) AS total_all,
             COALESCE(s.total_checked, 0) AS total_checked
      FROM shopping_lists l
      LEFT JOIN (
        SELECT li.list_id,
               COUNT(*) AS cnt,
               SUM(CASE WHEN li.is_checked = 1 THEN 1 ELSE 0 END) AS done,
               SUM(li.quantity * COALESCE(ps.price, ls.min_price, i.price) *
                   CASE COALESCE(ps.currency, ls.currency, i.currency)
                     WHEN 'USD' THEN 3.75 ELSE 1.0 END) AS total_all,
               SUM(CASE WHEN li.is_checked = 1 THEN li.quantity *
                   COALESCE(ps.price, ls.min_price, i.price) *
                   CASE COALESCE(ps.currency, ls.currency, i.currency)
                     WHEN 'USD' THEN 3.75 ELSE 1.0 END ELSE 0 END) AS total_checked
        FROM list_items li
        INNER JOIN items i ON i.id = li.item_id
        LEFT JOIN (
          SELECT item_id, MIN(price) AS min_price, currency
          FROM item_store GROUP BY item_id
        ) ls ON ls.item_id = i.id
        LEFT JOIN item_store ps
          ON ps.item_id = i.id AND ps.store_id = li.preferred_store_id
        GROUP BY li.list_id
      ) s ON s.list_id = l.id
      ORDER BY l.updated_at DESC
      ${limit != null ? 'LIMIT $limit' : ''}
      ''',
      readsFrom: {shoppingLists, listItems, items, itemStores},
    ).watch().asyncMap(
      (rows) async => [
        for (final row in rows)
          ListWithStats(
            list: await shoppingLists.mapFromRow(row),
            stats: ListStats(
              listId: row.read<int>('id'),
              itemCount: row.read<int>('cnt'),
              checkedCount: row.read<int>('done'),
              totalSar: row.read<double>('total_all'),
              checkedTotalSar: row.read<double>('total_checked'),
            ),
          ),
      ],
    );
  }

  Future<ShoppingListRow?> findById(int id) =>
      (select(shoppingLists)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<ShoppingListRow?> watchById(int id) => (select(
    shoppingLists,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();

  Stream<int> watchCount() {
    final count = shoppingLists.id.count();
    final q = selectOnly(shoppingLists)..addColumns([count]);
    return q.watchSingle().map((r) => r.read(count) ?? 0);
  }

  Future<int> insertList(ShoppingListsCompanion companion) =>
      into(shoppingLists).insert(companion);

  Future<void> updateList(int id, ShoppingListsCompanion companion) =>
      (update(shoppingLists)..where((t) => t.id.equals(id))).write(companion);

  /// Touch `updated_at` after any list_items change.
  Future<void> touch(int id) =>
      (update(shoppingLists)..where((t) => t.id.equals(id))).write(
        ShoppingListsCompanion(
          updatedAt: Value(DateTime.now().toIso8601String()),
        ),
      );

  Future<int> deleteList(int id) =>
      (delete(shoppingLists)..where((t) => t.id.equals(id))).go();
}
