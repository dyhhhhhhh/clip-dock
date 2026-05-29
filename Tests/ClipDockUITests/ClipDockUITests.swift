import AppKit
import ApplicationServices
import XCTest

final class ClipDockUITests: XCTestCase {
    private let bundleIdentifier = "app.clipdock.ClipDock"
    private var appProcess: Process?
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false

        guard ProcessInfo.processInfo.environment["CLIPDOCK_RUN_UI_TESTS"] == "1" else {
            throw XCTSkip("Set CLIPDOCK_RUN_UI_TESTS=1 or run Scripts/ui-qa.sh to execute real UI tests.")
        }
        guard AXIsProcessTrusted() else {
            throw XCTSkip("Accessibility permission is required for real UI tests.")
        }

        terminateRunningClipDock()
        try launchClipDock()
    }

    override func tearDownWithError() throws {
        appProcess?.terminate()
        appProcess = nil
        terminateRunningClipDock()
        app = nil
        try super.tearDownWithError()
    }

    func testMenuSettingsHistoryAndLauncherSmoke() throws {
        try openMenuBarPanel()
        assertExists(app.descendant("clipdock.menu.openSettings"), "Settings menu action should exist.")
        assertExists(app.descendant("clipdock.menu.openHistory"), "History menu action should exist.")
        assertExists(app.descendant("clipdock.menu.openLauncher"), "Launcher menu action should exist.")
        attachScreenshot(named: "01-menu-bar-panel")

        app.descendant("clipdock.menu.openSettings").click()
        assertExists(app.descendant("clipdock.settings.root"), "Settings window should open.")
        attachScreenshot(named: "02-settings-general")
        try verifySettingsTabs()

        try openMenuBarPanel()
        app.descendant("clipdock.menu.openHistory").click()
        assertExists(app.descendant("clipdock.history.root"), "History window should open.")
        assertExists(app.descendant("clipdock.history.sidebar"), "History sidebar should exist.")
        assertExists(app.descendant("clipdock.history.toolbar"), "History toolbar should exist.")
        assertExists(app.descendant("clipdock.history.openSettings"), "History sidebar should include a settings button.")
        assertExists(app.descendant("clipdock.history.storageUsage"), "History sidebar should show storage usage.")
        attachScreenshot(named: "06-history-window")

        try openMenuBarPanel()
        app.descendant("clipdock.menu.openLauncher").click()
        assertExists(app.descendant("clipdock.launcher.root"), "Launcher should open.")
        assertExists(app.descendant("clipdock.launcher.searchField"), "Launcher search field should exist.")
        assertExists(app.descendant("clipdock.launcher.filters"), "Launcher filter chips should exist.")
        assertExists(app.descendant("clipdock.launcher.footer"), "Launcher shortcut hints should exist.")
        attachScreenshot(named: "07-launcher")
    }

    private func verifySettingsTabs() throws {
        let tabs: [(identifier: String, section: String, screenshot: String)] = [
            ("clipdock.settings.tab.general", "clipdock.settings.section.general", "02-settings-general"),
            ("clipdock.settings.tab.history", "clipdock.settings.section.history", "03-settings-history"),
            ("clipdock.settings.tab.privacy", "clipdock.settings.section.privacy", "04-settings-privacy"),
            ("clipdock.settings.tab.advanced", "clipdock.settings.section.advanced", "05-settings-advanced"),
        ]

        for tab in tabs {
            let tabElement = app.descendant(tab.identifier)
            assertExists(tabElement, "Settings tab \(tab.identifier) should exist.")
            tabElement.click()
            assertExists(app.descendant(tab.section), "Settings section \(tab.section) should exist.")
            attachScreenshot(named: tab.screenshot)
        }
    }

    private func launchClipDock() throws {
        let environment = ProcessInfo.processInfo.environment
        let appPath = environment["CLIPDOCK_APP_PATH"] ?? "\(FileManager.default.currentDirectoryPath)/.build/ClipDock.app"
        let executablePath = "\(appPath)/Contents/MacOS/ClipDock"
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            XCTFail("ClipDock executable does not exist at \(executablePath).")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.environment = environment
        process.standardOutput = FileHandle(forWritingAtPath: "/dev/null")
        process.standardError = FileHandle(forWritingAtPath: "/dev/null")
        try process.run()
        appProcess = process

        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty {
                app = XCUIApplication(bundleIdentifier: bundleIdentifier)
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTFail("ClipDock did not start with bundle identifier \(bundleIdentifier).")
    }

    private func terminateRunningClipDock() {
        for runningApplication in NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier) {
            runningApplication.terminate()
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
    }

    private func openMenuBarPanel(file: StaticString = #filePath, line: UInt = #line) throws {
        let systemUIServer = XCUIApplication(bundleIdentifier: "com.apple.systemuiserver")
        let menuBarItem = systemUIServer
            .menuBars
            .descendants(matching: .menuBarItem)
            .matching(NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@", "ClipDock", "ClipDock"))
            .firstMatch

        assertExists(menuBarItem, "ClipDock menu bar item should exist.", file: file, line: line)
        menuBarItem.click()
        assertExists(app.descendant("clipdock.menu.panel"), "ClipDock menu panel should open.", file: file, line: line)
    }

    private func assertExists(
        _ element: XCUIElement,
        _ message: String,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) {
        if !element.waitForExistence(timeout: timeout) {
            attachScreenshot(named: "failure-\(UUID().uuidString)")
            XCTFail(message, file: file, line: line)
        }
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private extension XCUIApplication {
    func descendant(_ identifier: String) -> XCUIElement {
        descendants(matching: .any)[identifier]
    }
}
