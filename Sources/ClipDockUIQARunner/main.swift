import AppKit
import ApplicationServices
import ClipDockCore
import Foundation

@main
struct ClipDockUIQARunner {
    static func main() throws {
        let configURL = try configURL()
        let environment = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: configURL))
        guard environment["CLIPDOCK_RUN_UI_TESTS"] == "1" else {
            throw QAError("CLIPDOCK_RUN_UI_TESTS is not enabled in \(configURL.path)")
        }
        guard AXIsProcessTrusted() else {
            throw QAError("Accessibility permission is required for UI QA.")
        }

        let qaCase = try UIQACase.resolve(from: environment)
        let runner = Runner(environment: environment)
        try runner.run(qaCase)
        print("UI QA runner passed: \(qaCase.rawValue)")
    }

    private static func configURL() throws -> URL {
        if CommandLine.arguments.count > 1 {
            return URL(fileURLWithPath: CommandLine.arguments[1])
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build/ui-qa/ClipDockUITests.env.json")
    }
}

private final class Runner {
    private let environment: [String: String]
    private let bundleIdentifier = "app.clipdock.ClipDock"
    private var process: Process?
    private var pasteboardSnapshot: PasteboardSnapshot?

    init(environment: [String: String]) {
        self.environment = environment
    }

    func run(_ qaCase: UIQACase) throws {
        pasteboardSnapshot = PasteboardSnapshot.capture()
        defer {
            process?.terminate()
            terminateRunningClipDock()
            pasteboardSnapshot?.restore()
        }

        try seedStorage()
        terminateRunningClipDock()
        try launchClipDock()

        switch qaCase {
        case .all:
            try testMenuActionsAreReachable()
            try testMenuRecentListShowsSeededRowsAndHoverActions()
            try testHistoryWindowSmokeAndRowActions()
            try testLauncherMouseDoubleClickAndKeyboardCommands()
            try testSettingsTabsAndKeyControlsUseIsolatedSuite()
        case .launcher:
            try testLauncherMouseDoubleClickAndKeyboardCommands()
        case .menu:
            try testMenuActionsAreReachable()
            try testMenuRecentListShowsSeededRowsAndHoverActions()
        case .history:
            try testHistoryWindowSmokeAndRowActions()
        case .settings:
            try testSettingsTabsAndKeyControlsUseIsolatedSuite()
        }
    }

    private func testMenuActionsAreReachable() throws {
        try openMenuBarPanel()
        try require(identifier: "clipdock.menu.openSettings")
        try require(identifier: "clipdock.menu.openHistory")
        try require(identifier: "clipdock.menu.openLauncher")
    }

    private func testHistoryWindowSmokeAndRowActions() throws {
        try openMenuBarPanel()
        try click(identifier: "clipdock.menu.openHistory")
        try require(identifier: "clipdock.history.root", timeout: 6)
        try require(identifier: "clipdock.history.sidebar")
        try require(identifier: "clipdock.history.toolbar")
        try require(identifier: "clipdock.history.openSettings")
        try require(identifier: "clipdock.history.storageUsage")

        let textRow = try require(identifier: UISeed.historyRowID(UISeed.textID), timeout: 6)
        click(textRow)
        try require(identifier: "clipdock.history.detailPane")

        try resetAutoPasteMarker()
        doubleClick(textRow)
        try requireAutoPasteMarker(reason: "History row double-click should request auto-paste.")

        let refreshedTextRow = try require(identifier: UISeed.historyRowID(UISeed.textID), timeout: 6)
        click(refreshedTextRow)
        hover(refreshedTextRow)
        try click(identifier: UISeed.historyButtonID(UISeed.textID, suffix: "favorite"))
    }

    private func testMenuRecentListShowsSeededRowsAndHoverActions() throws {
        try openMenuBarPanel()
        try require(identifier: UISeed.menuRowID(UISeed.textID))
        let fileRow = try require(identifier: UISeed.menuRowID(UISeed.fileID))
        hover(fileRow)
        try require(identifier: UISeed.menuButtonID(UISeed.fileID, suffix: "finder"))
    }

    private func testLauncherMouseDoubleClickAndKeyboardCommands() throws {
        try openMenuBarPanel()
        try click(identifier: "clipdock.menu.openLauncher")
        try require(identifier: "clipdock.launcher.root", timeout: 6)
        try require(identifier: "clipdock.launcher.searchField")
        try require(identifier: "clipdock.launcher.filters")
        try require(identifier: "clipdock.launcher.footer")

        let textRow = try require(identifier: UISeed.launcherRowID(UISeed.textID), timeout: 6)
        click(textRow)

        pressKey(keyCode: 49)
        try require(identifier: "clipdock.launcher.preview")

        pressKey(keyCode: 35, flags: .maskCommand)
        hover(textRow)
        try require(identifier: UISeed.launcherButtonID(UISeed.textID, suffix: "favorite"))

        try resetAutoPasteMarker()
        doubleClick(textRow)
        try waitUntil(timeout: 3) {
            find(identifier: "clipdock.launcher.root") == nil
        }
        try requireAutoPasteMarker(reason: "Launcher row double-click should request auto-paste.")
    }

    private func testSettingsTabsAndKeyControlsUseIsolatedSuite() throws {
        try openMenuBarPanel()
        try click(identifier: "clipdock.menu.openSettings")
        try require(identifier: "clipdock.settings.root", timeout: 6)
        try require(identifier: "clipdock.settings.general.autoPasteStatus")

        try click(identifier: "clipdock.settings.tab.history")
        try click(identifier: "clipdock.settings.history.saveImages")

        try click(identifier: "clipdock.settings.tab.privacy")
        try click(identifier: "clipdock.settings.privacy.recordingPaused")
    }

    private func verifySettingsTabs() throws {
        for (tab, section) in [
            ("clipdock.settings.tab.general", "clipdock.settings.section.general"),
            ("clipdock.settings.tab.history", "clipdock.settings.section.history"),
            ("clipdock.settings.tab.privacy", "clipdock.settings.section.privacy"),
            ("clipdock.settings.tab.advanced", "clipdock.settings.section.advanced"),
        ] {
            try click(identifier: tab)
            try require(identifier: section)
        }
    }

    private func seedStorage() throws {
        guard let storagePath = environment["CLIPDOCK_STORAGE_DIR"], !storagePath.isEmpty else {
            throw QAError("Missing CLIPDOCK_STORAGE_DIR")
        }
        let directory = URL(fileURLWithPath: storagePath, isDirectory: true)
        try FileManager.default.removeItemIfExists(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let settingsSuite = environment["CLIPDOCK_SETTINGS_SUITE"] ?? "ClipDockUITests.\(UUID().uuidString)"
        UserDefaults.standard.removePersistentDomain(forName: settingsSuite)
        var settings = UserSettings.defaults
        settings.recordingPaused = false
        settings.autoPasteEnabled = false
        settings.defaultPasteBehavior = .restoreOnly
        settings.restoreLastClipboardOnStartup = false
        settings.ignoredBundleIdentifiers = []
        UserDefaultsSettingsStore.configured(environment: ["CLIPDOCK_SETTINGS_SUITE": settingsSuite]).save(settings)

        let payloadStore = try PayloadStore(directory: directory.appendingPathComponent("Payloads", isDirectory: true))
        let repository = try SQLiteClipRepository(directory: directory, payloadStore: payloadStore)
        try repository.clear()

        let fixtureDirectory = directory.appendingPathComponent("FixtureFiles", isDirectory: true)
        try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
        let fileURL = fixtureDirectory.appendingPathComponent("UI Fixture.txt")
        try "ClipDock UI file fixture".write(to: fileURL, atomically: true, encoding: .utf8)

        let imageData = Data(base64Encoded: UISeed.imageBase64)!
        guard let imagePayloadRef = try payloadStore.saveImagePayload(
            imageData,
            contentHash: UISeed.imageContentHash,
            settings: .defaults,
        ) else {
            throw QAError("Failed to seed image payload")
        }

        for item in UISeed.items(fileURL: fileURL, imagePayloadRef: imagePayloadRef, imageByteCount: imageData.count) {
            try repository.upsert(item)
        }
    }

    private func launchClipDock() throws {
        guard let appPath = environment["CLIPDOCK_APP_PATH"], !appPath.isEmpty else {
            throw QAError("Missing CLIPDOCK_APP_PATH")
        }
        let executablePath = "\(appPath)/Contents/MacOS/ClipDock"
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw QAError("ClipDock executable does not exist at \(executablePath)")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.environment = environment
        process.standardOutput = FileHandle(forWritingAtPath: "/dev/null")
        process.standardError = FileHandle(forWritingAtPath: "/dev/null")
        try process.run()
        self.process = process

        try waitUntil(timeout: 8) {
            !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
        }
    }

    private func terminateRunningClipDock() {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier) {
            app.terminate()
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
    }

    private func openMenuBarPanel() throws {
        if environment["CLIPDOCK_UI_TEST_MODE"] == "1" {
            raiseWindow(titled: "ClipDock UI QA")
            _ = try require(identifier: "clipdock.menu.panel", timeout: 6)
            return
        }
        if find(identifier: "clipdock.menu.panel") != nil { return }
        guard let item = findMenuBarItem() else {
            throw QAError("ClipDock menu bar item not found")
        }
        click(item)
        try require(identifier: "clipdock.menu.panel", timeout: 5)
    }

    private func raiseWindow(titled title: String) {
        guard let app = appElement(),
              let window = firstDescendant(of: app, maxDepth: 2, predicate: { element in
                  let role: String? = attribute(element, kAXRoleAttribute as CFString)
                  let windowTitle: String? = attribute(element, kAXTitleAttribute as CFString)
                  return role == kAXWindowRole as String && windowTitle == title
              })
        else {
            return
        }
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    }

    @discardableResult
    private func require(identifier: String, timeout: TimeInterval = 4) throws -> AXUIElement {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let element = find(identifier: identifier) {
                return element
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        throw QAError("Missing accessibility identifier: \(identifier)")
    }

    private func click(identifier: String) throws {
        click(try require(identifier: identifier))
    }

    private func click(_ element: AXUIElement) {
        let role: String? = attribute(element, kAXRoleAttribute as CFString)
        if [kAXButtonRole as String, kAXCheckBoxRole as String, kAXMenuItemRole as String].contains(role ?? ""),
           AXUIElementPerformAction(element, kAXPressAction as CFString) == .success {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            return
        }

        if let frame = frame(of: element) {
            click(at: CGPoint(x: frame.midX, y: frame.midY))
        } else {
            AXUIElementPerformAction(element, kAXPressAction as CFString)
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    }

    private func doubleClick(_ element: AXUIElement) {
        guard let frame = frame(of: element) else {
            click(element)
            click(element)
            return
        }
        let point = CGPoint(x: frame.midX, y: frame.midY)
        click(at: point, clickState: 1)
        RunLoop.current.run(until: Date().addingTimeInterval(0.08))
        click(at: point, clickState: 2)
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
    }

    private func hover(_ element: AXUIElement) {
        guard let frame = frame(of: element) else { return }
        let point = CGPoint(x: frame.midX, y: frame.midY)
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?
            .post(tap: .cghidEventTap)
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
    }

    private func click(at point: CGPoint, clickState: Int64 = 1) {
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?
            .post(tap: .cghidEventTap)
        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        down?.setIntegerValueField(.mouseEventClickState, value: clickState)
        up?.setIntegerValueField(.mouseEventClickState, value: clickState)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private func pressKey(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    }

    private func resetAutoPasteMarker() throws {
        guard let markerPath = environment["CLIPDOCK_UI_QA_PASTE_MARKER"] else { return }
        try FileManager.default.removeItemIfExists(at: URL(fileURLWithPath: markerPath))
    }

    private func requireAutoPasteMarker(reason: String) throws {
        guard let markerPath = environment["CLIPDOCK_UI_QA_PASTE_MARKER"] else {
            throw QAError("Missing CLIPDOCK_UI_QA_PASTE_MARKER. \(reason)")
        }
        try waitUntil(timeout: 3) {
            FileManager.default.fileExists(atPath: markerPath)
        }
    }

    private func find(identifier: String) -> AXUIElement? {
        guard let app = appElement() else { return nil }
        return firstDescendant(of: app, maxDepth: 10) { element in
            attribute(element, axIdentifierAttribute) == identifier
        }
    }

    private func appElement() -> AXUIElement? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            return nil
        }
        return AXUIElementCreateApplication(app.processIdentifier)
    }

    private func findMenuBarItem() -> AXUIElement? {
        guard let systemUIServer = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.systemuiserver")
            .first
        else {
            return nil
        }
        let root = AXUIElementCreateApplication(systemUIServer.processIdentifier)
        return firstDescendant(of: root, maxDepth: 8) { element in
            let role: String? = attribute(element, kAXRoleAttribute as CFString)
            guard role == kAXMenuBarItemRole as String else { return false }
            return searchableText(for: element).contains { $0.localizedCaseInsensitiveContains("ClipDock") }
        }
    }

    private func firstDescendant(
        of element: AXUIElement,
        maxDepth: Int,
        predicate: (AXUIElement) -> Bool,
    ) -> AXUIElement? {
        if predicate(element) { return element }
        guard maxDepth > 0 else { return nil }
        for child in children(of: element) {
            if let match = firstDescendant(of: child, maxDepth: maxDepth - 1, predicate: predicate) {
                return match
            }
        }
        return nil
    }

    private func searchableText(for element: AXUIElement) -> [String] {
        [
            attribute(element, axIdentifierAttribute),
            attribute(element, kAXTitleAttribute as CFString),
            attribute(element, kAXDescriptionAttribute as CFString),
            attribute(element, kAXHelpAttribute as CFString),
            attribute(element, kAXValueAttribute as CFString),
        ].compactMap { $0 as String? }
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let children = value as? [AXUIElement]
        else {
            return []
        }
        return children
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionAXValue = positionValue,
              let sizeAXValue = sizeValue
        else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionAXValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeAXValue as! AXValue, .cgSize, &size)
        else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private func attribute<T>(_ element: AXUIElement, _ name: CFString) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name, &value) == .success else { return nil }
        return value as? T
    }

    private func waitUntil(timeout: TimeInterval, condition: () -> Bool) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        throw QAError("Timed out after \(timeout) seconds")
    }
}

private enum UIQACase: String, CaseIterable {
    case all
    case launcher
    case menu
    case history
    case settings

    static func resolve(from environment: [String: String]) throws -> UIQACase {
        let rawValue = environment["CLIPDOCK_UI_QA_CASE"] ?? UIQACase.all.rawValue
        guard let qaCase = UIQACase(rawValue: rawValue) else {
            let supportedCases = UIQACase.allCases.map(\.rawValue).joined(separator: ", ")
            throw QAError("Unknown UI QA case '\(rawValue)'. Supported cases: \(supportedCases)")
        }
        return qaCase
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

private struct PasteboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]

    static func capture(from pasteboard: NSPasteboard = .general) -> PasteboardSnapshot {
        let items: [[NSPasteboard.PasteboardType: Data]] = pasteboard.pasteboardItems?.map { item in
            var dataByType: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dataByType[type] = data
                }
            }
            return dataByType
        } ?? []
        return PasteboardSnapshot(items: items)
    }

    func restore(to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        pasteboard.writeObjects(items.map { dataByType in
            let item = NSPasteboardItem()
            for (type, data) in dataByType {
                item.setData(data, forType: type)
            }
            return item
        })
    }
}

private extension FileManager {
    func removeItemIfExists(at url: URL) throws {
        guard fileExists(atPath: url.path) else { return }
        try removeItem(at: url)
    }
}

private let axIdentifierAttribute = "AXIdentifier" as CFString

struct QAError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
