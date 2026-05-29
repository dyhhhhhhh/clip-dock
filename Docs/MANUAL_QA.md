# ClipDock Manual QA Checklist

Use this checklist on macOS 14 or later after running:

```bash
Scripts/package-release.sh
open .build/ClipDock.app
```

## Automated UI QA

Real UI click checks are opt-in because macOS requires Accessibility permission.

```bash
Scripts/ui-qa.sh
```

The script runs Xcode UI tests, clicks the menu bar UI, opens Settings, Main Window, and Launcher, and writes screenshots to:

```text
.build/ui-qa/ClipDockUITests.xcresult
```

If the script reports missing Accessibility permission, enable the terminal app, Codex, or Xcode in System Settings > Privacy & Security > Accessibility, then run the script again.

## Launch And Menu Bar

- ClipDock launches without showing a Dock icon.
- ClipDock menu bar icon appears.
- Clicking the menu bar icon opens the ClipDock menu.
- Recent history area renders without layout overlap when empty.
- Open main window works from the menu.
- Open Launcher works from the menu.
- Settings opens from the menu.
- Quit ClipDock works from the menu and all ClipDock processes exit.

## Clipboard Capture

- Copy normal text in another app; it appears in recent history.
- Copy a URL; it is classified as a link.
- Copy a file from Finder; it is represented as a file URL/reference, not copied as file content.
- Copy an image; image metadata appears when image saving is enabled.
- Toggle pause recording; new clipboard changes are not captured.
- Resume recording; new allowed clipboard changes are captured again.

## Privacy

- Copy a value containing `api_key = sk_live_1234567890abcdef`; it is ignored.
- Copy a PEM private key block; it is ignored.
- Copy an OTP-style phrase such as `OTP code 123456`; it is ignored.
- Add an app bundle identifier to the ignore list; clipboard changes from that source are ignored.
- Debug or UI messages do not show ignored sensitive content.

## History Actions

- Search filters visible history.
- Type filters show only matching item types.
- Restore selected item copies it back to the system clipboard.
- Pin and unpin updates the row state.
- Delete removes one item.
- Clear history asks for confirmation before deleting all items.

## Settings Persistence

- Change history limits and privacy toggles.
- Quit and reopen ClipDock.
- Settings remain as configured.
- History remains visible after relaunch.
- ClipDock does not overwrite the system clipboard on startup.

## Launcher

- Press Command-Shift-V while ClipDock is running.
- Launcher opens or, if permissions prevent it, the app does not crash.
- Settings > General shows the global shortcut status.
- Requesting shortcut permission opens or prompts for Accessibility access.
- Search in Launcher filters rows.
- Up and Down move the selected row without using the mouse.
- Enter restores the selected item.
- Space toggles the selected item preview.
- Escape closes the preview.
- Command-D deletes the selected item while Launcher has focus.
- Command-P toggles pin for the selected item while Launcher has focus.

## Packaging

- `Scripts/package-release.sh` creates `dist/ClipDock-0.1.0-macOS.zip`.
- The zip expands to `ClipDock.app`.
- `codesign --verify --deep --strict .build/ClipDock.app` succeeds.
- If notarized with `NOTARIZE=1`, `xcrun stapler validate .build/ClipDock.app` succeeds.
