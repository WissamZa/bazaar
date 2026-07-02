# Upgrade notes — v1.3.8 → v1.4.0

This document walks you through verifying that your local build of Bazaar still works after the v1.4.0 upgrade. The release includes 21 security/quality fixes, package upgrades, and a new Android application ID — none of which should break a fresh install, but existing installs need a couple of migrations.

## 1. Prerequisites

- Flutter SDK **3.44 or newer** (unchanged from v1.3.8 — no upgrade needed). Check with `flutter --version`.
- Dart SDK **3.4 or newer** (comes with Flutter).
- Android SDK with `compileSdk 37` (was 34). Android Studio's SDK Manager will offer this.

## 2. Regenerate the lockfile

The `pubspec.lock` was deleted in v1.4.0 because 14 packages were bumped. Run:

```bash
cd bazaar
flutter clean
flutter pub get
```

Inspect the new `pubspec.lock` to confirm versions match what you expect. Commit it.

## 3. Verify the build compiles

```bash
flutter analyze --no-fatal-infos      # should pass with zero errors
flutter test                          # should pass all tests
flutter build apk --debug             # should produce a debug APK
```

If `flutter analyze` reports new warnings from the upgraded `flutter_lints` 6.x, fix them. Common ones:
- `prefer_const_constructors` is now stricter
- `use_super_parameters` is new — add `super.key` to widget constructors

## 4. Migrate existing installs

If you have an existing install of v1.3.8 on a device, the upgrade path is:

### 4.1 SearXNG URL migration

The old default (`https://cachyos-nitro.tail3d23b7.ts.net:8080`) is wiped on first launch of v1.4.0. The user will see a "SearXNG not configured" banner in Settings and must enter their own URL.

**Action:** Communicate this in the release notes. Users who self-hosted SearXNG need to re-enter their URL.

### 4.2 Android application ID change

The `applicationId` changed from `com.example.bazaar` to `io.github.wissamza.bazaar`. Android treats this as a different app, which means:

- The new install will NOT see the old install's data (different sandbox).
- The old install will NOT be auto-updated; users must uninstall the old one and install the new one.
- The old install's keystore entries (API keys) are NOT visible to the new install.

**Action:** Before upgrading, existing users should:
1. Open v1.3.8 → Settings → Backup → create a backup ZIP (with a passphrase if they want encryption — but v1.3.8 doesn't support that, so the backup will be plaintext).
2. Uninstall v1.3.8.
3. Install v1.4.0.
4. Open v1.4.0 → Settings → Restore → pick the backup ZIP.
5. Re-enter API keys in Settings → Search & LLM (keys are NOT included in the backup for security).

### 4.3 On-device LLM model

If the user previously downloaded a model file in v1.3.8, the model file path stored in `Secrets` is still valid (the file is in the app's documents directory, which survives the upgrade since the application ID change requires a fresh install anyway — see 4.2). After the fresh install they will need to re-download the model.

## 5. Test the new features

### 5.1 Encrypted backup

1. Open Settings → Backup.
2. The dialog now has three buttons: **Cancel**, **No encryption**, **Encrypt**.
3. Tap **Encrypt**, enter a passphrase, tap **Encrypt**.
4. Share the ZIP to your laptop.
5. Open Settings → Restore, pick the ZIP.
6. The decrypt-passphrase dialog should appear.
7. Enter the wrong passphrase → should fail with a clear error.
8. Enter the right passphrase → restore should succeed.

### 5.2 Receive sharing intent

1. Open WhatsApp (or any app that can share files).
2. Send yourself a `.json` file exported from Bazaar (Items export).
3. Tap the file in WhatsApp → Bazaar should appear in the open-with sheet.
4. Tap Bazaar → the app opens and imports the file.
5. Verify the items appear in the Items list.

### 5.3 JSON list import (v2 format)

1. Open a shopping list → tap the share button → export.
2. The exported `.json` file now contains a `products` array (v1.3.8 did not).
3. Uninstall Bazaar (or use a second device).
4. Install Bazaar fresh.
5. Open Settings → Import JSON → pick the exported list file.
6. Verify the list appears with all its items (in v1.3.8 this would have been an empty list).

### 5.4 N+1 query fix

1. Open a shopping list with 20+ items.
2. The list should load noticeably faster than in v1.3.8 (single SQL JOIN instead of 21 round-trips).
3. Toggle items checked / unchecked — should be smooth, no jank.

### 5.5 CI gate

Open a PR against `main`. The CI workflow should now:
1. Run `flutter analyze` and fail the build on any analyzer error (was silently swallowed in v1.3.8).
2. Run `flutter test` and fail the build on any test failure (was not run at all in v1.3.8).
3. Build the APK only if both pass.

## 6. Rollback

If v1.4.0 is broken for you, rollback is straightforward because the data format is unchanged:

1. Uninstall v1.4.0.
2. Install v1.3.8 from the previous release.
3. Settings → Restore → pick the backup ZIP you created before upgrading.

The only loss is the encrypted-backup feature (v1.3.8 cannot restore an encrypted ZIP — it will throw "Encrypted entry items.json.enc encountered but no passphrase was provided"). If your only backup is encrypted, you must restore it with v1.4.0 first, then re-export as plaintext, then rollback.

## 7. Reporting issues

If you hit a problem not covered here, open an issue at <https://github.com/WissamZa/bazaar/issues> with:
- The exact `flutter analyze` / `flutter test` / build output
- Your Flutter / Dart / Android SDK versions
- Whether you migrated from v1.3.8 or did a fresh install
- The device / emulator you tested on
