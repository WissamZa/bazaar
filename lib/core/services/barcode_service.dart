import 'dart:async';

import '../constants/currencies.dart';
import '../database/dao/item_dao.dart';
import '../database/dao/item_store_dao.dart';
import '../database/dao/store_dao.dart';
import '../models/item.dart';
import '../models/item_store.dart';
import 'scraper_service.dart';

/// Orchestrates the three-step barcode flow:
///   1. scan from camera (caller opens [ScannerScreen] which returns a code)
///   2. look up the code in the local DB
///   3. fall back to online scraping
class BarcodeService {
  BarcodeService._();
  static final BarcodeService instance = BarcodeService._();

  final ItemDao _itemDao = ItemDao.instance;
  final ScraperService _scraper = ScraperService.instance;

  /// Lookup a barcode locally first, then online using the full chain.
  /// Returns a [BarcodeLookup] describing what was found.
  Future<BarcodeLookup> lookup(String code) async {
    final local = await _itemDao.findByBarcode(code);
    if (local != null) {
      return BarcodeLookup.local(local);
    }
    final online = await _scraper.searchBarcode(code);
    return BarcodeLookup.online(code, online);
  }

  /// Lookup a barcode from a specific online [source] only. Local DB is
  /// still consulted first so we never duplicate existing items.
  /// Pass [skipLocal] = true to force an online-only lookup (e.g. when the
  /// user explicitly wants to refresh prices from a specific store).
  Future<BarcodeLookup> lookupFromSource(
    String code,
    LookupSource source, {
    bool skipLocal = false,
  }) async {
    if (!skipLocal) {
      final local = await _itemDao.findByBarcode(code);
      if (local != null && source == LookupSource.auto) {
        return BarcodeLookup.local(local);
      }
    }
    final online = await _scraper.searchBarcodeFromSource(code, source);
    return BarcodeLookup.online(code, online);
  }

  /// Ensure [item] (already saved) is linked to at least one store.
  ///
  /// Behavior:
  ///   1. ALWAYS creates the Default store if it doesn't exist (so the
  ///      Stores screen is never empty, and items always have somewhere
  ///      to live).
  ///   2. If [item] already has at least one store link, do nothing else —
  ///      the user has explicitly chosen where this item belongs.
  ///   3. If [item] has NO store links, link it to the Default store so
  ///      it's never orphaned.
  ///
  /// Idempotent — safe to call after every save.
  Future<void> ensureDefaultStoreLink(Item item) async {
    // Always make sure the Default store exists. This is cheap (one SELECT
    // by name; INSERT only if not found) and guarantees the Stores screen
    // always has at least one entry.
    final defaultStoreId = await StoreDao.instance.getOrCreateDefault();

    if (item.id == null) return;
    final links = await ItemStoreDao.instance.forItem(item.id!);
    if (links.isNotEmpty) return;

    // No existing links — link to Default so the item shows up somewhere.
    await ItemStoreDao.instance.upsert(ItemStore(
      itemId: item.id!,
      storeId: defaultStoreId,
      price: item.price,
      currency: item.currency,
      url: null,
    ));
  }
}

/// Result of a barcode lookup.
class BarcodeLookup {
  final String code;
  final Item? localItem;
  final ScrapedProduct? onlineProduct;

  const BarcodeLookup._({
    required this.code,
    this.localItem,
    this.onlineProduct,
  });

  factory BarcodeLookup.local(Item item) =>
      BarcodeLookup._(code: item.barcode ?? '', localItem: item);

  factory BarcodeLookup.online(String code, ScrapedProduct? product) =>
      BarcodeLookup._(code: code, onlineProduct: product);

  bool get foundLocal => localItem != null;
  bool get foundOnline => onlineProduct != null;
  bool get found => foundLocal || foundOnline;
}
