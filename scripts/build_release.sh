#!/usr/bin/env bash
# =============================================================================
# DocSera — production release build script
# =============================================================================
# Usage:
#   ./scripts/build_release.sh apk         # Android release APK
#   ./scripts/build_release.sh appbundle   # Android App Bundle (Play Store)
#   ./scripts/build_release.sh ios         # iOS archive (run from macOS)
#
# What this does that a plain `flutter build` doesn't:
#   1. --obfuscate                Renames Dart symbols to make reverse-engineering harder
#   2. --split-debug-info=...     Stores symbol mapping outside the binary (you need this
#                                 to symbolicate Sentry crashes for the obfuscated build)
#   3. --dart-define-from-file    Bakes the Sentry DSN (and other build-time config) in
#   4. Fails loudly if dart_defines/sentry.json is missing
#
# After a successful build, the symbol files in build/symbols/ MUST be kept safe
# (commit them to a private location, NOT to git). Sentry symbolication and any
# future crash debugging depend on them.
# =============================================================================

set -euo pipefail

cd "$(dirname "$0")/.."

TARGET="${1:-apk}"
DEFINES_FILE="dart_defines/sentry.json"
SYMBOLS_DIR="build/symbols/$(date +%Y%m%d-%H%M%S)"

if [[ ! -f "$DEFINES_FILE" ]]; then
  echo "❌ Missing $DEFINES_FILE — required for production builds (contains Sentry DSN)."
  echo "   Copy dart_defines/sentry.example.json and fill in real values, then re-run."
  exit 1
fi

if grep -q '"SENTRY_TEST": "1"' "$DEFINES_FILE"; then
  echo "❌ SENTRY_TEST is set to \"1\" in $DEFINES_FILE."
  echo "   This must be \"\" for production submissions or every install will fire a test event."
  exit 1
fi

mkdir -p "$SYMBOLS_DIR"

echo "→ Building $TARGET (release, obfuscated)…"
echo "  Symbols: $SYMBOLS_DIR"

case "$TARGET" in
  apk)
    flutter build apk --release \
      --obfuscate --split-debug-info="$SYMBOLS_DIR" \
      --dart-define-from-file="$DEFINES_FILE"
    echo "✅ APK at build/app/outputs/flutter-apk/app-release.apk"
    ;;
  appbundle)
    flutter build appbundle --release \
      --obfuscate --split-debug-info="$SYMBOLS_DIR" \
      --dart-define-from-file="$DEFINES_FILE"
    echo "✅ App Bundle at build/app/outputs/bundle/release/app-release.aab"
    ;;
  ios)
    flutter build ios --release \
      --obfuscate --split-debug-info="$SYMBOLS_DIR" \
      --dart-define-from-file="$DEFINES_FILE"
    echo "✅ iOS build prepared. Open ios/Runner.xcworkspace and Archive."
    ;;
  *)
    echo "❌ Unknown target: $TARGET. Use one of: apk | appbundle | ios"
    exit 1
    ;;
esac

echo
echo "🔐 IMPORTANT: back up $SYMBOLS_DIR somewhere safe."
echo "   Without it, Sentry crashes and any future debugging will be unreadable."
