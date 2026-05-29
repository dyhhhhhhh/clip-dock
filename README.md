# ClipDock

ClipDock is a local-first macOS clipboard manager focused on privacy-safe capture, searchable history, and quick restoration from the menu bar or launcher.

## Requirements

- macOS 14 or later
- Xcode 26.5 or compatible Swift toolchain
- Swift 6.3

## Build And Test

```bash
swift test
swift build
```

## Build The App Bundle

```bash
Scripts/build-app.sh
open .build/ClipDock.app
```

The app bundle is generated at:

```text
.build/ClipDock.app
```

## Sign And Package

Default local packaging uses ad-hoc signing:

```bash
Scripts/package-release.sh
```

The release zip is generated at:

```text
dist/ClipDock-0.1.0-macOS.zip
```

For Developer ID signing, pass a signing identity:

```bash
SIGN_IDENTITY="Developer ID Application: Example, Inc. (TEAMID)" Scripts/sign-app.sh
```

For notarization, provide Apple notarization credentials:

```bash
SIGN_IDENTITY="Developer ID Application: Example, Inc. (TEAMID)" \
NOTARIZE=1 \
NOTARY_APPLE_ID="apple-id@example.com" \
NOTARY_TEAM_ID="TEAMID" \
NOTARY_PASSWORD="app-specific-password" \
Scripts/package-release.sh
```

## Smoke QA

Run the automated smoke gate:

```bash
Scripts/smoke-qa.sh
```

This runs tests, packages the app, expands the zip, verifies bundle metadata and code signing, runs an isolated clipboard capture/privacy check, launches the app, asks it to quit, and checks that no process remains.

To run only the runtime clipboard check:

```bash
Scripts/runtime-clipboard-qa.sh
```

The runtime check uses a temporary HOME directory for ClipDock storage, writes a safe text value to the system clipboard, verifies persistence, writes a sensitive API-key-like value, verifies it is ignored, then restores the previous text clipboard value.

For isolated local runs, set `CLIPDOCK_STORAGE_DIR`:

```bash
CLIPDOCK_STORAGE_DIR=/tmp/clipdock-storage .build/ClipDock.app/Contents/MacOS/ClipDock
```

## Manual QA

Use [Docs/MANUAL_QA.md](Docs/MANUAL_QA.md) for the real UI checklist. The manual pass is still required for menu bar interactions, global shortcut behavior, permissions, and login item behavior.

## Privacy Defaults

- Sensitive text is ignored by default.
- Recording can be paused.
- Auto paste is disabled by default.
- Startup does not restore the last clipboard item by default.
- Clipboard history is stored locally.
