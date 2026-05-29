#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${APP_PATH:-$ROOT_DIR/.build/ClipDock.app}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(
    security find-identity -v -p codesigning 2>/dev/null \
      | awk -F '"' '/"Apple Development:|Developer ID Application:|Mac Developer:/{ print $2; exit }'
  )"
fi
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  echo "Run Scripts/build-app.sh first." >&2
  exit 1
fi

codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "Signed and verified: $APP_PATH"
