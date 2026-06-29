import 'dart:async';
import 'package:flutter/material.dart';

import '../database/dao/item_dao.dart';
import '../models/item.dart';
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

  /// Lookup a barcode locally first, then online.
  /// Returns a [BarcodeLookup] describing what was found.
  Future<BarcodeLookup> lookup(String code) async {
    final local = await _itemDao.findByBarcode(code);
    if (local != null) {
      return BarcodeLookup.local(local);
    }
    final online = await _scraper.searchBarcode(code);
    return BarcodeLookup.online(code, online);
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
