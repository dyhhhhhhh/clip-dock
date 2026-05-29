#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ClipDock"
VERSION="${VERSION:-0.1.0}"
BUILD_DIR="$ROOT_DIR/.build"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/${APP_NAME}-${VERSION}-macOS.zip"
NOTARIZE="${NOTARIZE:-0}"

mkdir -p "$DIST_DIR"

"$ROOT_DIR/Scripts/build-app.sh" >/tmp/clipdock-build-app.log
APP_PATH="$APP_PATH" "$ROOT_DIR/Scripts/sign-app.sh"

rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

if [[ "$NOTARIZE" == "1" ]]; then
  if [[ -z "${NOTARY_APPLE_ID:-}" || -z "${NOTARY_TEAM_ID:-}" || -z "${NOTARY_PASSWORD:-}" ]]; then
    echo "NOTARIZE=1 requires NOTARY_APPLE_ID, NOTARY_TEAM_ID, and NOTARY_PASSWORD." >&2
    exit 1
  fi

  xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$NOTARY_APPLE_ID" \
    --team-id "$NOTARY_TEAM_ID" \
    --password "$NOTARY_PASSWORD" \
    --wait

  xcrun stapler staple "$APP_PATH"
  xcrun stapler validate "$APP_PATH"

  rm -f "$ZIP_PATH"
  ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose=2 "$APP_PATH" || true

echo "$ZIP_PATH"
