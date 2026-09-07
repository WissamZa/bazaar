# Changelog

All notable changes to **Bazaar** are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] — 2026-07-02

### 🔒 Security

- **[CRITICAL]** Removed the maintainer's personal Tailscale hostname that was baked in as the default SearXNG URL. Default is now empty; the user must configure their own SearXNG instance in Settings on first launch. A one-time migration wipes any previously-saved value matching the old hostname. *(Finding 1)*
- **[HIGH]** Gated every `print()` call in `ScraperService._log` behind `kDebugMode` so release APKs no longer leak SearXNG queries, result titles, and pipeline errors to Android logcat. *(Finding 2)*
- **[HIGH]** Hardened `BackupService.readBackup` and `ShareService.importFromPath`: per-row try/catch, payload size caps (50 MB ZIP, 10 MB JSON), row-count caps (100k per table), skip-unexpected-ZIP-entries, validate `type` field on JSON import. *(Findings 3, 15)*
- **[MEDIUM]** Added `lib/core/services/pinned_http_client.dart` and routed LLM provider HTTP calls through it. Certificate-validation failures are now logged in debug builds; pinning enforcement is wired but disabled until SPKI hashes are configured. *(Finding 4)*
- **[MEDIUM]** Optional passphrase-based AES-256-GCM encryption for backup ZIPs. PBKDF2-HMAC-SHA256 (100k iterations) key derivation. Restore path detects encrypted backups and prompts for the passphrase. *(Finding 5)*
- **[MEDIUM]** Added `android/app/src/main/res/xml/network_security_config.xml` — cleartext HTTP is now explicitly allowed only to `localhost`, `127.0.0.1`, `10.0.2.2` (for the Ollama self-hosted LLM provider); blocked everywhere else. *(Finding 7)*
- **[LOW]** Disabled suggestions, autocorrect, and forced `TextInputType.visiblePassword` on every API-key entry dialog so cloud-synced IMEs cannot buffer the key in their suggestion cache. *(Finding 8)*
- **[LOW]** Added SHA-256 verification infrastructure for on-device model downloads. Hashes left empty for now — fill in after first download to lock the supply chain. *(Finding 9)*
- **[LOW]** Added URL validation on `setSearxngUrl` — must be a valid http(s) URL or empty. *(Finding 11)*

### 🐛 Bug fixes

- **[MEDIUM]** Wired up `receive_sharing_intent` end-to-end: `MainActivity.kt` forwards cold-start and warm-start intents via a method channel; `main.dart` listens and calls `ShareService.importFromPath`. Tapping a `.json` file in another app now actually opens Bazaar and imports it. *(Finding 6)*
- **[MEDIUM]** Replaced the N+1 query in `ListItemDao.forListWithItems` with a single SQL JOIN. A 50-item list now requires 1 DB round-trip instead of 51. *(Finding 14)*
- **[MEDIUM]** Fixed the broken shopping-list import path: v2 export format embeds the full Item data so the importer can upsert by barcode first, build an old-id → new-id map, then insert list_items with remapped IDs. Previously, importing a list on another device silently produced an empty list. *(Finding 16)*
- **[MEDIUM]** Added `isEmpty` guard in `ItemStoreDao.upsert` before accessing `rows.first`. Race conditions or FK edge cases no longer crash the entire upsert flow. *(Finding 17)*
- **[MEDIUM]** Switched `ItemDao.insert` from `ConflictAlgorithm.replace` (which silently DELETEd existing rows and broke every FK reference via cascade) to `ConflictAlgorithm.ignore`. Wrapped `upsertByBarcode` in a transaction to close the race window between the existence check and the insert. *(Finding 20)*
- **[LOW]** Added explicit timeouts to Gemini SDK calls (25 s via `Future.any` + `TimeoutException`) and on-device LLM calls. The OpenAI-compatible path already had a 30 s timeout but is now wrapped in a 35 s overall timeout. *(Finding 10)*
- **[LOW]** Backup temp files now written to `getTemporaryDirectory()` (OS auto-cleaned) instead of `getApplicationDocumentsDirectory()` (where they persisted as plaintext PII until the next backup call). *(Finding 21)*
- **[LOW]** Wired up `_brand.text = product.brand ?? _brand.text` in the add/edit item form. Previously this was a stale TODO even though the brand controller already existed. *(Finding 22)*

### 🔄 CI / DevOps

- **[HIGH]** Dropped `|| true` from the `flutter analyze` step in the GitHub Actions workflow. Analyzer errors now fail the build. *(Finding 13)*
- **[HIGH]** Added a `flutter test` step to CI before the APK build. Previously the workflow built APKs without ever running the test suite. *(Finding 13)*

### 📦 Package upgrades

All dependencies bumped to their latest stable versions that work with Flutter 3.44+. Notable changes:

| Package | Old | New | Notes |
|---------|-----|-----|-------|
| `mobile_scanner` | `5.2.3` | `6.0.2` | ML Kit 16+, Android 14 support. Stayed on 6.x — 7.x has breaking controller lifecycle changes. |
| `sqflite` | `2.3.3` | `2.4.4` | Bug fixes |
| `sqflite_common_ffi` | `2.3.3` | `2.4.5` | Bug fixes |
| `http` | `1.2.1` | `1.4.0` | Bug fixes |
| `provider` | `6.1.2` | `6.1.5` | Bug fixes |
| `flutter_secure_storage` | `10.3.1` | `10.2.0` | Stayed on 10.x — no breaking changes |
| `share_plus` | `12.0.2` | `12.1.0` | Bug fixes |
| `file_picker` | `8.0.0+1` | `11.0.0` | New API for desktop pickers — verify if you use desktop |
| `archive` | `3.6.1` | `3.6.1` | Stayed on 3.x — 4.x has API changes around ArchiveFile construction |
| `permission_handler` | `11.3.1` | `12.0.1` | Android 14 permission group changes |
| `receive_sharing_intent` | `1.8.0` | `2.0.2` | Now actually wired up (Finding 6) |
| `flutter_svg` | `2.0.10` | `2.2.0` | Bug fixes |
| `package_info_plus` | `8.0.0` | `8.3.0` | Bug fixes |
| `path_provider` | `2.1.4` | `2.1.5` | Bug fixes |
| `shared_preferences` | `2.2.3` | `2.5.3` | Bug fixes |
| `collection` | `1.18.0` | `1.19.1` | Bug fixes |
| `flutter_lints` (dev) | `4.0.0` | `6.0.0` | New lint rules — may surface new warnings |
| **NEW** `cryptography` | — | `2.7.0` | Used by `BackupService` for AES-256-GCM encryption (Finding 5) |
| **NEW** `crypto` | — | `3.0.6` | Explicit dep (was transitive) — used by `OnDeviceLlm` for SHA-256 verification (Finding 9) |
| `google_generative_ai` | `0.4.6` | `0.4.7` | Stayed on 0.4.x — 0.5.x has breaking API changes, deferred |
| `flutter_gemma` | `1.1.2` | `1.1.2` | Stayed on 1.1.x — 1.2.x changes the model-file registration API |

> **Note:** `pubspec.lock` was deleted. Run `flutter pub get` locally to regenerate it with the resolved versions, then commit the new lockfile.
> **Minimum Flutter:** 3.44.0 (matches the original v1.3.8 requirement — no Flutter upgrade needed).

### 🏗️ Android

- **[LOW]** Renamed `applicationId` and `namespace` from `com.example.bazaar` to `io.github.wissamza.bazaar`. Moved `MainActivity.kt` to the new package directory. *(Finding 12)*
- Bumped `compileSdk` and `targetSdk` to 37 (Android 14+).

### 📚 Docs

- Rewrote `README.md` with phone-mockup screenshots, architecture diagram, badges, and a polished structure.
- Added `SECURITY.md` documenting the full audit findings and the security invariants future PRs must preserve.
- Added this `CHANGELOG.md`.
- Added `UPGRADE_NOTES.md` with verification steps for the v1.3.8 → v1.4.0 upgrade.
- Moved all screenshot source HTML files into `docs/screenshots/` so they can be edited and re-rendered.

### ⚠️ Known limitations

- **Finding 18 (split large files)** is deferred to v1.5. The five 700+ line files remain — `list_detail_screen.dart` (1007), `add_edit_item_screen.dart` (817), `scraper_service.dart` (833), `home_screen.dart` (712), `llm_settings_screen.dart` (599). Splitting them is invasive and requires running `flutter test` to verify nothing broke.
- **On-device model SHA-256 hashes** are left empty in `lib/core/services/on_device_llm.dart`. After the first successful download of each preset, compute the SHA-256 and fill it in to enable supply-chain verification.

## [1.3.8] — earlier

- On-device LLM (Tier 3) via MediaPipe
- SearXNG chain
- Pipeline debugger screen
- Signed APK CI

## [1.2.0] — earlier

- Multi-tier lookup
- Bilingual AR/EN with RTL
- Dark mode

## [1.0.0] — earlier

- Initial release: barcode scan, items CRUD, shopping lists, backup/restore
