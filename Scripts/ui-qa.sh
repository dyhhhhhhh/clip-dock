#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ClipDock"
APP_PATH="$ROOT_DIR/.build/$APP_NAME.app"
RUN_HOME="$(mktemp -d "${TMPDIR:-/tmp}/clipdock-ui-qa.XXXXXX")"
RUN_STORAGE="$RUN_HOME/ClipDockStorage"
RESULT_DIR="$ROOT_DIR/.build/ui-qa"
RESULT_BUNDLE="$RESULT_DIR/ClipDockUITests.xcresult"
LOG_PATH="$RESULT_DIR/ClipDockUITests.log"

cleanup() {
  pkill -x "$APP_NAME" 2>/dev/null || true
  rm -rf "$RUN_HOME"
}
trap cleanup EXIT

cd "$ROOT_DIR"

ACCESSIBILITY_ENABLED="$(osascript -e 'tell application "System Events" to get UI elements enabled' 2>/dev/null || echo false)"
if [[ "$ACCESSIBILITY_ENABLED" != "true" ]]; then
  cat >&2 <<'EOF'
ClipDock UI QA requires Accessibility permission for the app running this script.

Enable it in:
System Settings > Privacy & Security > Accessibility

Add/enable the terminal app, Codex, or Xcode process that runs Scripts/ui-qa.sh,
then run:
  Scripts/ui-qa.sh
EOF
  exit 2
fi

pkill -x "$APP_NAME" 2>/dev/null || true
mkdir -p "$RESULT_DIR"
rm -rf "$RESULT_BUNDLE"

"$ROOT_DIR/Scripts/package-release.sh" >/tmp/clipdock-ui-package-release.log

CLIPDOCK_RUN_UI_TESTS=1 \
CLIPDOCK_APP_PATH="$APP_PATH" \
CLIPDOCK_STORAGE_DIR="$RUN_STORAGE" \
xcodebuild test \
  -scheme "$APP_NAME-Package" \
  -destination "platform=macOS" \
  -only-testing:ClipDockUITests \
  -resultBundlePath "$RESULT_BUNDLE" \
  | tee "$LOG_PATH"

if [[ ! -d "$RESULT_BUNDLE" ]]; then
  echo "Missing UI test result bundle: $RESULT_BUNDLE" >&2
  exit 1
fi

echo "UI QA passed: $RESULT_BUNDLE"
