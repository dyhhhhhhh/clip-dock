#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
SIGN_APP="${SIGN_APP:-1}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
APP_NAME="ClipDock"
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SOURCE_BINARY="$BUILD_DIR/$CONFIGURATION/$APP_NAME"
ICONSET_DIR="$ROOT_DIR/Packaging/Assets/AppIcon.iconset"
ICON_FILE="$ROOT_DIR/Packaging/Assets/AppIcon.icns"

cd "$ROOT_DIR"

swift Scripts/generate-icon.swift
iconutil -c icns "$ICONSET_DIR" -o "$ICON_FILE"
swift build -c "$CONFIGURATION"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$SOURCE_BINARY" "$MACOS_DIR/$APP_NAME"
chmod 755 "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ICON_FILE" "$RESOURCES_DIR/AppIcon.icns"
printf "APPL????" > "$CONTENTS_DIR/PkgInfo"

if [[ "$SIGN_APP" != "0" ]]; then
  if [[ -z "$SIGN_IDENTITY" ]]; then
    SIGN_IDENTITY="$(
      security find-identity -v -p codesigning 2>/dev/null \
        | awk -F '"' '/"Apple Development:|Developer ID Application:|Mac Developer:/{ print $2; exit }'
    )"
  fi
  SIGN_IDENTITY="${SIGN_IDENTITY:--}"
  codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP_DIR" >&2
  codesign --verify --deep --strict --verbose=2 "$APP_DIR" >&2
fi

echo "$APP_DIR"
