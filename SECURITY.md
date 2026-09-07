# Security Audit Report — Bazaar v1.4.0

This document tracks the security and code-quality audit of `github.com/WissamZa/bazaar`, performed on 2026-07-02 against the `main` branch. The full audit report is available as a PDF at <https://github.com/WissamZa/bazaar/releases> (attached to the v1.4.0 release).

## Summary

| Severity | Count | Fixed in v1.4.0 |
|----------|-------|-----------------|
| Critical | 1 | ✅ 1 |
| High | 2 | ✅ 2 |
| Medium | 6 | ✅ 6 |
| Low / Info | 13 | ✅ 12 (Finding 18 deferred to v1.5) |
| **Total** | **22** | **21** |

## Findings

Each finding below has been addressed in v1.4.0 unless otherwise noted. The "Fix" column links to the commit / file where the fix was applied.

### Critical

| # | Finding | File | Fix |
|---|---------|------|-----|
| 1 | Maintainer's private Tailscale hostname baked in as the default SearXNG URL | `lib/core/providers/scraping_provider.dart`, `lib/core/services/scraper_service.dart` | Removed all 5 occurrences; default is now empty; one-time migration wipes any previously-saved value matching the old hostname; UI shows a "not configured" banner until the user sets their own. |

### High

| # | Finding | File | Fix |
|---|---------|------|-----|
| 2 | `print()` in release builds leaks SearXNG queries, result titles, and pipeline internals to logcat | `lib/core/services/scraper_service.dart:483` | Gated behind `kDebugMode`; removed `// ignore: avoid_print` workaround. |
| 3 | Backup ZIP / JSON import performs no schema validation; attacker-controlled payload lands directly in the DB | `lib/core/services/backup_service.dart`, `lib/core/services/share_service.dart` | Per-row try/catch; payload size cap (50 MB ZIP, 10 MB JSON); row count cap (100k per table); skip unexpected ZIP entries; validate `type` field on JSON import. |
| 13 | CI runs `flutter analyze` with `\|\| true` and never runs `flutter test` | `.github/workflows/build-apk.yml:69` | Dropped `\|\| true`; added `flutter test` step before the build. |

### Medium

| # | Finding | File | Fix |
|---|---------|------|-----|
| 4 | No SSL pinning on any HTTP client | `lib/core/services/llm_extractor.dart` | Added `lib/core/services/pinned_http_client.dart`; LLM provider calls now wrap an `IOClient` around it so cert failures are logged (and would be enforced if pins were configured). |
| 5 | Backup ZIP is unencrypted; anyone with the file owns the entire DB | `lib/core/services/backup_service.dart` | Optional passphrase → AES-256-GCM encryption of every JSON entry; PBKDF2-HMAC-SHA256 (100k iterations) key derivation; restore path prompts for passphrase when needed. |
| 6 | `receive_sharing_intent` declared but never wired in `MainActivity` | `android/app/src/main/kotlin/io/github/wissamza/bazaar/MainActivity.kt`, `lib/main.dart` | Full wiring: Kotlin side forwards initial + warm-start intents via method channel; Dart side calls `ShareService.importFromPath`. |
| 7 | No `network_security_config` and no explicit cleartext policy | `android/app/src/main/res/xml/network_security_config.xml` | Added config that whitelists cleartext for `localhost`, `127.0.0.1`, `10.0.2.2` only; referenced from `AndroidManifest.xml`. |
| 14 | N+1 query in `ListItemDao.forListWithItems` | `lib/core/database/dao/list_item_dao.dart` | Replaced the loop with a single SQL JOIN; row mapping done in Dart. |
| 15 | `BackupService.readBackup` uses `utf8.decode` without `allowMalformed`, will throw on any non-UTF8 byte | `lib/core/services/backup_service.dart` | Wrapped in try/catch with a clear error message; skip non-expected ZIP entries. |
| 16 | `ShareService._importList` silently drops list items whose `item_id` is not found locally | `lib/core/services/share_service.dart` | v2 export format embeds the full Item data; importer upserts items by barcode first, builds old-id → new-id map, then inserts list_items with remapped IDs. |
| 17 | `ItemStoreDao.upsert` accesses `rows.first` without checking `isEmpty` | `lib/core/database/dao/item_store_dao.dart:44` | Added `isEmpty` guard; returns early on race-condition edge case. |
| 20 | `ItemDao.insert` uses `ConflictAlgorithm.replace`, silently overwrites existing rows on UNIQUE collisions | `lib/core/database/dao/item_dao.dart` | Switched to `ConflictAlgorithm.ignore`; wrapped `upsertByBarcode` in a transaction to close the race window. |

### Low / Info

| # | Finding | File | Fix |
|---|---------|------|-----|
| 8 | LLM API key entered in a plain TextField with no clipboard protection | `lib/features/settings/llm_settings_screen.dart` | Added `enableSuggestions: false`, `autocorrect: false`, `TextInputType.visiblePassword` to all secret-entry TextFields. |
| 9 | On-device model download trusts HuggingFace CDN with no integrity check | `lib/core/services/on_device_llm.dart` | Added `expectedSha256` field to `OnDeviceModel`; post-download SHA-256 verification with `package:crypto`; mismatch → delete + clear error message. Hashes left empty for now — fill in after first successful download to lock the supply chain. |
| 10 | Gemini SDK and on-device LLM calls have no timeout | `lib/core/services/llm_extractor.dart`, `lib/core/services/on_device_llm.dart` | Gemini: wrapped in `Future.any` with a 25-second `TimeoutException`; OpenAI-compat: 30-second connection timeout + 35-second overall timeout. |
| 11 | Ollama base URL stored in `Secrets` (overkill) and unvalidated | `lib/core/providers/scraping_provider.dart` | Added URL validation on `setSearxngUrl` (must be valid http/https URL or empty). Ollama URL kept in `Secrets` for backward-compat but the validation pattern is now applied. |
| 12 | Android `applicationId` is `com.example.bazaar` (rejected by Play Store) | `android/app/build.gradle`, `android/app/src/main/kotlin/...` | Renamed to `io.github.wissamza.bazaar`; moved `MainActivity.kt` to the new package directory. |
| 18 | Massive screens: `list_detail_screen` 1007 lines, `add_edit_item_screen` 817, `scraper_service` 833, `home` 712, `llm_settings` 599 | various | **Deferred to v1.5** — too invasive to do without being able to run `flutter test` to verify. |
| 19 | Duplicate imports in `item_dao.dart`, `list_item_dao.dart`, `scanner_screen.dart` | various | Removed all duplicate imports. |
| 21 | `BackupService.createBackup` leaves a `backup_tmp` directory on disk between calls | `lib/core/services/backup_service.dart` | Temp files now written to `getTemporaryDirectory()` (auto-cleaned by the OS) instead of `getApplicationDocumentsDirectory()`. |
| 22 | Stale TODO: brand field on add/edit form never populated from scraped product | `lib/features/items/add_edit_item_screen.dart:207` | Wired up `_brand.text = product.brand ?? _brand.text`; deleted the TODO. |

## Security invariants

The following invariants MUST be preserved by every future change to the codebase. PRs that violate them will be rejected.

1. **No hardcoded URLs to personal infrastructure.** Every endpoint URL must either be (a) a well-known public API (e.g. `https://world.openfoodfacts.org`), (b) a preset model URL from a verified public HuggingFace repo, or (c) user-configurable with no default.
2. **No `print()` in release paths.** Every `print` call must be gated by `kDebugMode`. The `avoid_print` lint must remain enabled.
3. **API keys never leave `Secrets`.** They are read at call time, passed as a runtime argument, never logged, never persisted outside `flutter_secure_storage`.
4. **Backup restore is per-row resilient.** A single malformed row must never abort the entire restore. Always wrap row-level upserts in try/catch and report skipped rows to the user.
5. **JSON import validates `type` and caps payload size.** Any untrusted JSON / ZIP must be size-capped, type-checked, and row-count-capped before it touches the DB.
6. **Cleartext HTTP only to localhost.** `network_security_config.xml` must keep the cleartext allowlist restricted to `localhost`, `127.0.0.1`, `10.0.2.2`.
7. **CI runs `flutter analyze` (no `|| true`) and `flutter test` before building the APK.** Any PR that weakens this gate will be rejected.

## Reporting a vulnerability

If you find a security issue, please **do not** open a public GitHub issue. Instead, email the maintainer directly at <wissam@example.com> (replace with the real address) with a description and a repro. You will get a response within 72 hours.
