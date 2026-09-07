import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'item_dao.g.dart';

/// Sort options for the items catalog.
enum ItemSort { newest, name, priceHigh, priceLow }

enum ItemGroup { none, brand, category }

/// One item row joined with its effective price.
///
/// Effective price = cheapest recorded store price, falling back to the
/// legacy `items.price`. Computed in SQL so the whole catalog stays a
/// single streamed query (the v1 screen did per-row queries instead).
class ItemWithEffectivePrice {
  final ItemRow item;
  final double? effectivePrice;
  final String effectiveCurrency;

  ItemWithEffectivePrice({
    required this.item,
    this.effectivePrice,
    required this.effectiveCurrency,
  });

  double? get displayPrice => effectivePrice ?? item.price;
}

/// Data access for the `items` table — reactive streams + typed queries.
/// Replaces the v1 hand-written row mappers and imperative reload pattern.
@DriftAccessor(tables: [Items, ItemStores, Stores, ItemPriceHistory])
class ItemDao extends DatabaseAccessor<AppDatabase> with _$ItemDaoMixin {
  ItemDao(super.db);

  // Table shortcuts (the generated mixin no longer forwards these).
  $ItemsTable get items => attachedDatabase.items;
  $ItemStoresTable get itemStores => attachedDatabase.itemStores;
  $StoresTable get stores => attachedDatabase.stores;
  $ItemPriceHistoryTable get itemPriceHistory =>
      attachedDatabase.itemPriceHistory;

  /// Watch the full catalog with effective prices, sorted by [sort].
  Stream<List<ItemWithEffectivePrice>> watchAll({
    ItemSort sort = ItemSort.newest,
    String search = '',
  }) {
    final q = search.trim();
    final where = q.isEmpty
        ? ''
        : "WHERE instr(lower(i.name_en), ?) > 0 "
              "OR instr(lower(coalesce(i.name_ar, '')), ?) > 0 "
              "OR instr(lower(coalesce(i.brand, '')), ?) > 0 "
              "OR instr(coalesce(i.barcode, ''), ?) > 0 ";
    final vars = q.isEmpty
        ? <Variable>[]
        : [
            Variable(q.toLowerCase()),
            Variable(q.toLowerCase()),
            Variable(q.toLowerCase()),
            Variable(q),
          ];

    final orderBy = switch (sort) {
      ItemSort.newest => 'ORDER BY i.created_at DESC',
      ItemSort.name => 'ORDER BY lower(i.name_en) COLLATE NOCASE',
      ItemSort.priceHigh => 'ORDER BY eff DESC',
      ItemSort.priceLow => 'ORDER BY eff ASC',
    };

    return customSelect(
      '''
      SELECT i.*, COALESCE(ls.min_price, i.price) AS eff,
             COALESCE(ls.currency, i.currency) AS eff_currency
      FROM items i
      LEFT JOIN (
        SELECT item_id, MIN(price) AS min_price, currency
        FROM item_store GROUP BY item_id
      ) ls ON ls.item_id = i.id
      $where
      $orderBy
      ''',
      variables: vars,
      readsFrom: {items, itemStores},
    ).watch().asyncMap(
      (rows) async => [
        for (final row in rows)
          ItemWithEffectivePrice(
            item: await items.mapFromRow(row),
            effectivePrice: row.readNullable<double>('eff'),
            effectiveCurrency: row.read<String>('eff_currency'),
          ),
      ],
    );
  }

  Future<List<ItemRow>> all() =>
      (select(items)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  Future<ItemRow?> findById(int id) =>
      (select(items)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<ItemRow?> findByBarcode(String barcode) => (select(
    items,
  )..where((t) => t.barcode.equals(barcode))).getSingleOrNull();

  Stream<ItemRow?> watchById(int id) =>
      (select(items)..where((t) => t.id.equals(id))).watchSingleOrNull();

  /// Watch every per-store price row for one item, joined with store data —
  /// one query instead of the v1 per-relation lookups.
  Stream<List<StorePriceRow>> watchStorePrices(int itemId) {
    final query =
        select(
            itemStores,
          ).join([innerJoin(stores, stores.id.equalsExp(itemStores.storeId))])
          ..where(itemStores.itemId.equals(itemId))
          ..orderBy([OrderingTerm.desc(itemStores.price)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (r) => StorePriceRow(
              price: r.readTable(itemStores),
              store: r.readTable(stores),
            ),
          )
          .toList(),
    );
  }

  /// Watch the full price history of an item across all stores (JOINed so
  /// the v1 per-store N+1 disappears).
  Stream<List<PriceHistoryWithStore>> watchPriceHistory(int itemId) {
    final query =
        select(itemStores).join([
            innerJoin(stores, stores.id.equalsExp(itemStores.storeId)),
            innerJoin(
              itemPriceHistory,
              itemPriceHistory.itemStoreId.equalsExp(itemStores.id),
            ),
          ])
          ..where(itemStores.itemId.equals(itemId))
          ..orderBy([OrderingTerm.desc(itemPriceHistory.recordedAt)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (r) => PriceHistoryWithStore(
              history: r.readTable(itemPriceHistory),
              itemStore: r.readTable(itemStores),
              store: r.readTable(stores),
            ),
          )
          .toList(),
    );
  }

  /// Insert or update by barcode (the import/backup/scan-save path).
  /// Returns the row id. Runs inside a transaction so the check-then-act
  /// is atomic under concurrent imports.
  Future<int> upsertByBarcode(ItemsCompanion companion) =>
      transaction(() async {
        final barcode = companion.barcode.present
            ? companion.barcode.value
            : null;
        if (barcode == null || barcode.isEmpty) {
          return into(items).insert(companion);
        }
        final existing = await findByBarcode(barcode);
        if (existing == null) {
          return into(items).insert(companion);
        }
        await (update(items)..where((t) => t.id.equals(existing.id))).write(
          _mergeForUpsert(companion),
        );
        return existing.id;
      });

  /// Merge semantics for the upsert path: only overwrite with values that
  /// are actually present (non-absent) in the incoming companion — matches
  /// v1's `upsertByBarcode` behaviour.
  ItemsCompanion _mergeForUpsert(ItemsCompanion incoming) => ItemsCompanion(
    brand: incoming.brand.present && incoming.brand.value != null
        ? incoming.brand
        : const Value.absent(),
    nameEn: incoming.nameEn.present && incoming.nameEn.value.isNotEmpty
        ? incoming.nameEn
        : const Value.absent(),
    nameAr: incoming.nameAr.present && incoming.nameAr.value != null
        ? incoming.nameAr
        : const Value.absent(),
    note: incoming.note.present && incoming.note.value != null
        ? incoming.note
        : const Value.absent(),
    price: incoming.price.present && incoming.price.value != null
        ? incoming.price
        : const Value.absent(),
    currency: incoming.currency.present
        ? incoming.currency
        : const Value.absent(),
    imageUrl: incoming.imageUrl.present && incoming.imageUrl.value != null
        ? incoming.imageUrl
        : const Value.absent(),
    categoryId: incoming.categoryId.present && incoming.categoryId.value != null
        ? incoming.categoryId
        : const Value.absent(),
    updatedAt: incoming.updatedAt,
  );

  Future<int> insertItem(ItemsCompanion companion) =>
      into(items).insert(companion);

  Future<void> updateItem(int id, ItemsCompanion companion) =>
      (update(items)..where((t) => t.id.equals(id))).write(companion);

  Future<int> deleteItem(int id) =>
      (delete(items)..where((t) => t.id.equals(id))).go();

  /// Live item count (dashboard KPI).
  Stream<int> watchCount() {
    final count = items.id.count();
    final q = selectOnly(items)..addColumns([count]);
    return q.watchSingle().map((r) => r.read(count) ?? 0);
  }

  /// Live count of distinct stores that have at least one linked item.
  Stream<int> watchLinkedStoreCount() {
    final cnt = itemStores.storeId.count(distinct: true);
    final q = selectOnly(itemStores)..addColumns([cnt]);
    return q.watchSingle().map((r) => r.read(cnt) ?? 0);
  }
}

/// One item_store price joined with its store.
class StorePriceRow {
  final ItemStoreRow price;
  final StoreRow store;

  const StorePriceRow({required this.price, required this.store});
}

/// One price-history entry joined with its store.
class PriceHistoryWithStore {
  final PriceHistoryRow history;
  final ItemStoreRow itemStore;
  final StoreRow store;

  PriceHistoryWithStore({
    required this.history,
    required this.itemStore,
    required this.store,
  });
}
