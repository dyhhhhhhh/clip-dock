#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ClipDock"
VERSION="${VERSION:-0.1.0}"
APP_PATH="$ROOT_DIR/.build/$APP_NAME.app"
ZIP_PATH="$ROOT_DIR/dist/${APP_NAME}-${VERSION}-macOS.zip"
EXPAND_DIR="$ROOT_DIR/.build/smoke-qa"
EXPANDED_APP="$EXPAND_DIR/$APP_NAME.app"

cd "$ROOT_DIR"

swift test
"$ROOT_DIR/Scripts/package-release.sh" >/tmp/clipdock-package-release.log

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Missing release zip: $ZIP_PATH" >&2
  exit 1
fi

rm -rf "$EXPAND_DIR"
mkdir -p "$EXPAND_DIR"
ditto -x -k "$ZIP_PATH" "$EXPAND_DIR"

if [[ ! -d "$EXPANDED_APP" ]]; then
  echo "Zip did not expand to $EXPANDED_APP" >&2
  exit 1
fi

plutil -lint "$EXPANDED_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$EXPANDED_APP/Contents/Info.plist" | grep -qx "app.clipdock.ClipDock"
/usr/libexec/PlistBuddy -c "Print :LSUIElement" "$EXPANDED_APP/Contents/Info.plist" | grep -qx "true"
test -f "$EXPANDED_APP/Contents/Resources/AppIcon.icns"
codesign --verify --deep --strict --verbose=2 "$EXPANDED_APP"
"$ROOT_DIR/Scripts/runtime-clipboard-qa.sh"

SMOKE_STORAGE="$(mktemp -d "${TMPDIR:-/tmp}/clipdock-smoke-storage.XXXXXX")"
CLIPDOCK_STORAGE_DIR="$SMOKE_STORAGE" "$APP_PATH/Contents/MacOS/$APP_NAME" >/tmp/clipdock-smoke-app.log 2>&1 &
APP_PID="$!"
sleep 2
kill "$APP_PID" 2>/dev/null || true
wait "$APP_PID" 2>/dev/null || true
sleep 1
rm -rf "$SMOKE_STORAGE"

if kill -0 "$APP_PID" 2>/dev/null; then
  echo "$APP_NAME smoke process is still running after quit request" >&2
  cat /tmp/clipdock-smoke-app.log >&2 || true
  exit 1
fi

echo "Smoke QA passed: $ZIP_PATH"
