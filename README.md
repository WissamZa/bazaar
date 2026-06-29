# Bazaar — Local Shopping List App

A 100% local Flutter shopping list app: SQLite on-device, no server, no auth,
no paid APIs. Scan a barcode, look it up online (Open Food Facts + Amazon SA
+ Noon + Panda + Carrefour SA), save it as an item, add it to a shopping
list, track prices across multiple stores, and back up / restore via a
shareable ZIP file. Localised for English and Arabic (RTL), with light and
dark themes and SAR (﷼) / USD ($) currency support.

---

## What's new

- **Home / Analytics tab**: a new dashboard surfaces quick KPIs (lists,
  items, stores), recent lists, top stores by item count, top-5 most
  expensive items, and side-by-side price comparisons across stores for
  the same product.
- **Per-source barcode lookup**: when scanning a barcode (or tapping the
  lookup button on the Add/Edit item form), the user can choose which
  source to query — Auto (full chain), Open Food Facts, Amazon SA, Noon,
  Panda, or Carrefour SA.
- **List detail redesign**: each row shows the item name, unit price,
  preferred store, barcode, and line total. Tap to edit price/store;
  long-press (or the ⋮ menu) to add a price at another store, edit the
  item, or remove it from the list. A summary bar shows total items +
  total price; a footer shows the checked total alongside the list total.
- **Signed APK CI**: `.github/workflows/build-apk.yml` builds a signed
  release APK on every push, PR, and tag push, using an Android release
  keystore stored as GitHub secrets. See
  [docs/ANDROID_SIGNING.md](docs/ANDROID_SIGNING.md) for setup.

---

## Tech stack

| Layer            | Choice                                  |
|------------------|------------------------------------------|
| Framework        | Flutter (>= 3.19) + Dart (>= 3.3)        |
| Database         | SQLite via `sqflite`                     |
| State management | `provider`                               |
| Barcode scan     | `mobile_scanner` (ML Kit, on-device)     |
| Online lookup    | `http` + `html` (scraper chain + Open Food Facts API) |
| Backup           | `archive` (ZIP encode/decode)            |
| i18n             | `flutter_localizations` + ARB files      |
| Persistence      | `shared_preferences` (theme/locale/currency/username) |

Zero server cost. Zero third-party auth. No telemetry.

---

## Project structure

```
lib/
├── main.dart                       # App bootstrap + MultiProvider
├── app.dart                        # MaterialApp, theme, locale, RTL
├── core/
│   ├── constants/
│   │   ├── app_colors.dart
│   │   ├── app_strings.dart
│   │   └── currencies.dart         # SAR (﷼) + USD ($) + conversion
│   ├── database/
│   │   ├── database_helper.dart    # SQLite init, schema, migrations
│   │   └── dao/                    # item, store, shopping_list, list_item, item_store
│   ├── models/                     # Item, Store, ShoppingList, ListItem, ItemStore
│   ├── providers/                  # theme, locale, currency, user
│   └── services/                   # barcode, scraper, share, backup
├── features/
│   ├── auth/username_screen.dart
│   ├── home_shell.dart             # Bottom-nav scaffold (Home | Items | Lists | Stores)
│   ├── home/home_screen.dart       # Analytics dashboard (KPIs, recent lists, price compare)
│   ├── items/                      # list + add/edit
│   ├── shopping_lists/             # list + detail + add/edit
│   ├── stores/                     # list + add/edit
│   ├── scanner/                    # scanner + scan_result (with source picker)
│   └── settings/settings_screen.dart
├── l10n/
│   ├── app_en.arb
│   └── app_ar.arb
└── widgets/                        # bottom_nav, currency_display, language_toggle, theme_toggle, empty_state
```

---

## Getting started

### Prerequisites
- Flutter SDK 3.19 or newer (<https://flutter.dev>)
- Android SDK (for Android builds) — `minSdk 21`, `targetSdk 34`
- Xcode 15+ (for iOS builds, macOS only)
- For Linux: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, `liblzma-dev`, `libstdc++-12-dev`
- For Windows: Visual Studio 2022 with "Desktop development with C++"

### Install
```bash
cd bazaar
flutter pub get
```

### Run
```bash
flutter run                 # auto-detects connected device
flutter run -d <device-id>  # specific device
```

### Build a release APK

Locally (signed with the debug key by default):

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

Locally (signed with your release keystore — see
[docs/ANDROID_SIGNING.md](docs/ANDROID_SIGNING.md)):

```bash
./scripts/generate_keystore.sh   # one-time setup
flutter build apk --release
```

On CI: every push to `main`/`master`, every PR, every `v*` tag, and every
manual dispatch triggers `.github/workflows/build-apk.yml`, which builds a
signed release APK and uploads it as a workflow artifact (and attaches it
to a GitHub Release on tag pushes). Configure these four repository
secrets to enable release signing:

| Secret | Value |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64`     | `base64 -w 0 android/app/bazaar-release.jks` |
| `ANDROID_KEY_STORE_PASSWORD`  | keystore password |
| `ANDROID_KEY_PASSWORD`        | key password |
| `ANDROID_KEY_ALIAS`           | key alias (`bazaar` by default) |

### Run on Linux desktop
```bash
flutter config --enable-linux-desktop
flutter run -d linux
```

### Run on Windows desktop
```bash
flutter config --enable-windows-desktop
flutter run -d windows
```

---

## NotoSansArabic font

The new Saudi Riyal symbol `﷼` (U+FDFC) needs a font that ships the glyph.
This project expects `assets/fonts/NotoSansArabic-Regular.ttf` and
`assets/fonts/NotoSansArabic-Bold.ttf`. Download them from
<https://fonts.google.com/noto/specimen/Noto+Sans+Arabic> and drop them into
`assets/fonts/` before running `flutter pub get` for the first time.
If the fonts are missing, Flutter will fall back to the system default
Arabic font, which usually still renders ﷼ on Android 10+ and iOS 16+.

---

## Permissions

Android (`AndroidManifest.xml`):
- `CAMERA` — barcode scanning
- `INTERNET` — online barcode lookup
- `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` (maxSdk 28) — legacy
- `READ_MEDIA_IMAGES` — Android 13+

iOS (`Info.plist`, when you add an iOS target):
- `NSCameraUsageDescription` — "Bazaar uses the camera to scan product barcodes."
- `NSPhotoLibraryUsageDescription` — "Bazaar reads JSON/ZIP files from your library."

Desktop: no special permissions needed.

---

## Database schema (SQLite)

```sql
users(id, username UNIQUE, created_at)
stores(id, name, name_ar, website, created_at)
items(id, barcode UNIQUE, name_en, name_ar, price, currency, image_url, created_at, updated_at)
item_store(id, item_id FK, store_id FK, price, currency, url, UNIQUE(item_id, store_id))
shopping_lists(id, name, name_ar, owner, created_at, updated_at)
list_items(id, list_id FK, item_id FK, quantity, is_checked, preferred_store_id, note, UNIQUE(list_id, item_id))
```

Foreign keys are enabled; cascade deletes remove orphaned M2M rows.

---

## Barcode lookup flow

1. User opens the scanner → `mobile_scanner` reads a code from the camera.
2. `ScanResultScreen` shows a **source picker** at the top so the user can
   choose which catalog to query:
   - Auto — full chain (default)
   - Open Food Facts — structured JSON API, returns the product name (and
     Arabic name when available). No price.
   - Amazon SA — HTML scrape, returns name + price.
   - Noon — HTML scrape (often SSR-deficient, falls through).
   - Panda — HTML scrape.
   - Carrefour SA — HTML scrape.
3. `BarcodeService.lookup()` first calls `ItemDao.findByBarcode` against
   the local DB (skipped when the user explicitly picks a single online
   source — that lets them refresh prices even for items they already have).
4. If not found locally (or source ≠ Auto), the matching
   `ScraperService` scraper runs.
5. The result screen lets the user save the item directly or pre-fill the
   Add/Edit form for manual review.

> Store HTML selectors will break as sites evolve. Each scraper is wrapped
> in try/catch so one failure never blocks the chain. Open Food Facts is
> always tried because it's a structured API.

---

## Backup & restore

- **Backup** → `BackupService.createBackup()` dumps every table to JSON
  files, zips them with `archive`, and shares the ZIP via `share_plus`.
- **Restore** → User picks a ZIP via `file_picker`, sees a checklist of
  Items / Stores / Lists with counts, then `restoreSelective` upserts
  (never wipes) the chosen tables.

---

## Share / import

- Export Items / Stores / a Shopping List as JSON → system share sheet
  (WhatsApp, Telegram, email, AirDrop, Files).
- Import a JSON file from any source → upsert into the DB by barcode /
  name. Detected via `type` field: `items` / `shopping_list` / `stores`.
- The app registers an `application/json` intent filter on Android so
  tapping a shared `.json` file from another app opens Bazaar. (For full
  intent handling, add `receive_sharing_intent` wiring in `MainActivity` —
  the package is already in `pubspec.yaml`.)

---

## Testing checklist

- [x] SQLite tables created on first launch
- [x] Items CRUD: add, edit, delete, search by name, search by barcode
- [x] Stores CRUD
- [x] Shopping lists CRUD
- [x] M2M: add item to list, remove item, set quantity, check/uncheck
- [x] Barcode camera opens, reads code, queries DB
- [x] Online barcode search returns a result (Open Food Facts fallback)
- [x] Language switches EN ↔ AR with RTL layout
- [x] Theme switches Light ↔ Dark, persists after restart
- [x] Currency switches SAR ↔ USD, symbol displays correctly (﷼ renders)
- [x] Export items as JSON
- [x] Import JSON merges into DB
- [x] Create backup ZIP, restore ZIP, selective restore works
- [x] Username entry on first launch, persists, never asks again
- [x] App works completely offline (no login, no server calls except scraping)

---

## License

MIT-style: do whatever you want, attribution appreciated. No warranty.
