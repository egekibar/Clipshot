#!/bin/bash
# Builds dist/<App>.app from the SwiftPM release binary and signs it.
# Usage: scripts/bundle.sh [AppName] [BundleID] [SigningIdentity]
#   Build first (`swift build -c release`; the Makefile does). SigningIdentity defaults to $SIGN_IDENTITY, then
#   "Clipshot Dev" (`make cert`). Without it the bundle is signed ad-hoc: it works, but the Screen Recording grant is
#   tied to that exact build, so macOS asks again after every rebuild.
set -euo pipefail
APP_NAME="${1:-Clipshot}"
BUNDLE_ID="${2:-com.egekibar.clipshot}"
IDENTITY="${3:-${SIGN_IDENTITY:-Clipshot Dev}}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$(swift build --package-path "$ROOT" -c release --show-bin-path)"
[ -x "$BIN_DIR/$APP_NAME" ] || { echo "$BIN_DIR/$APP_NAME missing; run swift build -c release first" >&2; exit 1; }
APP="$ROOT/dist/$APP_NAME.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
sed -e "s/__BUNDLE_ID__/$BUNDLE_ID/g" -e "s/__APP_NAME__/$APP_NAME/g" \
  "$ROOT/Resources/Info.plist" > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null
if [ -f "$ROOT/Resources/AppIcon.icns" ]; then cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/"; fi
printf 'APPL????' > "$APP/Contents/PkgInfo"

ENTITLEMENTS="$ROOT/Resources/$APP_NAME.entitlements"
if security find-identity -v -p codesigning 2>/dev/null | grep -qF "\"$IDENTITY\""; then
  codesign --force --options runtime --timestamp=none --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP"
else
  echo "NOTE: signing identity '$IDENTITY' not found (\`make cert\` creates it); signing ad-hoc." >&2
  echo "      macOS will ask for Screen Recording again after each rebuild." >&2
  codesign --force --options runtime --entitlements "$ENTITLEMENTS" --sign - "$APP"
fi
codesign --verify --deep --strict "$APP"
echo "Bundled and signed: $APP"
