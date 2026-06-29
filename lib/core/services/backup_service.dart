import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';
import '../database/dao/item_dao.dart';
import '../database/dao/list_item_dao.dart';
import '../database/dao/shopping_list_dao.dart';
import '../database/dao/store_dao.dart';
import '../models/item.dart';
import '../models/list_item.dart';
import '../models/shopping_list.dart';
import '../models/store.dart';

/// Snapshot the entire local DB into a .zip file the user can share, and
/// restore selectively from such a .zip.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  // ───────────────────────── CREATE BACKUP ────────────────────────────
  Future<File> createBackup() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/backup_tmp');
    if (backupDir.existsSync()) {
      await backupDir.delete(recursive: true);
    }
    await backupDir.create(recursive: true);

    await _exportTableToJson('items', '${backupDir.path}/items.json');
    await _exportTableToJson('stores', '${backupDir.path}/stores.json');
    await _exportTableToJson(
        'shopping_lists', '${backupDir.path}/lists.json');
    await _exportTableToJson('list_items', '${backupDir.path}/list_items.json');
    await _exportTableToJson('item_store', '${backupDir.path}/item_store.json');

    final meta = {
      'app': 'Bazaar',
      'version': 1,
      'created_at': DateTime.now().toIso8601String(),
    };
    await File('${backupDir.path}/meta.json')
        .writeAsString(jsonEncode(meta));

    final archive = Archive();
    for (final f in backupDir.listSync(recursive: true).whereType<File>()) {
      final bytes = f.readAsBytesSync();
      archive.addFile(
        ArchiveFile(
          p.relative(f.path, from: backupDir.path),
          bytes.length,
          bytes,
        ),
      );
    }

    final zipPath =
        '${appDir.path}/bazaar_backup_${_timestamp()}.zip';
    final zipFile = File(zipPath);
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw Exception('Failed to encode backup archive');
    }
    await zipFile.writeAsBytes(encoded);

    await backupDir.delete(recursive: true);
    return zipFile;
  }

  // ───────────────────────── READ BACKUP ──────────────────────────────
  Future<BackupContents> readBackup(File zipFile) async {
    final bytes = zipFile.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    final contents = BackupContents();
    for (final file in archive) {
      final data = file.content as List<int>;
      final decoded = utf8.decode(data);
      switch (file.name) {
        case 'items.json':
          contents.items = jsonDecode(decoded) as List<dynamic>;
          break;
        case 'stores.json':
          contents.stores = jsonDecode(decoded) as List<dynamic>;
          break;
        case 'lists.json':
          contents.lists = jsonDecode(decoded) as List<dynamic>;
          break;
        case 'list_items.json':
          contents.listItems = jsonDecode(decoded) as List<dynamic>;
          break;
        case 'item_store.json':
          contents.itemStores = jsonDecode(decoded) as List<dynamic>;
          break;
        case 'meta.json':
          contents.meta = jsonDecode(decoded) as Map<String, dynamic>;
          break;
      }
    }
    return contents;
  }

  /// Picks a .zip via the system file picker and reads it.
  Future<BackupContents?> pickAndRead() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.single.path == null) return null;
    return readBackup(File(result.files.single.path!));
  }

  // ───────────────────────── RESTORE ──────────────────────────────────
  Future<RestoreSummary> restoreSelective(
    BackupContents contents, {
    bool restoreItems = true,
    bool restoreStores = true,
    bool restoreLists = true,
  }) async {
    var itemsCount = 0;
    var storesCount = 0;
    var listsCount = 0;

    if (restoreStores && contents.stores != null) {
      for (final raw in contents.stores!) {
        final store = Store.fromJson(raw as Map<String, dynamic>);
        await StoreDao.instance.upsertByName(store);
        storesCount++;
      }
    }

    if (restoreItems && contents.items != null) {
      for (final raw in contents.items!) {
        final item = Item.fromJson(raw as Map<String, dynamic>);
        await ItemDao.instance.upsertByBarcode(item);
        itemsCount++;
      }
    }

    if (restoreLists && contents.lists != null) {
      for (final raw in contents.lists!) {
        final list = ShoppingList.fromJson(raw as Map<String, dynamic>);
        final newId = await ShoppingListDao.instance.insert(list.copyWith(
          id: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
        // Re-attach list_items that referenced this list's old id
        if (contents.listItems != null) {
          final oldId = list.id;
          for (final liRaw in contents.listItems!) {
            final li = ListItem.fromJson(liRaw as Map<String, dynamic>);
            if (li.listId == oldId) {
              try {
                await ListItemDao.instance.insert(li.copyWith(
                  id: null,
                  listId: newId,
                ));
              } catch (_) {
                // skip duplicates
              }
            }
          }
        }
        listsCount++;
      }
    }

    return RestoreSummary(
      items: itemsCount,
      stores: storesCount,
      lists: listsCount,
    );
  }

  // ───────────────────────── helpers ──────────────────────────────────
  Future<void> _exportTableToJson(String table, String path) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(table);
    await File(path).writeAsString(jsonEncode(rows));
  }

  String _timestamp() =>
      DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
}

class BackupContents {
  List<dynamic>? items;
  List<dynamic>? stores;
  List<dynamic>? lists;
  List<dynamic>? listItems;
  List<dynamic>? itemStores;
  Map<String, dynamic>? meta;

  int get itemsCount => items?.length ?? 0;
  int get storesCount => stores?.length ?? 0;
  int get listsCount => lists?.length ?? 0;
}

class RestoreSummary {
  final int items;
  final int stores;
  final int lists;
  const RestoreSummary({
    required this.items,
    required this.stores,
    required this.lists,
  });
}
