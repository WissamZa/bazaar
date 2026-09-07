import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart' show CategoryRow, StoreRow;
import '../database/daos/item_dao.dart';
import '../database/daos/list_item_dao.dart';
import '../database/daos/shopping_list_dao.dart';
import '../database/daos/store_dao.dart';
import 'database_provider.dart';

/// Reactive data providers — every screen watches these instead of running
/// imperative refreshes. All of them stream from drift, so any DB write
/// anywhere in the app automatically updates every visible screen (this
/// replaces v1's dead `DataChangeNotifier` + manual `_refresh()` pattern).

final _db = databaseProvider;

// ── Dashboard ──────────────────────────────────────────────────────────────
final listsCountProvider = StreamProvider<int>(
  (ref) => ref.watch(_db).shoppingListDao.watchCount(),
);

final itemsCountProvider = StreamProvider<int>(
  (ref) => ref.watch(_db).itemDao.watchCount(),
);

final storesCountProvider = StreamProvider<int>(
  (ref) => ref.watch(_db).storeDao.watchCount(),
);

final recentListsProvider = StreamProvider<List<ListWithStats>>(
  (ref) => ref.watch(_db).shoppingListDao.watchAllWithStats(limit: 3),
);

final storesByItemCountProvider = StreamProvider<List<StoreItemCount>>(
  (ref) => ref.watch(_db).storeDao.watchByItemCount(),
);

/// Top-5 most expensive items by effective price (single streamed query).
final topExpensiveItemsProvider = StreamProvider<List<ItemWithEffectivePrice>>((
  ref,
) {
  final dao = ref.watch(_db).itemDao;
  return dao.watchAll(sort: ItemSort.priceHigh).map((rows) {
    final priced = rows
        .where((r) => r.displayPrice != null)
        .toList(growable: false);
    return priced.take(5).toList(growable: false);
  });
});

// ── Items ──────────────────────────────────────────────────────────────────
/// Riverpod 3 has no StateProvider in the core API — a tiny Notifier pair
/// keeps the sort/search UI state.
class ItemSortNotifier extends Notifier<ItemSort> {
  @override
  ItemSort build() => ItemSort.newest;
  void set(ItemSort v) => state = v;
}

class ItemSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) => state = v;
}

final itemSortProvider = NotifierProvider<ItemSortNotifier, ItemSort>(
  ItemSortNotifier.new,
);
final itemSearchProvider = NotifierProvider<ItemSearchNotifier, String>(
  ItemSearchNotifier.new,
);

final itemsStreamProvider = StreamProvider<List<ItemWithEffectivePrice>>((ref) {
  final sort = ref.watch(itemSortProvider);
  final search = ref.watch(itemSearchProvider);
  return ref.watch(_db).itemDao.watchAll(sort: sort, search: search);
});

// ── Lists ──────────────────────────────────────────────────────────────────
final listsWithStatsProvider = StreamProvider<List<ListWithStats>>(
  (ref) => ref.watch(_db).shoppingListDao.watchAllWithStats(),
);

final listDetailProvider = StreamProvider.family<List<ListItemWithItem>, int>(
  (ref, listId) => ref.watch(_db).listItemDao.watchForList(listId),
);

final listHeaderProvider = StreamProvider.family<ListWithStats, int>((
  ref,
  listId,
) async* {
  await for (final lists
      in ref.watch(_db).shoppingListDao.watchAllWithStats()) {
    final match = lists.where((l) => l.list.id == listId).firstOrNull;
    if (match != null) yield match;
  }
});

// ── Stores ─────────────────────────────────────────────────────────────────
final storesStreamProvider = StreamProvider<List<StoreRow>>(
  (ref) => ref.watch(_db).storeDao.watchAll(),
);

final storeDetailProvider = StreamProvider.family<List<ItemAtStoreRow>, int>(
  (ref, storeId) => ref.watch(_db).storeDao.watchItemsAtStore(storeId),
);

// ── Categories ─────────────────────────────────────────────────────────────
final categoriesStreamProvider = StreamProvider<List<CategoryRow>>(
  (ref) => ref.watch(_db).categoryDao.watchAll(),
);
