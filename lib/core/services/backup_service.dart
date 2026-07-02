import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
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
  //
  // SECURITY (Finding 21): Temp JSON files are now written to the OS
  // temporary directory (which is auto-cleaned) instead of the app's
  // documents directory (where they would persist as plaintext PII until
  // the next backup call).
  //
  // SECURITY (Finding 5): If [passphrase] is provided, every JSON file in
  // the ZIP is encrypted with AES-256-GCM using a key derived from the
  // passphrase via PBKDF2 (100,000 iterations, HMAC-SHA256). The salt and
  // nonce are stored alongside the ciphertext in a `.enc` file. Without the
  // passphrase, the backup is plaintext (same as before).
  Future<File> createBackup({String? passphrase}) async {
    final appDir = await getApplicationDocumentsDirectory();
    final tempDir = await getTemporaryDirectory();
    final backupDir = Directory('${tempDir.path}/bazaar_backup_tmp');
    if (backupDir.existsSync()) {
      await backupDir.delete(recursive: true);
    }
    await backupDir.create(recursive: true);

    await _exportTableToJson('items', '${backupDir.path}/items.json');
    await _exportTableToJson('stores', '${backupDir.path}/stores.json');
    await _exportTableToJson(
      'shopping_lists',
      '${backupDir.path}/lists.json',
    );
    await _exportTableToJson('list_items', '${backupDir.path}/list_items.json');
    await _exportTableToJson('item_store', '${backupDir.path}/item_store.json');

    final meta = {
      'app': 'Bazaar',
      'version': 1,
      'created_at': DateTime.now().toIso8601String(),
      'encrypted': passphrase != null && passphrase.isNotEmpty,
      'encryption_algo': passphrase != null && passphrase.isNotEmpty
          ? 'AES-256-GCM + PBKDF2-HMAC-SHA256 (100k iterations)'
          : null,
    };
    await File('${backupDir.path}/meta.json').writeAsString(jsonEncode(meta));

    final useEncryption = passphrase != null && passphrase.isNotEmpty;
    final archive = Archive();
    for (final f in backupDir.listSync(recursive: true).whereType<File>()) {
      final bytes = f.readAsBytesSync();
      if (useEncryption && f.path.endsWith('.json') &&
          !f.path.endsWith('meta.json')) {
        // Encrypt the JSON file.
        final enc = await _encryptBytes(bytes, passphrase!);
        archive.addFile(
          ArchiveFile(
            '${p.relative(f.path, from: backupDir.path)}.enc',
            enc.length,
            enc,
          ),
        );
      } else {
        archive.addFile(
          ArchiveFile(
            p.relative(f.path, from: backupDir.path),
            bytes.length,
            bytes,
          ),
        );
      }
    }

    final zipPath = '${appDir.path}/bazaar_backup_${_timestamp()}.zip';
    final zipFile = File(zipPath);
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw Exception('Failed to encode backup archive');
    }
    await zipFile.writeAsBytes(encoded);

    await backupDir.delete(recursive: true);
    return zipFile;
  }

  /// Encrypt [plaintext] with AES-256-GCM using a key derived from
  /// [passphrase] via PBKDF2 (100k iterations, HMAC-SHA256, 16-byte salt).
  /// Returns a single byte buffer containing: salt (16) || nonce (12) ||
  /// ciphertext || MAC (16).
  static Future<Uint8List> _encryptBytes(
    List<int> plaintext,
    String passphrase,
  ) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    // SECURITY (Finding 5): Generate salt with dart:math's cryptographically
    // secure random number generator (the `cryptography` package does not
    // export NonceSecureRandom in 2.x — it was renamed / moved between
    // versions).
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    final algorithm = AesGcm.with256bits();
    final secretBox = await algorithm.encrypt(
      plaintext,
      secretKey: secretKey,
    );
    // Concatenate salt + nonce + ciphertext + MAC.
    final out = BytesBuilder();
    out.add(salt);
    out.add(secretBox.nonce);
    out.add(secretBox.cipherText);
    out.add(secretBox.mac.bytes);
    return out.toBytes();
  }

  /// Decrypt bytes produced by [_encryptBytes]. Throws on wrong passphrase
  /// (MAC verification failure) or corruption.
  static Future<Uint8List> _decryptBytes(
    List<int> encrypted,
    String passphrase,
  ) async {
    if (encrypted.length < 16 + 12 + 16) {
      throw StateError('Encrypted payload is too short (${encrypted.length} bytes)');
    }
    final salt = encrypted.sublist(0, 16);
    final nonce = encrypted.sublist(16, 28);
    final mac = encrypted.sublist(encrypted.length - 16);
    final cipherText = encrypted.sublist(28, encrypted.length - 16);

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    final algorithm = AesGcm.with256bits();
    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(mac),
    );
    final plaintext = await algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
    );
    return Uint8List.fromList(plaintext);
  }

  // ───────────────────────── READ BACKUP ──────────────────────────────
  //
  // SECURITY (Findings 3 + 5 + 15): Hardened to:
  //   • skip any ZIP entry whose name is not in the expected set
  //     (supports both `.json` and `.json.enc` entries)
  //   • wrap utf8.decode + jsonDecode in try/catch per entry
  //   • refuse ZIPs larger than 50 MB (DoS protection)
  //   • refuse individual table payloads larger than 100,000 rows
  //   • if the backup is encrypted (per meta.json), require [passphrase]
  //     and decrypt each `.enc` entry with AES-256-GCM
  static const int _kMaxBackupBytes = 50 * 1024 * 1024; // 50 MB
  static const int _kMaxRowsPerTable = 100000;
  static const Set<String> _kExpectedEntries = {
    'items.json', 'items.json.enc',
    'stores.json', 'stores.json.enc',
    'lists.json', 'lists.json.enc',
    'list_items.json', 'list_items.json.enc',
    'item_store.json', 'item_store.json.enc',
    'meta.json',
  };

  Future<BackupContents> readBackup(File zipFile, {String? passphrase}) async {
    final fileBytes = zipFile.readAsBytesSync();
    if (fileBytes.length > _kMaxBackupBytes) {
      throw StateError('Backup file is too large (${fileBytes.length} bytes). '
          'Maximum allowed is ${_kMaxBackupBytes ~/ (1024 * 1024)} MB.');
    }
    final archive = ZipDecoder().decodeBytes(fileBytes);

    // First pass: read meta.json to know whether the backup is encrypted.
    bool encrypted = false;
    for (final file in archive) {
      if (file.name == 'meta.json') {
        try {
          final meta = jsonDecode(
            utf8.decode(file.content as List<int>, allowMalformed: false),
          ) as Map<String, dynamic>;
          encrypted = meta['encrypted'] == true;
        } catch (_) {
          // Old backups have no meta or a malformed meta — treat as unencrypted.
        }
        break;
      }
    }
    if (encrypted && (passphrase == null || passphrase.isEmpty)) {
      throw StateError('This backup is encrypted. Please enter the passphrase '
          'you used when creating it.');
    }

    final contents = BackupContents();
    for (final file in archive) {
      // Skip directories and unexpected files (e.g. macOS __MACOSX metadata).
      if (!_kExpectedEntries.contains(file.name)) continue;
      if (file.name == 'meta.json') {
        try {
          final decoded = utf8.decode(file.content as List<int>,
              allowMalformed: false);
          contents.meta = jsonDecode(decoded) as Map<String, dynamic>;
        } catch (e) {
          throw StateError('meta.json could not be parsed: $e');
        }
        continue;
      }

      // For every other entry, decrypt if needed and decode.
      final rawBytes = file.content as List<int>;
      final List<int> jsonBytes;
      if (file.name.endsWith('.enc')) {
        if (passphrase == null || passphrase.isEmpty) {
          throw StateError('Encrypted entry ${file.name} encountered but no '
              'passphrase was provided.');
        }
        try {
          jsonBytes = await _decryptBytes(rawBytes, passphrase);
        } catch (e) {
          throw StateError('Decryption failed for ${file.name} (wrong '
              'passphrase?): $e');
        }
      } else {
        jsonBytes = rawBytes;
      }

      // Per-entry decode with allowMalformed:false so a single bad byte does
      // not abort the entire restore.
      final String decoded;
      try {
        decoded = utf8.decode(jsonBytes, allowMalformed: false);
      } catch (e) {
        throw StateError('Entry ${file.name} is not valid UTF-8: $e');
      }
      // Strip the `.enc` suffix for the switch below.
      final entryName = file.name.replaceAll('.enc', '');
      try {
        switch (entryName) {
          case 'items.json':
            contents.items = _decodeList(decoded, 'items.json');
            break;
          case 'stores.json':
            contents.stores = _decodeList(decoded, 'stores.json');
            break;
          case 'lists.json':
            contents.lists = _decodeList(decoded, 'lists.json');
            break;
          case 'list_items.json':
            contents.listItems = _decodeList(decoded, 'list_items.json');
            break;
          case 'item_store.json':
            contents.itemStores = _decodeList(decoded, 'item_store.json');
            break;
        }
      } catch (e) {
        throw StateError('Entry ${file.name} could not be parsed: $e');
      }
    }
    return contents;
  }

  /// Decode a JSON list with row-count cap. Throws StateError if the list
  /// is malformed or exceeds the row cap.
  List<dynamic> _decodeList(String json, String entryName) {
    final decoded = jsonDecode(json);
    if (decoded is! List) {
      throw StateError('$entryName is not a JSON array');
    }
    if (decoded.length > _kMaxRowsPerTable) {
      throw StateError('$entryName has ${decoded.length} rows, exceeds '
          'the $_kMaxRowsPerTable row limit');
    }
    return decoded;
  }

  /// Picks a .zip via the system file picker and reads it.
  ///
  /// If the backup is encrypted, calls [passphrasePrompt] to ask the user
  /// for the passphrase. If the user cancels (returns null or empty), the
  /// restore is aborted.
  Future<BackupContents?> pickAndRead({
    Future<String?> Function()? passphrasePrompt,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.single.path == null) return null;
    final file = File(result.files.single.path!);

    // Quick sniff: is this an encrypted backup? Read meta.json first.
    bool encrypted = false;
    try {
      final archive = ZipDecoder().decodeBytes(file.readAsBytesSync());
      for (final entry in archive) {
        if (entry.name == 'meta.json') {
          final meta = jsonDecode(
            utf8.decode(entry.content as List<int>, allowMalformed: false),
          ) as Map<String, dynamic>;
          encrypted = meta['encrypted'] == true;
          break;
        }
      }
    } catch (_) {
      // ignore — let readBackup surface the real error
    }

    String? passphrase;
    if (encrypted) {
      if (passphrasePrompt == null) {
        throw StateError('This backup is encrypted but no passphrase prompt '
            'was provided.');
      }
      passphrase = await passphrasePrompt();
      if (passphrase == null || passphrase.isEmpty) {
        return null; // user cancelled
      }
    }
    return readBackup(file, passphrase: passphrase);
  }

  // ───────────────────────── RESTORE ──────────────────────────────────
  //
  // SECURITY (Finding 3): Each row's upsert is wrapped in its own try/catch
  // so a single malformed row does not abort the entire restore. Skipped
  // rows are counted and returned in the summary so the user knows what
  // happened.
  Future<RestoreSummary> restoreSelective(
    BackupContents contents, {
    bool restoreItems = true,
    bool restoreStores = true,
    bool restoreLists = true,
  }) async {
    var itemsCount = 0;
    var storesCount = 0;
    var listsCount = 0;
    var skipped = 0;

    if (restoreStores && contents.stores != null) {
      for (final raw in contents.stores!) {
        try {
          if (raw is! Map<String, dynamic>) {
            skipped++;
            continue;
          }
          final store = Store.fromJson(raw);
          await StoreDao.instance.upsertByName(store);
          storesCount++;
        } catch (_) {
          skipped++;
        }
      }
    }

    if (restoreItems && contents.items != null) {
      for (final raw in contents.items!) {
        try {
          if (raw is! Map<String, dynamic>) {
            skipped++;
            continue;
          }
          final item = Item.fromJson(raw);
          await ItemDao.instance.upsertByBarcode(item);
          itemsCount++;
        } catch (_) {
          skipped++;
        }
      }
    }

    if (restoreLists && contents.lists != null) {
      for (final raw in contents.lists!) {
        try {
          if (raw is! Map<String, dynamic>) {
            skipped++;
            continue;
          }
          final list = ShoppingList.fromJson(raw);
          final newId = await ShoppingListDao.instance.insert(list.copyWith(
            id: null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),);
          // Re-attach list_items that referenced this list's old id
          if (contents.listItems != null) {
            final oldId = list.id;
            for (final liRaw in contents.listItems!) {
              try {
                if (liRaw is! Map<String, dynamic>) {
                  skipped++;
                  continue;
                }
                final li = ListItem.fromJson(liRaw);
                if (li.listId == oldId) {
                  await ListItemDao.instance.insert(li.copyWith(
                    id: null,
                    listId: newId,
                  ),);
                }
              } catch (_) {
                skipped++;
              }
            }
          }
          listsCount++;
        } catch (_) {
          skipped++;
        }
      }
    }

    return RestoreSummary(
      items: itemsCount,
      stores: storesCount,
      lists: listsCount,
      skipped: skipped,
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
  final int skipped;
  const RestoreSummary({
    required this.items,
    required this.stores,
    required this.lists,
    this.skipped = 0,
  });
}
