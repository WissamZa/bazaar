import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'list_item_dao.g.dart';

/// A list_items row joined with its catalog item and resolved preferred
/// store (nullable). One streamed JOIN replaces the v1's per-row lookups.
class ListItemWithItem {
  final ListItemRow listItem;
  final ItemRow item;
  final StoreRow? preferredStore;
  final double? preferredPrice;
  final String? preferredCurrency;

  /// Cheapest recorded store price across all stores (null when none).
  final double? lowestPrice;
  final String? lowestCurrency;

  ListItemWithItem({
    required this.listItem,
    required this.item,
    this.preferredStore,
    this.preferredPrice,
    this.preferredCurrency,
    this.lowestPrice,
    this.lowestCurrency,
  });

  /// Preferred > lowest > legacy item price.
  double? get effectivePrice => preferredPrice ?? lowestPrice ?? item.price;

  String get effectiveCurrency =>
      preferredCurrency ?? lowestCurrency ?? item.currency;
}

/// Data access for `list_items`.
@DriftAccessor(tables: [ListItems, Items, Stores, ItemStores])
class ListItemDao extends DatabaseAccessor<AppDatabase>
    with _$ListItemDaoMixin {
  ListItemDao(super.db);

  // Table shortcuts (the generated mixin no longer forwards these).
  $ListItemsTable get listItems => attachedDatabase.listItems;
  $ItemsTable get items => attachedDatabase.items;
  $StoresTable get stores => attachedDatabase.stores;
  $ItemStoresTable get itemStores => attachedDatabase.itemStores;

  /// Watch a list's rows with item + preferred-store + cheapest-store data
  /// resolved in a single streamed query.
  Stream<List<ListItemWithItem>> watchForList(int listId) {
    final preferred = alias(itemStores, 'ps');
    final lowest = alias(itemStores, 'ls_agg');
    final minPriceExp = lowest.price.min();

    final cheapest = Subquery(
      selectOnly(lowest)
        ..addColumns([lowest.itemId, minPriceExp, lowest.currency])
        ..groupBy([lowest.itemId]),
      'ls_agg',
    );
    final minPriceRef = cheapest.ref(minPriceExp);
    final minCurrencyRef = cheapest.ref(lowest.currency);

    final query =
        select(listItems).join([
            innerJoin(items, items.id.equalsExp(listItems.itemId)),
            leftOuterJoin(
              stores,
              stores.id.equalsExp(listItems.preferredStoreId),
            ),
            leftOuterJoin(
              preferred,
              Expression.and([
                preferred.itemId.equalsExp(listItems.itemId),
                preferred.storeId.equalsExp(listItems.preferredStoreId),
              ]),
            ),
            leftOuterJoin(
              cheapest,
              cheapest.ref(lowest.itemId).equalsExp(listItems.itemId),
            ),
          ])
          ..where(listItems.listId.equals(listId))
          ..addColumns([minPriceRef, minCurrencyRef])
          ..orderBy([OrderingTerm.asc(listItems.id)]);

    return query.watch().map(
      (rows) => rows.map((r) {
        final li = r.readTable(listItems);
        final item = r.readTable(items);
        final hasPreferred = li.preferredStoreId != null;
        final ps = hasPreferred ? r.readTableOrNull(preferred) : null;
        return ListItemWithItem(
          listItem: li,
          item: item,
          preferredStore: hasPreferred ? r.readTableOrNull(stores) : null,
          preferredPrice: ps?.price,
          preferredCurrency: ps?.currency,
          lowestPrice: r.read(minPriceRef),
          lowestCurrency: r.read(minCurrencyRef),
        );
      }).toList(),
    );
  }

  Future<ListItemRow?> findRow(int listId, int itemId) =>
      (select(listItems)
            ..where((t) => t.listId.equals(listId))
            ..where((t) => t.itemId.equals(itemId)))
          .getSingleOrNull();

  /// Add (or bump the quantity of) an item in a list. Returns the row id.
  Future<int> addItemToList({
    required int listId,
    required int itemId,
    int quantity = 1,
  }) async {
    final existing = await findRow(listId, itemId);
    if (existing != null) {
      await (update(listItems)..where((t) => t.id.equals(existing.id))).write(
        ListItemsCompanion(quantity: Value(existing.quantity + quantity)),
      );
      return existing.id;
    }
    return into(listItems).insert(
      ListItemsCompanion.insert(
        listId: listId,
        itemId: itemId,
        quantity: Value(quantity),
      ),
    );
  }

  Future<void> setChecked(int rowId, bool checked) =>
      (update(listItems)..where((t) => t.id.equals(rowId))).write(
        ListItemsCompanion(isChecked: Value(checked ? 1 : 0)),
      );

  Future<void> setQuantity(int rowId, int quantity) =>
      (update(listItems)..where((t) => t.id.equals(rowId))).write(
        ListItemsCompanion(quantity: Value(quantity < 1 ? 1 : quantity)),
      );

  Future<void> setPreferredStore(int rowId, int? storeId) =>
      (update(listItems)..where((t) => t.id.equals(rowId))).write(
        ListItemsCompanion(preferredStoreId: Value(storeId)),
      );

  Future<void> setNote(int rowId, String? note) =>
      (update(listItems)..where((t) => t.id.equals(rowId))).write(
        ListItemsCompanion(note: Value(note)),
      );

  Future<int> removeRow(int rowId) =>
      (delete(listItems)..where((t) => t.id.equals(rowId))).go();

  Future<int> insertRaw(ListItemsCompanion companion) =>
      into(listItems).insert(companion);
}
