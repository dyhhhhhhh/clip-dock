#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ClipDock"
APP_BINARY="$ROOT_DIR/.build/$APP_NAME.app/Contents/MacOS/$APP_NAME"
RUN_HOME="$(mktemp -d "${TMPDIR:-/tmp}/clipdock-runtime-home.XXXXXX")"
RUN_STORAGE="$RUN_HOME/ClipDockStorage"
SAFE_TEXT="ClipDock runtime QA $(uuidgen)"
SENSITIVE_TEXT="api_key = sk_live_1234567890abcdef"
STORE_DB="$RUN_STORAGE/clips.sqlite"
ORIGINAL_TEXT="$(pbpaste 2>/dev/null || true)"
APP_PID=""

sql_string_literal() {
  local value="${1//\'/\'\'}"
  printf "'%s'" "$value"
}

cleanup() {
  if [[ -n "$APP_PID" ]] && kill -0 "$APP_PID" 2>/dev/null; then
    kill "$APP_PID" 2>/dev/null || true
    wait "$APP_PID" 2>/dev/null || true
  fi
  pkill -x "$APP_NAME" 2>/dev/null || true
  printf "%s" "$ORIGINAL_TEXT" | pbcopy || true
  rm -rf "$RUN_HOME"
}
trap cleanup EXIT

cd "$ROOT_DIR"

if [[ ! -x "$APP_BINARY" ]]; then
  "$ROOT_DIR/Scripts/build-app.sh" >/tmp/clipdock-runtime-build.log
fi

pkill -x "$APP_NAME" 2>/dev/null || true
sleep 1

CLIPDOCK_STORAGE_DIR="$RUN_STORAGE" "$APP_BINARY" >/tmp/clipdock-runtime-app.log 2>&1 &
APP_PID="$!"
sleep 1

printf "%s" "$SAFE_TEXT" | pbcopy

deadline=$((SECONDS + 10))
while [[ $SECONDS -lt $deadline ]]; do
  if [[ -f "$STORE_DB" ]] && [[ "$(sqlite3 "$STORE_DB" "SELECT COUNT(*) FROM clips WHERE preview_text = $(sql_string_literal "$SAFE_TEXT");")" != "0" ]]; then
    break
  fi
  sleep 0.5
done

if [[ ! -f "$STORE_DB" ]] || [[ "$(sqlite3 "$STORE_DB" "SELECT COUNT(*) FROM clips WHERE preview_text = $(sql_string_literal "$SAFE_TEXT");")" == "0" ]]; then
  echo "Safe clipboard text was not persisted." >&2
  echo "Expected store: $STORE_DB" >&2
  cat /tmp/clipdock-runtime-app.log >&2 || true
  exit 1
fi

printf "%s" "$SENSITIVE_TEXT" | pbcopy
sleep 2

if grep -Fq "$SENSITIVE_TEXT" "$STORE_DB"; then
  echo "Sensitive clipboard text was persisted unexpectedly." >&2
  exit 1
fi

echo "Runtime clipboard QA passed"
