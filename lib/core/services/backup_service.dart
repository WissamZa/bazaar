import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart'
    show DoNothing, Insertable, RawValuesInsertable, Table, TableInfo, Variable;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';

/// Snapshot the entire local DB into a .zip the user can share, and
/// restore selectively from such a .zip.
///
/// WIRE FORMAT (compatibility contract): each table dumps to `<table>.json`
/// (a JSON array of raw row maps — same shape as v1). `meta.json` records
/// the encryption flag. Encrypted entries are `<table>.json.enc` with
/// layout `salt(16) || nonce(12) || ciphertext || mac(16)`, AES-256-GCM
/// with PBKDF2-HMAC-SHA256 (100k iterations).
///
/// v2 adds `categories.json` and `item_price_history.json` (v1 backups
/// lacked them); the v1 restore flow's allowlist simply skips unknown
/// entries, so v2 backups remain restorable by v1 apps and vice versa.
class BackupService {
  final AppDatabase db;

  BackupService(this.db);

  static const int maxBackupBytes = 50 * 1024 * 1024; // 50 MB
  static const int maxRowsPerTable = 100000;

  /// Tables included in a full backup, in restore (FK-safe) order.
  static const _kTables = [
    'stores',
    'categories',
    'items',
    'item_store',
    'shopping_lists',
    'list_items',
    'item_price_history',
  ];

  // ── CREATE ─────────────────────────────────────────────────────────────
  //
  // All file IO, JSON encoding, ZIP compression and crypto run in a
  // background isolate — v1 did 50 MB of synchronous IO on the UI isolate
  // and janked. Only the final write lands on disk here.
  Future<File> createBackup({String? passphrase}) async {
    final appDir = await getApplicationDocumentsDirectory();
    final timestamp = _timestamp();

    final tableJson = <String, String>{};
    for (final table in _kTables) {
      final rows = await _dumpTable(table);
      // v1 wire-format filename: the shopping_lists table dumped to
      // `lists.json` (every other table kept its SQL name).
      final entry = table == 'shopping_lists' ? 'lists' : table;
      tableJson['$entry.json'] = rows;
    }

    final meta = {
      'app': 'Bazaar',
      'version': 1,
      'created_at': DateTime.now().toIso8601String(),
      'encrypted': passphrase != null && passphrase.isNotEmpty,
      'encryption_algo': passphrase != null && passphrase.isNotEmpty
          ? 'AES-256-GCM + PBKDF2-HMAC-SHA256 (100k iterations)'
          : null,
    };

    final zipPath = '${appDir.path}/bazaar_backup_$timestamp.zip';
    final useEncryption = passphrase != null && passphrase.isNotEmpty;

    final bytes = await Isolate.run(() async {
      final archive = Archive();
      for (final entry in tableJson.entries) {
        final raw = utf8.encode(entry.value);
        if (useEncryption) {
          final enc = await BackupCrypto.encryptBytes(raw, passphrase);
          archive.addFile(ArchiveFile.bytes('${entry.key}.enc', enc));
        } else {
          archive.addFile(ArchiveFile.bytes(entry.key, raw));
        }
      }
      archive.addFile(
        ArchiveFile.bytes('meta.json', utf8.encode(jsonEncode(meta))),
      );
      return ZipEncoder().encode(archive);
    });

    final zipFile = File(zipPath);
    // Fresh installs may not have the documents dir yet.
    await zipFile.parent.create(recursive: true);
    return zipFile.writeAsBytes(bytes);
  }

  /// Dump a table to pretty-ordered JSON rows. Raw `db.select` on table
  /// names keeps the dump format exactly equal to v1's `db.query(table)`.
  Future<String> _dumpTable(String table) async {
    final rows = await db.customSelect('SELECT * FROM $table').get();
    return jsonEncode(rows.map((r) => r.data).toList());
  }

  // ── READ ───────────────────────────────────────────────────────────────
  //
  // SECURITY: entry allowlist (skips `__MACOSX` etc.), per-entry UTF-8/JSON
  // decode with try/catch, 50 MB ZIP cap, 100k rows/table cap, and AES
  // decryption when meta.json says the backup is encrypted. The whole
  // decode runs in an isolate.
  Future<BackupContents> readBackup(File zipFile, {String? passphrase}) async {
    final fileBytes = await zipFile.readAsBytes();
    if (fileBytes.length > maxBackupBytes) {
      throw StateError(
        'Backup file is too large (${fileBytes.length} bytes). Maximum is '
        '${maxBackupBytes ~/ (1024 * 1024)} MB.',
      );
    }

    final contents = await Isolate.run(
      () => _decodeBackupBytes(fileBytes, passphrase: passphrase),
    );
    if (contents.meta == null && contents.items == null) {
      throw StateError(
          'Not a Bazaar backup file (no meta.json or items.json found).');
    }
    return contents;
  }

  static Future<BackupContents> _decodeBackupBytes(
    Uint8List fileBytes, {
    String? passphrase,
  }) async {
    final archive = ZipDecoder().decodeBytes(fileBytes);

    // First pass: meta.json → is it encrypted?
    var encrypted = false;
    for (final file in archive) {
      if (file.name == 'meta.json') {
        try {
          final meta =
              jsonDecode(
                    utf8.decode(
                      file.content as List<int>,
                      allowMalformed: false,
                    ),
                  )
                  as Map<String, dynamic>;
          encrypted = meta['encrypted'] == true;
        } catch (_) {
          // Old backups may have no/broken meta — treat as unencrypted.
        }
        break;
      }
    }
    if (encrypted && (passphrase == null || passphrase.isEmpty)) {
      throw StateError(
        'This backup is encrypted. Please enter the passphrase you used '
        'when creating it.',
      );
    }

    final contents = BackupContents();
    for (final file in archive) {
      final name = file.name;
      final baseName = name.replaceAll('.enc', '');
      final isMeta = name == 'meta.json';
      final isExpected = _kExpectedBases.contains(baseName);
      if (!isMeta && !isExpected) continue;

      final rawBytes = file.content as List<int>;
      List<int> jsonBytes;
      if (name.endsWith('.enc')) {
        if (passphrase == null || passphrase.isEmpty) {
          throw StateError(
            'Encrypted entry $name encountered but no passphrase was provided.',
          );
        }
        try {
          jsonBytes = await BackupCrypto.decryptBytes(rawBytes, passphrase);
        } catch (e) {
          throw StateError(
            'Decryption failed for $name (wrong passphrase?): $e',
          );
        }
      } else {
        jsonBytes = rawBytes;
      }
      final String decoded;
      try {
        decoded = utf8.decode(jsonBytes, allowMalformed: false);
      } catch (e) {
        throw StateError('Entry $name is not valid UTF-8: $e');
      }

      try {
        if (isMeta) {
          contents.meta = jsonDecode(decoded) as Map<String, dynamic>;
          continue;
        }
        final list = _decodeList(decoded, name);
        switch (baseName) {
          case 'items.json':
            contents.items = list;
          case 'stores.json':
            contents.stores = list;
          case 'categories.json':
            contents.categories = list;
          case 'lists.json':
            contents.lists = list;
          case 'list_items.json':
            contents.listItems = list;
          case 'item_store.json':
            contents.itemStores = list;
          case 'item_price_history.json':
            contents.priceHistory = list;
        }
      } catch (e) {
        throw StateError('Entry $name could not be parsed: $e');
      }
    }
    return contents;
  }

  static const _kExpectedBases = {
    'items.json',
    'stores.json',
    'categories.json',
    'lists.json',
    'list_items.json',
    'item_store.json',
    'item_price_history.json',
  };

  static List<dynamic> _decodeList(String json, String entryName) {
    final decoded = jsonDecode(json);
    if (decoded is! List) {
      throw StateError('$entryName is not a JSON array');
    }
    if (decoded.length > maxRowsPerTable) {
      throw StateError(
        '$entryName has ${decoded.length} rows, exceeds the '
        '$maxRowsPerTable row limit',
      );
    }
    return decoded;
  }

  /// Picks a .zip via the system file picker and reads it, prompting for a
  /// passphrase when the backup is encrypted. Returns null when cancelled.
  Future<BackupContents?> pickAndRead({
    Future<String?> Function()? passphrasePrompt,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.single.path == null) return null;
    final file = File(result.single.path!);

    // Quick sniff: read meta.json to detect encryption before prompting.
    var encrypted = false;
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final entry in archive) {
        if (entry.name == 'meta.json') {
          final meta =
              jsonDecode(
                    utf8.decode(
                      entry.content as List<int>,
                      allowMalformed: false,
                    ),
                  )
                  as Map<String, dynamic>;
          encrypted = meta['encrypted'] == true;
          break;
        }
      }
    } catch (_) {
      // ignore — readBackup surfaces the real error
    }

    String? passphrase;
    if (encrypted) {
      if (passphrasePrompt == null) {
        throw StateError(
          'This backup is encrypted but no passphrase prompt was provided.',
        );
      }
      passphrase = await passphrasePrompt();
      if (passphrase == null || passphrase.isEmpty) return null;
    }
    return readBackup(file, passphrase: passphrase);
  }

  // ── RESTORE ────────────────────────────────────────────────────────────
  //
  // SECURITY (v1 Finding 3): per-row try/catch — a single malformed row
  // never aborts the restore; skipped rows are counted in the summary.
  // Everything runs inside one transaction: either the restore lands whole
  // or nothing is half-written.
  Future<RestoreSummary> restoreSelective(
    BackupContents contents, {
    bool restoreItems = true,
    bool restoreStores = true,
    bool restoreLists = true,
  }) async {
    var items = 0, stores = 0, lists = 0, skipped = 0;

    await db.transaction(() async {
      // Original row ids are PRESERVED (not re-numbered): list_items,
      // item_store and price history reference items/stores by id, so an
      // exact-id restore keeps every FK intact. On id collisions with
      // existing local rows the insert is skipped (DoNothing) and counted.
      if (restoreStores && contents.stores != null) {
        for (final raw in contents.stores!) {
          try {
            if (raw is! Map<String, dynamic>) {
              skipped++;
              continue;
            }
            await db.into(db.stores).insert(
                  _rawRowToInsertable(raw, keepDates: 'created_at'),
                  onConflict: DoNothing(),
                );
            stores++;
          } catch (_) {
            skipped++;
          }
        }
      }

      if (restoreItems && contents.categories != null) {
        for (final raw in contents.categories!) {
          try {
            if (raw is! Map<String, dynamic>) {
              skipped++;
              continue;
            }
            await db.into(db.categories).insert(
                  _rawRowToInsertable(raw, keepDates: 'created_at'),
                  onConflict: DoNothing(),
                );
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
            await db.into(db.items).insert(
                  _rawRowToInsertable(raw,
                      keepDates: 'created_at,updated_at'),
                  onConflict: DoNothing(),
                );
            items++;
          } catch (_) {
            skipped++;
          }
        }
      }

      if (restoreItems && contents.itemStores != null) {
        for (final raw in contents.itemStores!) {
          try {
            if (raw is! Map<String, dynamic>) {
              skipped++;
              continue;
            }
            await db.into(db.itemStores).insert(
                  _rawRowToInsertable(raw, keepDates: ''),
                  onConflict: DoNothing(),
                );
          } catch (_) {
            skipped++;
          }
        }
      }

      if (restoreLists && contents.lists != null) {
        final oldToNewListId = <int, int>{};
        for (final raw in contents.lists!) {
          try {
            if (raw is! Map<String, dynamic>) {
              skipped++;
              continue;
            }
            final oldId = (raw['id'] as num?)?.toInt();
            final newId = await db.into(db.shoppingLists).insert(
                  _rawRowToInsertable(raw,
                      keepDates: 'created_at,updated_at'),
                  onConflict: DoNothing(),
                );
            if (oldId != null) oldToNewListId[oldId] = newId;
            lists++;
          } catch (_) {
            skipped++;
          }
        }
        // Re-attach list_items by old list id (identity when ids were
        // preserved, remapped when a collision forced a new id).
        if (contents.listItems != null) {
          for (final liRaw in contents.listItems!) {
            try {
              if (liRaw is! Map<String, dynamic>) {
                skipped++;
                continue;
              }
              final oldListId =
                  ((liRaw['list_id'] ?? liRaw['listId']) as num?)?.toInt();
              final mapped = oldToNewListId[oldListId];
              if (mapped == null) {
                skipped++;
                continue;
              }
              final row = Map<String, Object?>.from(liRaw);
              row['list_id'] = mapped;
              await db.into(db.listItems).insert(
                    _rawRowToInsertable(row, keepDates: ''),
                    onConflict: DoNothing(),
                  );
            } catch (_) {
              skipped++;
            }
          }
        }
      }

      if (restoreItems && contents.priceHistory != null) {
        for (final raw in contents.priceHistory!) {
          try {
            if (raw is! Map<String, dynamic>) {
              skipped++;
              continue;
            }
            await db.into(db.itemPriceHistory).insert(
                  _rawRowToInsertable(raw, keepDates: 'recorded_at'),
                  onConflict: DoNothing(),
                );
          } catch (_) {
            skipped++;
          }
        }
      }
    });

    return RestoreSummary(
      items: items,
      stores: stores,
      lists: lists,
      skipped: skipped,
    );
  }

  /// Turn a raw JSON row map (legacy schema column names) into a drift
  /// insertable. NOT NULL date columns always get a value so old partial
  /// backups still restore.
  Insertable<D> _rawRowToInsertable<D>(
    Map<String, Object?> raw, {
    required String keepDates,
  }) {
    final keep = keepDates.split(',').where((e) => e.isNotEmpty).toSet();
    final map = <String, Object?>{};
    for (final entry in raw.entries) {
      if (entry.value == null && !keep.contains(entry.key)) continue;
      map[entry.key] = entry.value;
    }
    for (final col in keep) {
      map[col] ??= DateTime.now().toIso8601String();
    }
    return RawValuesInsertable({
      for (final entry in map.entries)
        entry.key: Variable(entry.value),
    });
  }

  /// Turn a raw JSON row map into a drift insert companion, dropping the
  /// `id` column (free re-numbering) and any columns not in [keepDates].
  /// Column names come from the legacy schema, which the row maps use.
  Insertable<D> _rowMapToCompanion<Tbl extends Table, D>(
    TableInfo<Tbl, D> table,
    Map<String, Object?> raw,
    String keepDates,
  ) {
    final map = <String, Object?>{};
    final keep = keepDates.split(',').where((e) => e.isNotEmpty).toSet();
    for (final entry in raw.entries) {
      if (entry.key == 'id') continue;
      final isDate = keep.contains(entry.key);
      if (!isDate && entry.value == null) continue;
      map[entry.key] = entry.value;
    }
    // Ensure NOT NULL date columns always get a value.
    for (final col in keep) {
      map[col] ??= DateTime.now().toIso8601String();
    }
    return RawValuesInsertable({
      for (final entry in map.entries) entry.key: Variable(entry.value),
    });
  }

  String _timestamp() =>
      DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
}

/// The decrypted+decoded contents of a backup ZIP.
class BackupContents {
  List<dynamic>? items;
  List<dynamic>? stores;
  List<dynamic>? categories;
  List<dynamic>? lists;
  List<dynamic>? listItems;
  List<dynamic>? itemStores;
  List<dynamic>? priceHistory;
  Map<String, dynamic>? meta;

  int get itemsCount => items?.length ?? 0;
  int get storesCount => stores?.length ?? 0;
  int get listsCount => lists?.length ?? 0;
  int get categoriesCount => categories?.length ?? 0;
  int get priceHistoryCount => priceHistory?.length ?? 0;
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

/// AES-256-GCM backup encryption with PBKDF2-HMAC-SHA256 (100k iterations).
///
/// Layout: `salt(16) || nonce(12) || ciphertext || mac(16)` — identical to
/// v1 so old encrypted backups restore into v2 and vice versa.
abstract final class BackupCrypto {
  static Future<Uint8List> encryptBytes(
    List<int> plaintext,
    String passphrase,
  ) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    final algorithm = AesGcm.with256bits();
    final secretBox = await algorithm.encrypt(plaintext, secretKey: secretKey);
    final out = BytesBuilder();
    out.add(salt);
    out.add(secretBox.nonce);
    out.add(secretBox.cipherText);
    out.add(secretBox.mac.bytes);
    return out.toBytes();
  }

  static Future<Uint8List> decryptBytes(
    List<int> encrypted,
    String passphrase,
  ) async {
    if (encrypted.length < 16 + 12 + 16) {
      throw StateError(
        'Encrypted payload is too short (${encrypted.length} bytes)',
      );
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
    final plaintext = await algorithm.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
      secretKey: secretKey,
    );
    return Uint8List.fromList(plaintext);
  }
}
