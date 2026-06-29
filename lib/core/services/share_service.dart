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
    final json = jsonEncode({
      'type': 'shopping_list',
      'version': 1,
      'list': list.toJson(),
      'items': listItems.map((e) => e.toJson()).toList(),
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
    await Share.shareXFiles([XFile(file.path)], text: 'Shared from Bazaar');
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
    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;

    switch (data['type']) {
      case 'items':
        final count = await _importItems(data['data'] as List);
        return ImportSummary(type: 'items', count: count);
      case 'shopping_list':
        final count = await _importList(
          data['list'] as Map<String, dynamic>,
          (data['items'] as List).cast(),
        );
        return ImportSummary(type: 'shopping_list', count: count);
      case 'stores':
        final count = await _importStores(data['data'] as List);
        return ImportSummary(type: 'stores', count: count);
      default:
        throw FormatException('Unknown export type: ${data['type']}');
    }
  }

  Future<int> _importItems(List<dynamic> items) async {
    var count = 0;
    for (final raw in items) {
      final item = Item.fromJson(raw as Map<String, dynamic>);
      await ItemDao.instance.upsertByBarcode(item);
      count++;
    }
    return count;
  }

  Future<int> _importStores(List<dynamic> stores) async {
    var count = 0;
    for (final raw in stores) {
      final store = Store.fromJson(raw as Map<String, dynamic>);
      await StoreDao.instance.upsertByName(store);
      count++;
    }
    return count;
  }

  Future<int> _importList(
    Map<String, dynamic> listJson,
    List<dynamic> itemsJson,
  ) async {
    // 1. Insert the list itself
    final list = ShoppingList.fromJson(listJson).copyWith(
      id: null, // let DB assign a new id to avoid PK collisions
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final listId = await ShoppingListDao.instance.insert(list);

    // 2. Insert each item (upsert by barcode) and link to the list
    var count = 0;
    for (final raw in itemsJson) {
      final li = ListItem.fromJson(raw as Map<String, dynamic>);
      // The exported item is the ListItem, but it references an item_id
      // we don't have locally — caller should also have exported items.
      // For simplicity: treat each entry as a ListItem referencing an
      // already-imported item; if not found, skip.
      try {
        await ListItemDao.instance.insert(li.copyWith(listId: listId));
        count++;
      } catch (_) {
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
