#!/bin/bash
# Publishes Clipshot <version> in one go: runs the tests, sets the version in Resources/Info.plist (commit), builds the
# DMG signed with the stable identity, tags and pushes, publishes the GitHub release with the DMG and its .sha256 (what
# the in-app updater downloads and verifies) and points the Homebrew cask at it.
# Usage: scripts/release.sh <version> [notes-file]     (make release VERSION=1.0.1 [NOTES=notes.md])
#   Without a notes file GitHub generates the notes. SIGN_IDENTITY defaults to "Clipshot Dev" (`make cert`).
set -euo pipefail
VERSION="${1:-}"
NOTES="${2:-}"
APP_NAME=Clipshot
REPO="${APP_REPO:-egekibar/Clipshot}"
IDENTITY="${SIGN_IDENTITY:-Clipshot Dev}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLIST="$ROOT/Resources/Info.plist"
PLIST_BUDDY=/usr/libexec/PlistBuddy
cd "$ROOT"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "usage: make release VERSION=1.2.3 [NOTES=file]" >&2; exit 1; }
[ -z "$NOTES" ] || [ -f "$NOTES" ] || { echo "notes file $NOTES not found" >&2; exit 1; }
# Every release is signed with this identity: with ad-hoc builds macOS drops Screen Recording after each update.
security find-identity -v -p codesigning | grep -qF "\"$IDENTITY\"" ||
  { echo "signing identity '$IDENTITY' not found; run make cert first" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "the working tree has uncommitted changes" >&2; exit 1; }
[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || { echo "releases are cut from main" >&2; exit 1; }
if git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null; then echo "tag v$VERSION already exists" >&2; exit 1; fi

make test

CURRENT="$("$PLIST_BUDDY" -c 'Print :CFBundleShortVersionString' "$PLIST")"
if [ "$CURRENT" != "$VERSION" ]; then
  BUILD="$("$PLIST_BUDDY" -c 'Print :CFBundleVersion' "$PLIST")"
  # sed keeps the file's one-key-per-line layout; PlistBuddy would rewrite all of it.
  sed -i '' -E \
    -e "s#(<key>CFBundleShortVersionString</key><string>)[^<]*#\1$VERSION#" \
    -e "s#(<key>CFBundleVersion</key><string>)[^<]*#\1$((BUILD + 1))#" "$PLIST"
  [ "$("$PLIST_BUDDY" -c 'Print :CFBundleShortVersionString' "$PLIST")" = "$VERSION" ] ||
    { echo "could not set the version in $PLIST" >&2; exit 1; }
  git commit -q -m "chore(release): $VERSION" -- "$PLIST"
fi

make dmg SIGN_IDENTITY="$IDENTITY"
git tag -a "v$VERSION" -m "$APP_NAME $VERSION"
git push -q origin main "v$VERSION"

NOTES_ARGS=(--generate-notes)
if [ -n "$NOTES" ]; then NOTES_ARGS=(--notes-file "$NOTES"); fi
gh release create "v$VERSION" "dist/$APP_NAME-$VERSION.dmg" "dist/$APP_NAME-$VERSION.dmg.sha256" \
  --repo "$REPO" --title "$APP_NAME $VERSION" --verify-tag "${NOTES_ARGS[@]}"
./scripts/bump-cask.sh "$APP_NAME"
echo "Released $APP_NAME $VERSION: https://github.com/$REPO/releases/tag/v$VERSION"
