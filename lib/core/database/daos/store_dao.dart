import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'store_dao.g.dart';

/// Data access for `stores`.
@DriftAccessor(tables: [Stores, Items, ItemStores])
class StoreDao extends DatabaseAccessor<AppDatabase> with _$StoreDaoMixin {
  StoreDao(super.db);

  // Table shortcuts (the generated mixin no longer forwards these).
  $StoresTable get stores => attachedDatabase.stores;
  $ItemsTable get items => attachedDatabase.items;
  $ItemStoresTable get itemStores => attachedDatabase.itemStores;

  Stream<List<StoreRow>> watchAll() =>
      (select(stores)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<List<StoreRow>> all() =>
      (select(stores)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  Future<StoreRow?> findById(int id) =>
      (select(stores)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<StoreRow?> watchById(int id) =>
      (select(stores)..where((t) => t.id.equals(id))).watchSingleOrNull();

  /// Live count of stores the user created (KPI).
  Stream<int> watchCount() {
    final count = stores.id.count();
    final q = selectOnly(stores)..addColumns([count]);
    return q.watchSingle().map((r) => r.read(count) ?? 0);
  }

  /// The implicit "Default" store every v1 install had — items without an
  /// explicit store land here. Created on demand.
  Future<StoreRow> getOrCreateDefault() async {
    final existing = await (select(
      stores,
    )..where((t) => t.name.equals('Default'))).getSingleOrNull();
    if (existing != null) return existing;
    final id = await into(stores).insert(
      StoresCompanion.insert(
        name: 'Default',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    return (await findById(id))!;
  }

  Future<int> insertStore(StoresCompanion companion) =>
      into(stores).insert(companion);

  Future<void> updateStore(int id, StoresCompanion companion) =>
      (update(stores)..where((t) => t.id.equals(id))).write(companion);

  /// Upsert by name (import path). Name is the v1 merge key.
  Future<int> upsertByName(StoresCompanion companion) async {
    final name = companion.name.present
        ? companion.name.value
        : (throw ArgumentError('upsertByName requires a name'));
    final existing = await (select(
      stores,
    )..where((t) => t.name.equals(name))).getSingleOrNull();
    if (existing == null) return into(stores).insert(companion);
    await (update(stores)..where((t) => t.id.equals(existing.id))).write(
      StoresCompanion(
        nameAr: companion.nameAr.present && companion.nameAr.value != null
            ? companion.nameAr
            : const Value.absent(),
        website: companion.website.present && companion.website.value != null
            ? companion.website
            : const Value.absent(),
        address: companion.address.present && companion.address.value != null
            ? companion.address
            : const Value.absent(),
        imageUrl: companion.imageUrl.present && companion.imageUrl.value != null
            ? companion.imageUrl
            : const Value.absent(),
      ),
    );
    return existing.id;
  }

  Future<int> deleteStore(int id) =>
      (delete(stores)..where((t) => t.id.equals(id))).go();

  /// "Stores by item count" for the dashboard — one aggregated stream.
  Stream<List<StoreItemCount>> watchByItemCount({int limit = 8}) {
    final cnt = itemStores.id.count();
    final q =
        selectOnly(
            itemStores,
          ).join([innerJoin(stores, stores.id.equalsExp(itemStores.storeId))])
          ..addColumns([stores.id, stores.name, stores.imageUrl, cnt])
          ..groupBy([stores.id])
          ..orderBy([OrderingTerm.desc(cnt)])
          ..limit(limit);
    return q.watch().map(
      (rows) => rows
          .map(
            (row) => StoreItemCount(
              store: StoreRow(
                id: row.read(stores.id)!,
                name: row.read(stores.name)!,
                nameAr: null,
                website: null,
                address: null,
                imageUrl: row.read(stores.imageUrl),
                createdAt: '',
              ),
              itemCount: row.read(cnt) ?? 0,
            ),
          )
          .toList(),
    );
  }

  /// Items + their price rows at one store — replaces the v1 N+1 screen.
  Stream<List<ItemAtStoreRow>> watchItemsAtStore(int storeId) {
    final query =
        select(
            itemStores,
          ).join([innerJoin(items, items.id.equalsExp(itemStores.itemId))])
          ..where(itemStores.storeId.equals(storeId))
          ..orderBy([OrderingTerm.desc(items.updatedAt)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (r) => ItemAtStoreRow(
              item: r.readTable(items),
              price: r.readTable(itemStores),
            ),
          )
          .toList(),
    );
  }
}

class StoreItemCount {
  final StoreRow store;
  final int itemCount;

  const StoreItemCount({required this.store, required this.itemCount});
}

class ItemAtStoreRow {
  final ItemRow item;
  final ItemStoreRow price;

  const ItemAtStoreRow({required this.item, required this.price});
}
