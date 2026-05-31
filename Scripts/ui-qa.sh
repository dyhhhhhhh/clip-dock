#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ClipDock"
APP_PATH="$ROOT_DIR/.build/$APP_NAME.app"
RUN_HOME="$(mktemp -d "${TMPDIR:-/tmp}/clipdock-ui-qa.XXXXXX")"
RUN_STORAGE="$RUN_HOME/ClipDockStorage"
RUN_SETTINGS_SUITE="ClipDockUITests.$(uuidgen)"
RUN_PASTE_MARKER="$RUN_HOME/AutoPasteMarker.txt"
RESULT_DIR="$ROOT_DIR/.build/ui-qa"
LOG_PATH="$RESULT_DIR/ClipDockUIQARunner.log"
RUN_CONFIG="$RESULT_DIR/ClipDockUITests.env.json"
QA_CASE="all"

cleanup() {
  pkill -x "$APP_NAME" 2>/dev/null || true
  defaults delete "$RUN_SETTINGS_SUITE" 2>/dev/null || true
  rm -f "$RUN_CONFIG"
  rm -rf "$RUN_HOME"
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage: Scripts/ui-qa.sh [--case all|launcher|menu|history|settings]

Runs real ClipDock UI QA through ClipDockUIQARunner.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --case)
      if [[ $# -lt 2 ]]; then
        echo "--case requires a value." >&2
        usage >&2
        exit 64
      fi
      QA_CASE="$2"
      shift 2
      ;;
    --case=*)
      QA_CASE="${1#--case=}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

case "$QA_CASE" in
  all|launcher|menu|history|settings) ;;
  *)
    echo "Unknown UI QA case: $QA_CASE" >&2
    usage >&2
    exit 64
    ;;
esac

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
cat >"$RUN_CONFIG" <<EOF
{
  "CLIPDOCK_RUN_UI_TESTS": "1",
  "CLIPDOCK_UI_TEST_MODE": "1",
  "CLIPDOCK_UI_QA_CASE": "$QA_CASE",
  "CLIPDOCK_UI_QA_PASTE_MARKER": "$RUN_PASTE_MARKER",
  "CLIPDOCK_APP_PATH": "$APP_PATH",
  "CLIPDOCK_STORAGE_DIR": "$RUN_STORAGE",
  "CLIPDOCK_SETTINGS_SUITE": "$RUN_SETTINGS_SUITE"
}
EOF

"$ROOT_DIR/Scripts/package-release.sh" >/tmp/clipdock-ui-package-release.log

swift run ClipDockUIQARunner "$RUN_CONFIG" | tee "$LOG_PATH"

echo "UI QA passed ($QA_CASE): $LOG_PATH"
