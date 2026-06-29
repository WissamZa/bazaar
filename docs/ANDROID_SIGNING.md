# Android release signing

This document explains how to generate an Android release keystore, register
it as GitHub secrets, and ship a signed APK from the GitHub Action in
`.github/workflows/build-apk.yml`.

---

## 1. Generate the keystore locally

Run the helper script from the repo root:

```bash
./scripts/generate_keystore.sh
```

It will ask for:

| Prompt | Description |
|--------|-------------|
| `Keystore password`        | Password protecting the whole keystore file. |
| `Key password`             | Password protecting the bazaar key (defaults to the keystore password). |
| `Key alias [bazaar]`       | Friendly name for the key inside the keystore. |
| `Validity in years [25]`   | How long the key stays valid. 25 years is the Android recommendation. |
| `Your name`                | Common Name (CN) written into the certificate DN. |
| `Organization`             | Organization (O) written into the certificate DN. |

The script writes two files:

- `android/app/bazaar-release.jks` — the keystore. **Never lose this file.**
  You cannot publish an update to a published app without it.
- `android/key.properties` — plaintext pointer used by Gradle to load the
  keystore. Both files are listed in `.gitignore` and will never be committed.

After the script finishes, verify a release build works locally:

```bash
flutter build apk --release
```

The output APK at `build/app/outputs/flutter-apk/app-release.apk` will be
signed with your new release key.

---

## 2. Register the keystore as GitHub secrets

The CI workflow decodes a base64-encoded keystore from a secret and writes
the matching `key.properties` on the runner. You need four secrets:

| Secret name | Value |
|-------------|-------|
| `ANDROID_KEYSTORE_BASE64`     | `base64 -w 0 android/app/bazaar-release.jks` (paste the entire output). |
| `ANDROID_KEY_STORE_PASSWORD`  | The `storePassword` you typed in step 1. |
| `ANDROID_KEY_PASSWORD`        | The `keyPassword` you typed in step 1. |
| `ANDROID_KEY_ALIAS`           | The alias (defaults to `bazaar`). |

To get the base64 string on Linux/macOS:

```bash
base64 -w 0 android/app/bazaar-release.jks
# macOS users: base64 -i android/app/bazaar-release.jks
```

Add the secrets under your repo settings:
**Settings → Secrets and variables → Actions → New repository secret.**

---

## 3. How the workflow uses them

`.github/workflows/build-apk.yml` does the following on every push, PR, and
tag (`v*`):

1. Checks out the repo and sets up JDK 17 + Flutter.
2. Decodes `ANDROID_KEYSTORE_BASE64` to `android/app/bazaar-release.jks`.
3. Writes `android/key.properties` from the remaining secrets.
4. Runs `flutter build apk --release`.
5. Uploads the APK as a workflow artifact (`bazaar-apk`) with 30-day
   retention.
6. On tag pushes (`v1.0.0`, etc.), attaches the APK to a GitHub release.

If the secrets are missing, the workflow still builds an APK, but it will be
signed with the debug key (fine for testing, not for Play Store upload).

---

## 4. Triggering a build

```bash
# Manual run from the Actions tab: Workflow dispatch → Run workflow.
# Or push a tag to cut a release:
git tag v1.0.0
git push origin v1.0.0
```

The APK appears in:
- **Actions → [your run] → Artifacts** for any push/PR/dispatch.
- **Releases** page for tag pushes.

---

## 5. Rotating or losing the key

If you lose `bazaar-release.jks`, you cannot publish updates to an app
already on the Play Store that was signed with that key. Keep at least one
offline backup (e.g. on a USB stick or in a password manager).

If you ever need to rotate the key:

1. Generate a new keystore with `scripts/generate_keystore.sh` (delete the
   old one first).
2. Update the four GitHub secrets.
3. Cut a new release tag. The new APK will be signed with the new key.
4. For Play Store apps: use Google Play's **key upgrade** flow to migrate
   users to the new signing key (one-time operation, irreversible).

---

## 6. Verifying an APK signature

```bash
# After downloading the APK from the Actions artifact:
keytool -printcert -jarfile bazaar-<sha>-signed.apk
```

You should see the CN/O/L/ST/C you entered in step 1.
