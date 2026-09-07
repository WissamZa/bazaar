import 'package:drift/drift.dart' show Value;

import '../constants/currencies.dart';
import '../database/app_database.dart';
import '../database/daos/item_dao.dart';
import '../database/daos/item_store_dao.dart';
import '../database/daos/store_dao.dart';
import 'scraper_service.dart';

/// Orchestrates the barcode flow:
///   1. scan from camera (ScannerScreen returns a code)
///   2. look the code up in the local DB (local-first — never duplicates)
///   3. fall back to the online scraping chain
class BarcodeService {
  final AppDatabase db;

  BarcodeService(this.db);

  /// Local-first lookup, then the full online chain.
  Future<BarcodeLookup> lookup(String code, {CancelToken? cancelToken}) async {
    final local = await db.itemDao.findByBarcode(code);
    if (local != null) return BarcodeLookup.local(local);
    final online = await ScraperService.instance.searchBarcode(
      code,
      cancelToken: cancelToken,
    );
    return BarcodeLookup.online(code, online);
  }

  /// Lookup restricted to a specific [source]. The local DB is still
  /// consulted first (unless [skipLocal]) so existing items are never
  /// duplicated.
  Future<BarcodeLookup> lookupFromSource(
    String code,
    LookupSource source, {
    bool skipLocal = false,
    CancelToken? cancelToken,
  }) async {
    if (!skipLocal) {
      final local = await db.itemDao.findByBarcode(code);
      if (local != null && source == LookupSource.auto) {
        return BarcodeLookup.local(local);
      }
    }
    final online = await ScraperService.instance.searchBarcodeFromSource(
      code,
      source,
      cancelToken: cancelToken,
    );
    return BarcodeLookup.online(code, online);
  }

  /// Ensure [itemId] is linked to at least one store — items with no store
  /// link are attached to the implicit Default store. Idempotent.
  Future<void> ensureDefaultStoreLink(
    int itemId, {
    double? price,
    String currency = 'SAR',
  }) async {
    final links = await db.itemStoreDao.forItem(itemId);
    if (links.isNotEmpty) return;
    final defaultStore = await db.storeDao.getOrCreateDefault();
    await db.itemStoreDao.upsertWithHistory(
      ItemStoresCompanion.insert(
        itemId: itemId,
        storeId: defaultStore.id,
        price: Value(price),
        currency: Value(currency),
      ),
    );
  }

  /// Save a scraped product as a full item (scan-result "Add to items").
  /// Returns the item id. Links to the Default store with the scraped price.
  Future<int> saveScrapedProduct(ScrapedProduct product, String barcode) async {
    final now = DateTime.now();
    final id = await db.itemDao.upsertByBarcode(
      ItemsCompanion.insert(
        nameEn: product.name,
        createdAt: now.toIso8601String(),
        updatedAt: now.toIso8601String(),
        barcode: Value(barcode),
        brand: Value(product.brand),
        nameAr: Value(product.nameAr),
        price: Value(product.price),
        currency: Value(product.currency),
        imageUrl: Value(product.imageUrl),
      ),
    );
    if (product.price != null) {
      final defaultStore = await db.storeDao.getOrCreateDefault();
      await db.itemStoreDao.upsertWithHistory(
        ItemStoresCompanion.insert(
          itemId: id,
          storeId: defaultStore.id,
          price: Value(product.price),
          currency: Value(product.currency),
        ),
      );
    }
    return id;
  }
}

/// Result of a barcode lookup.
class BarcodeLookup {
  final String code;
  final ItemRow? localItem;
  final ScrapedProduct? onlineProduct;

  const BarcodeLookup._({
    required this.code,
    this.localItem,
    this.onlineProduct,
  });

  factory BarcodeLookup.local(ItemRow item) =>
      BarcodeLookup._(code: item.barcode ?? '', localItem: item);

  factory BarcodeLookup.online(String code, ScrapedProduct? product) =>
      BarcodeLookup._(code: code, onlineProduct: product);

  bool get foundLocal => localItem != null;
  bool get foundOnline => onlineProduct != null;
  bool get found => foundLocal || foundOnline;
}
