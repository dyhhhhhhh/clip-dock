import AppKit
import SwiftUI

@main
struct ClipDockApp: App {
    @NSApplicationDelegateAdaptor(ClipDockApplicationDelegate.self) private var appDelegate
    @StateObject private var appState: AppState

    init() {
        let appState = AppState.live()
        _appState = StateObject(wrappedValue: appState)
        ClipDockApplicationDelegate.appState = appState
        SingleInstanceController.activateExistingInstanceIfNeeded()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appState)
                .frame(width: 360)
        } label: {
            ClipDockMenuBarLabel()
                .environmentObject(appState)
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

private final class ClipDockApplicationDelegate: NSObject, NSApplicationDelegate {
    static var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["CLIPDOCK_UI_TEST_MODE"] == "1" else { return }
        Task { @MainActor in
            guard let appState = Self.appState else { return }
            UITestMenuWindowController.open(appState: appState)
        }
    }
}

private struct ClipDockMenuBarLabel: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if let image = ClipDockMenuBarIcon.image {
                Image(nsImage: image)
            } else {
                Image(systemName: "doc.on.clipboard")
            }
        }
        .accessibilityLabel("ClipDock")
        .accessibilityIdentifier("clipdock.menuBar.item")
        .background(UITestMenuWindowBootstrap().environmentObject(appState))
    }
}

private struct UITestMenuWindowBootstrap: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                guard ProcessInfo.processInfo.environment["CLIPDOCK_UI_TEST_MODE"] == "1" else { return }
                UITestMenuWindowController.open(appState: appState)
            }
    }
}

@MainActor
private enum UITestMenuWindowController {
    private static var window: NSWindow?

    static func open(appState: AppState) {
        guard window == nil else { return }
        let hostingView = NSHostingView(
            rootView: MenuBarContentView(actions: UITestWindowController.menuActions(appState: appState))
                .environmentObject(appState)
                .frame(width: 360)
        )
        let qaWindow = NSWindow(
            contentRect: NSRect(x: 180, y: 180, width: 380, height: 620),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false,
        )
        qaWindow.title = "ClipDock UI QA"
        qaWindow.contentView = hostingView
        qaWindow.isReleasedWhenClosed = false
        qaWindow.makeKeyAndOrderFront(nil)
        NSApp.activate()
        window = qaWindow
    }
}

@MainActor
private enum UITestWindowController {
    private static var historyWindow: NSWindow?
    private static var settingsWindow: NSWindow?

    static func menuActions(appState: AppState) -> MenuBarContentActions {
        MenuBarContentActions(
            dismiss: {},
            openHistory: {
                openHistory(appState: appState)
            },
            openLauncher: {
                appState.openLauncher(enableTransientDismissal: false)
            },
            openSettings: {
                openSettings(appState: appState)
            },
        )
    }

    private static func openHistory(appState: AppState) {
        if let historyWindow {
            historyWindow.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let hostingView = NSHostingView(
            rootView: HistoryWindowView()
                .environmentObject(appState)
                .frame(
                    minWidth: HistoryWindowMetrics.windowMinWidth,
                    idealWidth: HistoryWindowMetrics.windowIdealWidth,
                    minHeight: HistoryWindowMetrics.windowMinHeight,
                ),
        )
        let window = makeWindow(
            title: "ClipDock",
            contentRect: NSRect(
                x: 220,
                y: 180,
                width: HistoryWindowMetrics.windowIdealWidth,
                height: 660,
            ),
            contentView: hostingView,
        )
        historyWindow = window
    }

    private static func openSettings(appState: AppState) {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let hostingView = NSHostingView(
            rootView: SettingsView()
                .environmentObject(appState)
                .frame(width: 640, height: 620),
        )
        let window = makeWindow(
            title: "ClipDock Settings",
            contentRect: NSRect(x: 260, y: 160, width: 660, height: 660),
            contentView: hostingView,
        )
        settingsWindow = window
    }

    private static func makeWindow(title: String, contentRect: NSRect, contentView: NSView) -> NSWindow {
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false,
        )
        window.title = title
        window.contentView = contentView
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        return window
    }
}

private enum ClipDockMenuBarIcon {
    static let image: NSImage? = {
        guard let url = Bundle.main.url(forResource: "MenuBarIconStatusTemplate", withExtension: "png"),
              let image = NSImage(contentsOf: url)
        else {
            return nil
        }
        image.isTemplate = true
        image.size = NSSize(width: 19, height: 19)
        return image
    }()
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
