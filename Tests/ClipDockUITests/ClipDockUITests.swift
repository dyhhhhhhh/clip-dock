import AppKit
import ApplicationServices
import ClipDockCore
import XCTest

final class ClipDockUITests: XCTestCase {
    private let bundleIdentifier = "app.clipdock.ClipDock"
    private var appProcess: Process?
    private var app: XCUIApplication!
    private var appEnvironment: [String: String] = [:]
    private var settingsSuiteName: String?
    private var storageDirectory: URL?
    private var pasteboardSnapshot: SystemPasteboardSnapshot?

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false

        let configuration = try UITestConfiguration.load()
        var environment = configuration.environment
        let storageDirectory = uiTestStorageDirectory(from: environment)
        let settingsSuiteName = environment["CLIPDOCK_SETTINGS_SUITE"].flatMap { $0.isEmpty ? nil : $0 }
            ?? "ClipDockUITests.\(UUID().uuidString)"
        environment["CLIPDOCK_STORAGE_DIR"] = storageDirectory.path
        environment["CLIPDOCK_SETTINGS_SUITE"] = settingsSuiteName
        environment["CLIPDOCK_UI_TEST_MODE"] = "1"

        self.storageDirectory = storageDirectory
        self.settingsSuiteName = settingsSuiteName
        appEnvironment = environment
        pasteboardSnapshot = SystemPasteboardSnapshot.capture()

        try resetSettingsSuite(settingsSuiteName, environment: environment)
        try seedStorage(at: storageDirectory)
        terminateRunningClipDock()
        try launchClipDock()
    }

    override func tearDownWithError() throws {
        appProcess?.terminate()
        appProcess = nil
        terminateRunningClipDock()
        pasteboardSnapshot?.restore()
        pasteboardSnapshot = nil
        if let settingsSuiteName {
            UserDefaults.standard.removePersistentDomain(forName: settingsSuiteName)
        }
        if let storageDirectory {
            try? FileManager.default.removeItem(at: storageDirectory)
        }
        storageDirectory = nil
        settingsSuiteName = nil
        appEnvironment = [:]
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

    func testMenuRecentListShowsSeededRowsAndHoverActions() throws {
        try openMenuBarPanel()

        let textRow = app.descendant(UISeed.menuRowID(UISeed.textID))
        let fileRow = app.descendant(UISeed.menuRowID(UISeed.fileID))
        assertExists(textRow, "Menu should show seeded text row.")
        assertExists(fileRow, "Menu should show seeded file row.")

        hover(fileRow)
        assertExists(
            app.descendant(UISeed.menuButtonID(UISeed.fileID, suffix: "finder")),
            "File rows should expose Finder action on hover.",
        )
        attachScreenshot(named: "08-menu-seeded-hover")
    }

    func testHistoryClickSelectsRowShowsDetailAndFavoriteAction() throws {
        try openMenuBarPanel()
        app.descendant("clipdock.menu.openHistory").click()

        let textRow = app.descendant(UISeed.historyRowID(UISeed.textID))
        assertExists(textRow, "History should show seeded text row.")
        textRow.click()
        assertExists(app.descendant("clipdock.history.detailPane"), "Clicking a history row should show its detail pane.")

        hover(textRow)
        let favoriteButton = app.descendant(UISeed.historyButtonID(UISeed.textID, suffix: "favorite"))
        assertExists(favoriteButton, "History row should expose favorite action on hover.")
        favoriteButton.click()
        attachScreenshot(named: "09-history-row-action")
    }

    func testLauncherMouseDoubleClickAndKeyboardCommands() throws {
        try openMenuBarPanel()
        app.descendant("clipdock.menu.openLauncher").click()
        assertExists(app.descendant("clipdock.launcher.root"), "Launcher should open.")

        let textRow = app.descendant(UISeed.launcherRowID(UISeed.textID))
        assertExists(textRow, "Launcher should show seeded text row.")
        textRow.click()

        app.typeKey(.space, modifierFlags: [])
        assertExists(app.descendant("clipdock.launcher.preview"), "Space should open the Launcher preview.")

        app.typeKey("p", modifierFlags: [.command])
        hover(textRow)
        let favoriteButton = app.descendant(UISeed.launcherButtonID(UISeed.textID, suffix: "favorite"))
        assertExists(favoriteButton, "Command-P should keep the row actionable after toggling favorite.")
        XCTAssertEqual(favoriteButton.label, "取消收藏")

        textRow.doubleClick()
        XCTAssertFalse(
            app.descendant("clipdock.launcher.root").waitForExistence(timeout: 1),
            "Double-click restore should close the Launcher.",
        )
    }

    func testSettingsTabsAndKeyControlsUseIsolatedSuite() throws {
        try openMenuBarPanel()
        app.descendant("clipdock.menu.openSettings").click()
        assertExists(app.descendant("clipdock.settings.root"), "Settings window should open.")

        app.descendant("clipdock.settings.tab.history").click()
        let saveImagesToggle = app.descendant("clipdock.settings.history.saveImages")
        assertExists(saveImagesToggle, "History settings should expose save-images toggle.")
        saveImagesToggle.click()

        app.descendant("clipdock.settings.tab.privacy").click()
        let recordingToggle = app.descendant("clipdock.settings.privacy.recordingPaused")
        assertExists(recordingToggle, "Privacy settings should expose recording pause toggle.")
        recordingToggle.click()
        attachScreenshot(named: "10-settings-key-controls")
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
        let environment = appEnvironment.isEmpty ? ProcessInfo.processInfo.environment : appEnvironment
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

    private func uiTestStorageDirectory(from environment: [String: String]) -> URL {
        if let override = environment["CLIPDOCK_STORAGE_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipDockUITests-\(UUID().uuidString)", isDirectory: true)
    }

    private func resetSettingsSuite(_ suiteName: String, environment: [String: String]) throws {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        var settings = UserSettings.defaults
        settings.recordingPaused = false
        settings.autoPasteEnabled = false
        settings.restoreLastClipboardOnStartup = false
        settings.ignoredBundleIdentifiers = []
        UserDefaultsSettingsStore.configured(environment: environment).save(settings)
    }

    private func seedStorage(at directory: URL) throws {
        try FileManager.default.removeItemIfExists(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let payloadStore = try PayloadStore(directory: directory.appendingPathComponent("Payloads", isDirectory: true))
        let repository = try SQLiteClipRepository(directory: directory, payloadStore: payloadStore)
        try repository.clear()

        let fixtureDirectory = directory.appendingPathComponent("FixtureFiles", isDirectory: true)
        try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
        let fileURL = fixtureDirectory.appendingPathComponent("UI Fixture.txt")
        try "ClipDock UI file fixture".write(to: fileURL, atomically: true, encoding: .utf8)

        let imageData = Data(base64Encoded: UISeed.imageBase64)!
        let imagePayloadRef = try XCTUnwrap(
            payloadStore.saveImagePayload(imageData, contentHash: UISeed.imageContentHash, settings: .defaults),
        )

        for item in UISeed.items(fileURL: fileURL, imagePayloadRef: imagePayloadRef, imageByteCount: imageData.count) {
            try repository.upsert(item)
        }
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

    private func hover(_ element: XCUIElement) {
        let frame = element.frame
        let point = CGPoint(x: frame.midX, y: frame.midY)
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?
            .post(tap: .cghidEventTap)
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
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

private enum UISeed {
    static let textID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    static let urlID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
    static let imageID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
    static let fileID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
    static let imageContentHash = "ui-seed-image"
    static let imageBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
    private static let sourceApp = SourceAppMetadata(name: "ClipDock UI Seed", bundleIdentifier: "app.clipdock.tests")
    private static let baseDate = Date(timeIntervalSince1970: 1_800_000_000)

    static func items(fileURL: URL, imagePayloadRef: String, imageByteCount: Int) -> [ClipItem] {
        var image = item(
            id: imageID,
            contentHash: imageContentHash,
            primaryType: .image,
            capturedAt: baseDate.addingTimeInterval(20),
            previewText: "UI Seed Image",
            payload: .image(ImagePayload(byteCount: imageByteCount, width: 1, height: 1)),
            byteSize: imageByteCount,
        )
        image.payloadRef = imagePayloadRef

        return [
            item(
                id: textID,
                contentHash: "ui-seed-text",
                primaryType: .text,
                capturedAt: baseDate.addingTimeInterval(40),
                previewText: "UI Seed Text - click and keyboard target",
                payload: .text("UI Seed Text - click and keyboard target"),
            ),
            item(
                id: urlID,
                contentHash: "ui-seed-url",
                primaryType: .url,
                capturedAt: baseDate.addingTimeInterval(30),
                isFavorite: true,
                previewText: "https://clipdock.app/ui-seed",
                payload: .url("https://clipdock.app/ui-seed"),
            ),
            image,
            item(
                id: fileID,
                contentHash: "ui-seed-file",
                primaryType: .file,
                capturedAt: baseDate.addingTimeInterval(10),
                previewText: fileURL.path,
                payload: .fileURL(fileURL.path),
                byteSize: fileURL.path.utf8.count,
            ),
        ]
    }

    static func menuRowID(_ id: UUID) -> String { "clipdock.menu.recent.row.\(id.uuidString)" }
    static func historyRowID(_ id: UUID) -> String { "clipdock.history.row.\(id.uuidString)" }
    static func launcherRowID(_ id: UUID) -> String { "clipdock.launcher.row.\(id.uuidString)" }
    static func menuButtonID(_ id: UUID, suffix: String) -> String { "\(menuRowID(id)).\(suffix)" }
    static func historyButtonID(_ id: UUID, suffix: String) -> String { "\(historyRowID(id)).\(suffix)" }
    static func launcherButtonID(_ id: UUID, suffix: String) -> String { "\(launcherRowID(id)).\(suffix)" }

    private static func item(
        id: UUID,
        contentHash: String,
        primaryType: ClipType,
        capturedAt: Date,
        isFavorite: Bool = false,
        previewText: String,
        payload: ClipPayload,
        byteSize: Int? = nil,
    ) -> ClipItem {
        ClipItem(
            id: id,
            contentHash: contentHash,
            primaryType: primaryType,
            capturedAt: capturedAt,
            lastUsedAt: nil,
            useCount: 0,
            isFavorite: isFavorite,
            previewText: previewText,
            payload: payload,
            sourceApp: sourceApp,
            byteSize: byteSize ?? previewText.utf8.count,
        )
    }
}

private struct UITestConfiguration {
    let environment: [String: String]

    static func load() throws -> UITestConfiguration {
        let processEnvironment = ProcessInfo.processInfo.environment
        if processEnvironment["CLIPDOCK_RUN_UI_TESTS"] == "1" {
            return UITestConfiguration(environment: processEnvironment)
        }

        let configURL = repositoryRoot()
            .appendingPathComponent(".build/ui-qa/ClipDockUITests.env.json")
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            throw XCTSkip("Set CLIPDOCK_RUN_UI_TESTS=1 or run Scripts/ui-qa.sh to execute real UI tests.")
        }

        let data = try Data(contentsOf: configURL)
        let fileEnvironment = try JSONDecoder().decode([String: String].self, from: data)
        guard fileEnvironment["CLIPDOCK_RUN_UI_TESTS"] == "1" else {
            throw XCTSkip("Set CLIPDOCK_RUN_UI_TESTS=1 or run Scripts/ui-qa.sh to execute real UI tests.")
        }

        return UITestConfiguration(
            environment: processEnvironment.merging(fileEnvironment) { _, fileValue in fileValue },
        )
    }

    private static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct SystemPasteboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]

    static func capture(from pasteboard: NSPasteboard = .general) -> SystemPasteboardSnapshot {
        let items: [[NSPasteboard.PasteboardType: Data]] = pasteboard.pasteboardItems?.map { item in
            var dataByType: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dataByType[type] = data
                }
            }
            return dataByType
        } ?? []
        return SystemPasteboardSnapshot(items: items)
    }

    func restore(to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }

        let pasteboardItems = items.map { dataByType in
            let item = NSPasteboardItem()
            for (type, data) in dataByType {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(pasteboardItems)
    }
}

private extension FileManager {
    func removeItemIfExists(at url: URL) throws {
        guard fileExists(atPath: url.path) else { return }
        try removeItem(at: url)
    }
}

private extension XCUIApplication {
    func descendant(_ identifier: String) -> XCUIElement {
        descendants(matching: .any)[identifier]
    }
}
