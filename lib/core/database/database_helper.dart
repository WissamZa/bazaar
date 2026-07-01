import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Single-instance SQLite helper. Boots the DB, runs schema + migrations,
/// exposes a [database] getter used by every DAO.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'bazaar.db';
  static const _dbVersion = 5;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Enable foreign keys so cascade deletes work.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE users (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        username   TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE stores (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT NOT NULL,
        name_ar    TEXT,
        website    TEXT,
        address    TEXT,
        image_url  TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE categories (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT NOT NULL,
        name_ar    TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
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
    ''');

    batch.execute('''
      CREATE TABLE item_store (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id  INTEGER REFERENCES items(id) ON DELETE CASCADE,
        store_id INTEGER REFERENCES stores(id) ON DELETE CASCADE,
        price    REAL,
        currency TEXT DEFAULT 'SAR',
        url      TEXT,
        UNIQUE(item_id, store_id)
      )
    ''');

    batch.execute('''
      CREATE TABLE shopping_lists (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT NOT NULL,
        name_ar     TEXT,
        owner       TEXT NOT NULL,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL
      )
    ''');

    batch.execute('''
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
    ''');

    batch.execute('CREATE INDEX idx_items_barcode ON items(barcode)');
    batch.execute('CREATE INDEX idx_list_items_list ON list_items(list_id)');
    batch.execute('CREATE INDEX idx_item_store_item ON item_store(item_id)');

    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    // v2: add stores.address column for existing installs. Fresh installs
    // already get the column via _onCreate.
    if (oldV < 2) {
      await db.execute('ALTER TABLE stores ADD COLUMN address TEXT;');
    }
    if (oldV < 3) {
      await db.execute('''
        CREATE TABLE categories (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          name       TEXT NOT NULL,
          name_ar    TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'ALTER TABLE items ADD COLUMN category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL;',
      );
    }
    if (oldV < 4) {
      await db.execute('ALTER TABLE stores ADD COLUMN image_url TEXT;');
    }
    if (oldV < 5) {
      await db.execute('ALTER TABLE items ADD COLUMN brand TEXT;');
      await db.execute('ALTER TABLE items ADD COLUMN note TEXT;');
    }
  }

  // ───────────────────────── Maintenance helpers ─────────────────────────
  Future<void> wipeAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('list_items');
      await txn.delete('item_store');
      await txn.delete('shopping_lists');
      await txn.delete('items');
      await txn.delete('stores');
      await txn.delete('users');
    });
  }
}
