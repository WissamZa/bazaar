import 'package:drift/drift.dart';

import 'daos/category_dao.dart';
import 'daos/item_dao.dart';
import 'daos/item_store_dao.dart';
import 'daos/list_item_dao.dart';
import 'daos/shopping_list_dao.dart';
import 'daos/store_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The single drift database for the app.
///
/// Opens `bazaar.db` at [schemaVersion] 6 with the exact schema the v1.x
/// sqflite code created, so:
///   • upgrading from v1.4.x opens the existing file with zero migration;
///   • a fresh v2 install produces a byte-identical schema (see
///     [_onCreateV6]) — backup ZIPs and JSON exports remain compatible in
///     both directions.
@DriftDatabase(
  tables: [
    Users,
    Stores,
    Categories,
    Items,
    ItemStores,
    ShoppingLists,
    ListItems,
    ItemPriceHistory,
  ],
  daos: [
    ItemDao,
    StoreDao,
    CategoryDao,
    ShoppingListDao,
    ListItemDao,
    ItemStoreDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      // Hand-written instead of m.createAll() so a fresh install gets
      // the exact v1 CREATE statements (indexes included).
      for (final stmt in _onCreateV6) {
        await customStatement(stmt);
      }
    },
    onUpgrade: (m, from, to) async {
      // v1 apps ran migrations 1→6; nothing above 6 exists yet. Kept as
      // an explicit no-op so a future version bump has a home.
      assert(to <= 6, 'bump schema and add migrations here');
    },
    beforeOpen: (details) async {
      // Enable FK enforcement exactly like the v1 sqflite onConfigure.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// The exact CREATE statements from the v1 `DatabaseHelper._onCreate`
  /// (schema v6), kept verbatim for cross-version compatibility.
  static const List<String> _onCreateV6 = [
    '''
      CREATE TABLE users (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        username   TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''',
    '''
      CREATE TABLE stores (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT NOT NULL,
        name_ar    TEXT,
        website    TEXT,
        address    TEXT,
        image_url  TEXT,
        created_at TEXT NOT NULL
      )
    ''',
    '''
      CREATE TABLE categories (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT NOT NULL,
        name_ar    TEXT,
        created_at TEXT NOT NULL
      )
    ''',
    '''
      CREATE TABLE items (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode    TEXT UNIQUE,
        brand      TEXT,
        name_en    TEXT NOT NULL,
        name_ar    TEXT,
        note       TEXT,
        price      REAL,
        currency   TEXT DEFAULT 'SAR',
        image_url  TEXT,
        category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''',
    '''
      CREATE TABLE item_store (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id  INTEGER REFERENCES items(id) ON DELETE CASCADE,
        store_id INTEGER REFERENCES stores(id) ON DELETE CASCADE,
        price    REAL,
        currency TEXT DEFAULT 'SAR',
        url      TEXT,
        UNIQUE(item_id, store_id)
      )
    ''',
    '''
      CREATE TABLE shopping_lists (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT NOT NULL,
        name_ar     TEXT,
        owner       TEXT NOT NULL,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL
      )
    ''',
    '''
      CREATE TABLE list_items (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        list_id            INTEGER REFERENCES shopping_lists(id) ON DELETE CASCADE,
        item_id            INTEGER REFERENCES items(id) ON DELETE CASCADE,
        quantity           INTEGER DEFAULT 1,
        is_checked         INTEGER DEFAULT 0,
        preferred_store_id INTEGER REFERENCES stores(id),
        note               TEXT,
        UNIQUE(list_id, item_id)
      )
    ''',
    '''
      CREATE TABLE item_price_history (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        item_store_id INTEGER REFERENCES item_store(id) ON DELETE CASCADE,
        price         REAL,
        currency      TEXT DEFAULT 'SAR',
        recorded_at   TEXT NOT NULL
      )
    ''',
    'CREATE INDEX idx_price_history_store ON item_price_history(item_store_id)',
    'CREATE INDEX idx_items_barcode ON items(barcode)',
    'CREATE INDEX idx_list_items_list ON list_items(list_id)',
    'CREATE INDEX idx_item_store_item ON item_store(item_id)',
  ];

  /// Wipe every table (order respects FKs). Used by "reset app data".
  Future<void> wipeAll() async {
    await batch((b) {
      b.deleteAll(listItems);
      b.deleteAll(itemPriceHistory);
      b.deleteAll(itemStores);
      b.deleteAll(shoppingLists);
      b.deleteAll(items);
      b.deleteAll(categories);
      b.deleteAll(stores);
      b.deleteAll(users);
    });
  }
}
