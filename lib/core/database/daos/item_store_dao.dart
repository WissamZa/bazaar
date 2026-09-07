import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'item_store_dao.g.dart';

/// Data access for `item_store` (per-store prices) and `item_price_history`.
@DriftAccessor(tables: [ItemStores, ItemPriceHistory])
class ItemStoreDao extends DatabaseAccessor<AppDatabase>
    with _$ItemStoreDaoMixin {
  ItemStoreDao(super.db);

  // Table shortcuts (the generated mixin no longer forwards these).
  $ItemStoresTable get itemStores => attachedDatabase.itemStores;
  $ItemPriceHistoryTable get itemPriceHistory =>
      attachedDatabase.itemPriceHistory;

  Future<ItemStoreRow?> findByItemAndStore(int itemId, int storeId) =>
      (select(itemStores)
            ..where((t) => t.itemId.equals(itemId))
            ..where((t) => t.storeId.equals(storeId)))
          .getSingleOrNull();

  Future<List<ItemStoreRow>> forItem(int itemId) =>
      (select(itemStores)..where((t) => t.itemId.equals(itemId))).get();

  /// Upsert a per-store price **without** wiping price history.
  ///
  /// BUGFIX vs v1: the old code used `ConflictAlgorithm.replace`, which in
  /// SQLite deletes the conflicting row and re-inserts it with a new id.
  /// Because `item_price_history.item_store_id` cascades on delete of
  /// `item_store`, every price edit silently destroyed the item's whole
  /// price history. We now update in place (keeping the same row id) and
  /// append a history entry whenever the price actually changed.
  Future<void> upsertWithHistory(ItemStoresCompanion companion) async {
    await transaction(() async {
      final itemId = companion.itemId.present ? companion.itemId.value : null;
      final storeId = companion.storeId.present
          ? companion.storeId.value
          : null;
      if (itemId == null || storeId == null) {
        throw ArgumentError('upsertWithHistory needs itemId and storeId');
      }
      final price = companion.price.present ? companion.price.value : null;
      final currency = companion.currency.present
          ? companion.currency.value
          : 'SAR';
      final existing = await findByItemAndStore(itemId, storeId);
      final now = DateTime.now().toIso8601String();

      if (existing == null) {
        final newId = await into(itemStores).insert(companion);
        if (price != null) {
          await _appendHistory(newId, price, currency, now);
        }
        return;
      }

      final priceChanged =
          price != null && (existing.price == null || existing.price != price);
      await (update(itemStores)..where((t) => t.id.equals(existing.id))).write(
        ItemStoresCompanion(
          price: Value(price),
          currency: Value(currency),
          url: companion.url,
        ),
      );
      if (priceChanged) {
        await _appendHistory(existing.id, price, currency, now);
      }
    });
  }

  Future<void> _appendHistory(
    int itemStoreId,
    double? price,
    String currency,
    String now,
  ) {
    return into(itemPriceHistory).insert(
      ItemPriceHistoryCompanion.insert(
        itemStoreId: itemStoreId,
        price: Value(price),
        currency: Value(currency),
        recordedAt: now,
      ),
    );
  }

  /// Delete a per-store price row (also cascades to its history via FK).
  Future<int> removeByItemAndStore(int itemId, int storeId) =>
      (delete(itemStores)
            ..where((t) => t.itemId.equals(itemId))
            ..where((t) => t.storeId.equals(storeId)))
          .go();

  /// Raw rows for the backup exporter (kept as plain maps by the caller).
  Future<List<ItemStoreRow>> all() => select(itemStores).get();
}
