#!/usr/bin/env bash
# Pre-flight check: run on a machine that has Flutter installed.
# Verifies pubspec, generates l10n, runs analyze, and runs tests.
set -e

cd "$(dirname "$0")/.."

echo "==> flutter --version"
flutter --version

echo
echo "==> flutter pub get"
flutter pub get

echo
echo "==> flutter gen-l10n (auto-run by pub get, but explicit)"
flutter gen-l10n || true

echo
echo "==> flutter analyze"
flutter analyze || true

echo
echo "==> flutter test"
flutter test || true

echo
echo "==> DONE"
