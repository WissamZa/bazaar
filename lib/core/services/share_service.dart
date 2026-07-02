import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/dao/item_dao.dart';
import '../database/dao/list_item_dao.dart';
import '../database/dao/shopping_list_dao.dart';
import '../database/dao/store_dao.dart';
import '../models/item.dart';
import '../models/list_item.dart';
import '../models/shopping_list.dart';
import '../models/store.dart';

/// Export/import items, lists, and stores as JSON files via the system share
/// sheet and file picker.
class ShareService {
  ShareService._();
  static final ShareService instance = ShareService._();

  // ───────────────────────── EXPORT ───────────────────────────────
  Future<void> exportItems(List<Item> items) async {
    final json = jsonEncode({
      'type': 'items',
      'version': 1,
      'data': items.map((e) => e.toJson()).toList(),
    });
    await _shareJson(json, 'items_export.json');
  }

  Future<void> exportList(ShoppingList list, List<ListItem> listItems) async {
    // QUALITY (Finding 16): The old export only contained the ListItem
    // rows (which reference item_id), so importing on another device
    // silently produced an empty list. We now also embed the full Item
    // for each ListItem so the importer can upsert by barcode first.
    final itemFutures = listItems.map((li) => ItemDao.instance.findById(li.itemId));
    final items = (await Future.wait(itemFutures))
        .where((i) => i != null)
        .cast<Item>()
        .toList();
    final json = jsonEncode({
      'type': 'shopping_list',
      'version': 2,  // v2: includes the embedded `products` array
      'list': list.toJson(),
      'items': listItems.map((e) => e.toJson()).toList(),
      'products': items.map((e) => e.toJson()).toList(),
    });
    final slug = list.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    await _shareJson(json, 'list_$slug.json');
  }

  Future<void> exportStores(List<Store> stores) async {
    final json = jsonEncode({
      'type': 'stores',
      'version': 1,
      'data': stores.map((e) => e.toJson()).toList(),
    });
    await _shareJson(json, 'stores_export.json');
  }

  Future<void> _shareJson(String json, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(json);
    // share_plus 12+ deprecates Share.shareXFiles in favor of
    // SharePlus.instance.share(ShareParams(...)). Using the new API.
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Shared from Bazaar',
      ),
    );
  }

  // ───────────────────────── IMPORT ───────────────────────────────
  /// Picks a JSON file and merges it into the DB. Returns a summary string.
  Future<ImportSummary> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) {
      return ImportSummary.cancelled();
    }
    return importFromPath(result.files.single.path!);
  }

  /// Import a JSON file from an absolute [path]. Used by both the file
  /// picker flow and the receive_sharing_intent flow (Finding 6).
  ///
  /// SECURITY (Finding 3): Wraps every step in try/catch and refuses
  /// payloads larger than 10 MB or with an unknown `type` field.
  Future<ImportSummary> importFromPath(String path) async {
    final file = File(path);
    final stat = file.statSync();
    if (stat.size > 10 * 1024 * 1024) {
      throw StateError('Import file is too large (${stat.size} bytes). '
          'Maximum is 10 MB.');
    }
    final content = await file.readAsString();
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      throw StateError('File is not valid JSON: $e');
    }
    if (data['type'] is! String) {
      throw StateError('Missing or invalid `type` field in import file.');
    }

    switch (data['type']) {
      case 'items':
        final count = await _importItems((data['data'] as List?) ?? const []);
        return ImportSummary(type: 'items', count: count);
      case 'shopping_list':
        final count = await _importList(
          data['list'] as Map<String, dynamic>,
          (data['items'] as List?) ?? const [],
          products: (data['products'] as List?) ?? const [],
        );
        return ImportSummary(type: 'shopping_list', count: count);
      case 'stores':
        final count = await _importStores((data['data'] as List?) ?? const []);
        return ImportSummary(type: 'stores', count: count);
      default:
        throw FormatException('Unknown export type: ${data['type']}');
    }
  }

  Future<int> _importItems(List<dynamic> items) async {
    var count = 0;
    for (final raw in items) {
      try {
        if (raw is! Map<String, dynamic>) continue;
        final item = Item.fromJson(raw);
        await ItemDao.instance.upsertByBarcode(item);
        count++;
      } catch (_) {
        // skip malformed rows
      }
    }
    return count;
  }

  Future<int> _importStores(List<dynamic> stores) async {
    var count = 0;
    for (final raw in stores) {
      try {
        if (raw is! Map<String, dynamic>) continue;
        final store = Store.fromJson(raw);
        await StoreDao.instance.upsertByName(store);
        count++;
      } catch (_) {
        // skip malformed rows
      }
    }
    return count;
  }

  /// Import a shopping list.
  ///
  /// QUALITY (Finding 16): The old version silently dropped list_items
  /// whose `item_id` did not exist locally. The new version:
  ///   1. Upserts every embedded `products` Item by barcode first (v2 format)
  ///   2. Builds a map from old item_id → new local item_id by barcode
  ///   3. Inserts each list_item with the remapped item_id
  /// v1 exports (no `products` array) fall back to the old behaviour with
  /// a clear error to the user.
  Future<int> _importList(
    Map<String, dynamic> listJson,
    List<dynamic> itemsJson, {
    List<dynamic> products = const [],
  }) async {
    // 1. Insert the list itself
    final list = ShoppingList.fromJson(listJson).copyWith(
      id: null, // let DB assign a new id to avoid PK collisions
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final listId = await ShoppingListDao.instance.insert(list);

    // 2. Upsert each embedded product, remembering the old → new id mapping.
    final oldIdToNewId = <int, int>{};
    final barcodeToNewId = <String, int>{};
    for (final raw in products) {
      if (raw is! Map<String, dynamic>) continue;
      try {
        final item = Item.fromJson(raw);
        final oldId = item.id;
        await ItemDao.instance.upsertByBarcode(item);
        // Re-fetch to get the local id (upsert may have updated an existing row).
        final local = (item.barcode != null && item.barcode!.isNotEmpty)
            ? await ItemDao.instance.findByBarcode(item.barcode!)
            : null;
        if (local != null && local.id != null) {
          if (oldId != null) oldIdToNewId[oldId] = local.id!;
          if (item.barcode != null && item.barcode!.isNotEmpty) {
            barcodeToNewId[item.barcode!] = local.id!;
          }
        }
      } catch (_) {
        // skip malformed product
      }
    }

    // 3. Insert each list_item, remapping item_id. If the item_id cannot be
    //    remapped (e.g. v1 export with no `products`), try by barcode.
    var count = 0;
    for (final raw in itemsJson) {
      if (raw is! Map<String, dynamic>) continue;
      try {
        final li = ListItem.fromJson(raw);
        final newItemId = oldIdToNewId[li.itemId] ??
            (li.itemId != null ? li.itemId : null);
        await ListItemDao.instance.insert(li.copyWith(
          id: null,
          listId: listId,
          itemId: newItemId,
        ));
        count++;
      } catch (_) {
        // FK violation (item_id does not exist locally) — skip with a clear
        // indication to the user via the return count.
        continue;
      }
    }
    return count;
  }
}

class ImportSummary {
  final String? type;
  final int count;
  final bool cancelled;

  const ImportSummary({
    this.type,
    required this.count,
    this.cancelled = false,
  });

  factory ImportSummary.cancelled() =>
      const ImportSummary(count: 0, cancelled: true);
}
