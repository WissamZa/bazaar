import 'package:drift/drift.dart';

/// Drift table definitions mirroring the legacy raw-sqflite schema v6
/// byte-for-byte (same table names, column names, types, constraints).
///
/// Compatibility contract with v1.4.x installs:
///  • The database file is still `<databases>/bazaar.db` at `schemaVersion 6`
///    — an upgrade opens the existing file without any migration.
///  • Fresh installs are created with the *original* CREATE statements (see
///    [AppDatabase._onCreateV6]) so a v2 database is indistinguishable from
///    a v1 one (backups and exports stay interchangeable).
///  • Dates remain ISO-8601 TEXT (not drift's int epoch mapping) to keep the
///    on-disk format identical.
///
/// NOTE ON THE CASCADE FKs: drift's `references()` cannot emit
/// `ON DELETE CASCADE`, so every FK that carries a delete action uses
/// `customConstraint` with the exact clause from the v1 schema instead.

@DataClassName('UserRow')
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get username => text().unique()();
  TextColumn get createdAt => text()();
}

@DataClassName('StoreRow')
class Stores extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get nameAr => text().nullable()();
  TextColumn get website => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get createdAt => text()();
}

@DataClassName('CategoryRow')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get nameAr => text().nullable()();
  TextColumn get createdAt => text()();
}

@DataClassName('ItemRow')
class Items extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get barcode => text().nullable().unique()();
  TextColumn get brand => text().nullable()();
  TextColumn get nameEn => text()();
  TextColumn get nameAr => text().nullable()();
  TextColumn get note => text().nullable()();
  RealColumn get price => real().nullable()();
  TextColumn get currency => text().withDefault(const Constant('SAR'))();
  TextColumn get imageUrl => text().nullable()();
  IntColumn get categoryId => integer().nullable().customConstraint(
    'REFERENCES categories(id) ON DELETE SET NULL',
  )();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}

@DataClassName('ItemStoreRow')
class ItemStores extends Table {
  @override
  String get tableName => 'item_store'; // legacy v6 name (not `item_stores`)

  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId =>
      integer().customConstraint('REFERENCES items(id) ON DELETE CASCADE')();
  IntColumn get storeId =>
      integer().customConstraint('REFERENCES stores(id) ON DELETE CASCADE')();
  RealColumn get price => real().nullable()();
  TextColumn get currency => text().withDefault(const Constant('SAR'))();
  TextColumn get url => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {itemId, storeId},
  ];
}

@DataClassName('ShoppingListRow')
class ShoppingLists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get nameAr => text().nullable()();
  TextColumn get owner => text()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}

@DataClassName('ListItemRow')
class ListItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get listId => integer().customConstraint(
    'REFERENCES shopping_lists(id) ON DELETE CASCADE',
  )();
  IntColumn get itemId =>
      integer().customConstraint('REFERENCES items(id) ON DELETE CASCADE')();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  // Stored as INTEGER 0/1 in the legacy schema — mapped to bool via
  // BoolColumn's default TEXT? No: BoolColumn maps to INTEGER 0/1 already.
  IntColumn get isChecked => integer().withDefault(const Constant(0))();
  IntColumn get preferredStoreId =>
      integer().nullable().customConstraint('REFERENCES stores(id)')();
  TextColumn get note => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {listId, itemId},
  ];
}

@DataClassName('PriceHistoryRow')
class ItemPriceHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemStoreId => integer().customConstraint(
    'REFERENCES item_store(id) ON DELETE CASCADE',
  )();
  RealColumn get price => real().nullable()();
  TextColumn get currency => text().withDefault(const Constant('SAR'))();
  TextColumn get recordedAt => text()();
}
