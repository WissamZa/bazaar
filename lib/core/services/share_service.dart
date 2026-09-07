import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/app_database.dart';
import '../models/models.dart';

/// Export/import items, lists, and stores as JSON files via the system
/// share sheet and file picker.
///
/// WIRE FORMAT (compatibility contract with v1.x):
///   • `items` / `stores` exports: {type, version: 1, data: [...]}
///   • list export v2: {type: shopping_list, version: 2, list, items,
///     products} — `products` embeds full Item rows so cross-device import
///     works via barcode-based id remapping.
class ShareService {
  final AppDatabase db;

  ShareService(this.db);

  // ── EXPORT ─────────────────────────────────────────────────────────────
  Future<void> exportItems(List<Item> items) async {
    final json = jsonEncode({
      'type': 'items',
      'version': 1,
      'data': items.map((e) => e.toJson()).toList(),
    });
    await _shareJson(json, 'items_export.json');
  }

  Future<void> exportList(ShoppingList list) async {
    final rows = await (db.select(
      db.listItems,
    )..where((t) => t.listId.equals(list.id!))).get();
    final items = <Item>[];
    for (final r in rows) {
      final item = await db.itemDao.findById(r.itemId);
      if (item != null) items.add(Item.fromRow(item));
    }
    final json = jsonEncode({
      'type': 'shopping_list',
      'version': 2,
      'list': list.toJson(),
      'items': rows.map((r) => ListItem.fromRow(r).toJson()).toList(),
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
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Shared from Bazaar'),
    );
  }

  // ── IMPORT ─────────────────────────────────────────────────────────────
  /// Picks a JSON file and merges it into the DB.
  Future<ImportSummary> importFromFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.single.path == null) {
      return const ImportSummary.cancelled();
    }
    return importFromPath(result.single.path!);
  }

  /// Import a JSON file from an absolute [path] (file picker or the
  /// receive-shared-intent flow).
  ///
  /// SECURITY: refuses payloads > 10 MB and unknown `type` fields; every
  /// row upsert is individually guarded so one malformed row cannot abort
  /// the whole import. Parsing runs in a background isolate to keep the UI
  /// responsive.
  Future<ImportSummary> importFromPath(String path) async {
    final file = File(path);
    final size = await file.length();
    if (size > 10 * 1024 * 1024) {
      throw StateError('Import file is too large ($size bytes). Max is 10 MB.');
    }
    final content = await file.readAsString();

    final Map<String, dynamic> data;
    try {
      data = await Isolate.run(
        () => jsonDecode(content) as Map<String, dynamic>,
      );
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
        await db.itemDao.upsertByBarcode(
          Item.fromJson(raw).toInsertCompanion(),
        );
        count++;
      } catch (_) {}
    }
    return count;
  }

  Future<int> _importStores(List<dynamic> stores) async {
    var count = 0;
    for (final raw in stores) {
      try {
        if (raw is! Map<String, dynamic>) continue;
        await db.storeDao.upsertByName(Store.fromJson(raw).toInsertCompanion());
        count++;
      } catch (_) {}
    }
    return count;
  }

  /// Import a shopping list: upsert every embedded product by barcode,
  /// build old→new id maps, then insert list_items with remapped ids.
  /// v1 exports (no `products`) still import; rows whose item cannot be
  /// resolved are skipped.
  Future<int> _importList(
    Map<String, dynamic> listJson,
    List<dynamic> itemsJson, {
    List<dynamic> products = const [],
  }) async {
    final now = DateTime.now();
    final listId = await db.shoppingListDao.insertList(
      ShoppingList.fromJson(
        listJson,
      ).copyWith(id: null, createdAt: now, updatedAt: now).toInsertCompanion(),
    );

    final oldIdToNewId = <int, int>{};
    for (final raw in products) {
      if (raw is! Map<String, dynamic>) continue;
      try {
        final item = Item.fromJson(raw);
        final newId = await db.itemDao.upsertByBarcode(
          item.toInsertCompanion(),
        );
        final oldId = item.id;
        if (oldId != null) oldIdToNewId[oldId] = newId;
      } catch (_) {}
    }

    var count = 0;
    for (final raw in itemsJson) {
      if (raw is! Map<String, dynamic>) continue;
      try {
        final li = ListItem.fromJson(raw);
        // Resolve the local item id: direct remap → barcode lookup → skip.
        int? newItemId = oldIdToNewId[li.itemId];
        if (newItemId == null) {
          final candidate = await db.itemDao.findById(li.itemId);
          newItemId = candidate?.id;
        }
        if (newItemId == null) continue;
        await db.listItemDao.insertRaw(
          li
              .copyWith(id: null, listId: listId, itemId: newItemId)
              .toInsertCompanion(),
        );
        count++;
      } catch (_) {
        continue;
      }
    }
    await db.shoppingListDao.touch(listId);
    return count;
  }
}

class ImportSummary {
  final String? type;
  final int count;
  final bool cancelled;

  const ImportSummary({this.type, required this.count, this.cancelled = false});

  const ImportSummary.cancelled() : type = null, count = 0, cancelled = true;
}
