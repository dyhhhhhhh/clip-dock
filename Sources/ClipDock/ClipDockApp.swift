import AppKit
import SwiftUI

@main
struct ClipDockApp: App {
    @StateObject private var appState = AppState.live()

    init() {
        SingleInstanceController.activateExistingInstanceIfNeeded()
    }

    var body: some Scene {
        MenuBarExtra("ClipDock", systemImage: "doc.on.clipboard") {
            MenuBarContentView()
                .environmentObject(appState)
                .frame(width: 360)
        }
        .menuBarExtraStyle(.window)

        Window("ClipDock", id: "history") {
            HistoryWindowView()
                .environmentObject(appState)
                .frame(
                    minWidth: HistoryWindowMetrics.windowMinWidth,
                    idealWidth: HistoryWindowMetrics.windowIdealWidth,
                    minHeight: HistoryWindowMetrics.windowMinHeight,
                )
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .frame(width: 640, height: 620)
        }
        .commands {
            CommandMenu("ClipDock") {
                Button("打开 Launcher") {
                    appState.openLauncher()
                }
                Button("恢复选中项") {
                    appState.restore(appState.selectedClip(in: appState.historyVisibleClips))
                }
                .keyboardShortcut(.return, modifiers: [])
                Button("删除选中项") {
                    appState.delete(appState.selectedClip(in: appState.historyVisibleClips))
                }
                .keyboardShortcut("d", modifiers: [.command])
                Button("收藏/取消收藏") {
                    appState.toggleFavorite(appState.selectedClip(in: appState.historyVisibleClips))
                }
                .keyboardShortcut("p", modifiers: [.command])
                Divider()
                Button("退出 ClipDock") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: [.command])
            }
        }
    }
}

private enum SingleInstanceController {
    static func activateExistingInstanceIfNeeded() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        let currentPID = ProcessInfo.processInfo.processIdentifier
        guard let existing = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first(where: { $0.processIdentifier != currentPID })
        else {
            return
        }

        DispatchQueue.main.async {
            existing.activate()
            NSApp.terminate(nil)
        }
    }
}
