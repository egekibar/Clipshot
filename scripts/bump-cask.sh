#!/bin/bash
# Points the Homebrew cask in egekibar/homebrew-tap at the published GitHub release of the current version: sets
# `version` and `sha256` (taken from the release's own .sha256 asset, so the cask matches what users download)
# and pushes it. Run it after the release is published. The first run adds the cask from packaging/<token>.rb.
# Usage: scripts/bump-cask.sh [AppName]     (TAP_REPO / APP_REPO override the GitHub repositories)
set -euo pipefail
APP_NAME="${1:-Clipshot}"
TAP_REPO="${TAP_REPO:-egekibar/homebrew-tap}"
APP_REPO="${APP_REPO:-egekibar/Clipshot}"
TOKEN="$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
ASSET="$APP_NAME-$VERSION.dmg.sha256"

SHA="$(gh release download "v$VERSION" --repo "$APP_REPO" --pattern "$ASSET" --output - | awk '{print $1}')"
[[ "$SHA" =~ ^[0-9a-f]{64}$ ]] || { echo "no valid $ASSET on release v$VERSION of $APP_REPO" >&2; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/$APP_NAME-tap.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
git clone --quiet "https://github.com/$TAP_REPO.git" "$WORK"
CASK="$WORK/Casks/$TOKEN.rb"
if [ ! -f "$CASK" ]; then
  [ -f "$ROOT/packaging/$TOKEN.rb" ] || { echo "$TAP_REPO has no Casks/$TOKEN.rb and there is no template" >&2; exit 1; }
  mkdir -p "$WORK/Casks"
  cp "$ROOT/packaging/$TOKEN.rb" "$CASK"
  git -C "$WORK" add "Casks/$TOKEN.rb"
fi
sed -i '' -E -e "s/^  version \"[^\"]*\"/  version \"$VERSION\"/" -e "s/^  sha256 \"[0-9a-f]{64}\"/  sha256 \"$SHA\"/" "$CASK"
grep -qF "version \"$VERSION\"" "$CASK" && grep -qF "sha256 \"$SHA\"" "$CASK" ||
  { echo "could not update $CASK" >&2; exit 1; }
if git -C "$WORK" diff --quiet HEAD; then
  echo "$TAP_REPO already points at $VERSION"
  exit 0
fi
git -C "$WORK" commit --quiet -am "$TOKEN $VERSION"
# Through gh's login over HTTPS (the tap is cloned over HTTPS), so no SSH key is needed.
git -C "$WORK" -c credential.helper= -c credential.helper='!gh auth git-credential' push --quiet origin HEAD
echo "Pushed $TOKEN $VERSION ($SHA) to $TAP_REPO; users get it with: brew upgrade --cask --greedy $TOKEN"
