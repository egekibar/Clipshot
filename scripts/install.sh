#!/bin/bash
# Copies dist/<App>.app to ~/Applications (a stable path keeps the Screen Recording grant), replacing a running copy.
set -euo pipefail
APP_NAME="${1:-Clipshot}"
INSTALL_DIR="${2:-$HOME/Applications}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/dist/$APP_NAME.app"
[ -d "$SRC" ] || { echo "dist/$APP_NAME.app missing; run make bundle" >&2; exit 1; }
mkdir -p "$INSTALL_DIR"
# Clipshot keeps no state worth saving, so a plain SIGTERM is enough; one still there after 5 s is killed.
if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  pkill -x "$APP_NAME" 2>/dev/null || true
  for _ in $(seq 1 25); do
    pgrep -x "$APP_NAME" >/dev/null 2>&1 || break
    sleep 0.2
  done
  pkill -9 -x "$APP_NAME" 2>/dev/null || true
fi
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$SRC" "$INSTALL_DIR/$APP_NAME.app"
echo "Installed: $INSTALL_DIR/$APP_NAME.app"
