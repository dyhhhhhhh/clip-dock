@testable import ClipDockCore
import AppKit
import XCTest

final class ClipboardTests: XCTestCase {
    func testMonitorEmitsOnlyWhenChangeCountChangesAndRecordingIsActive() {
        let adapter = FakePasteboardAdapter(changeCount: 1)
        let monitor = ClipboardMonitor(adapter: adapter, pollingInterval: 0.1)
        var events: [Int] = []
        monitor.onChange = { events.append($0.changeCount) }

        monitor.tick(settings: .defaults)
        XCTAssertEqual(events, [])

        adapter.changeCount = 2
        monitor.tick(settings: .defaults)
        XCTAssertEqual(events, [2])

        var paused = UserSettings.defaults
        paused.recordingPaused = true
        adapter.changeCount = 3
        monitor.tick(settings: paused)
        XCTAssertEqual(events, [2])

        paused.recordingPaused = false
        monitor.tick(settings: paused)
        XCTAssertEqual(events, [2])
    }

    func testReaderNormalizesSupportedTypesAfterPrivacyAllowsSnapshot() {
        let adapter = FakePasteboardAdapter(changeCount: 1)
        adapter.declaredTypes = ["public.utf8-plain-text"]
        adapter.stringValue = "https://www.clipdock.app/features"
        let reader = ClipboardReader(adapter: adapter)

        let item = reader.readCandidate(settings: .defaults)

        XCTAssertEqual(item?.primaryType, .url)
        XCTAssertEqual(item?.previewText, "https://www.clipdock.app/features")
    }

    func testReaderDoesNotReturnSensitiveTextAfterContentInspection() {
        let adapter = FakePasteboardAdapter(changeCount: 1)
        adapter.declaredTypes = ["public.utf8-plain-text"]
        adapter.stringValue = "api_key = sk_live_1234567890abcdef"
        let reader = ClipboardReader(adapter: adapter)

        XCTAssertNil(reader.readCandidate(settings: .defaults))
    }

    func testWriterRestoresTextAndURL() throws {
        let adapter = FakePasteboardAdapter(changeCount: 1)
        let writer = ClipboardWriter(adapter: adapter)

        try writer.restore(ClipItem.fixture(primaryType: .text, payload: .text("hello"), previewText: "hello"))
        XCTAssertEqual(adapter.writtenString, "hello")

        try writer.restore(ClipItem.fixture(primaryType: .url, payload: .url("https://example.com"), previewText: "https://example.com"))
        XCTAssertEqual(adapter.writtenURL?.absoluteString, "https://example.com")
    }

    func testWriterRestoresFileURLAsFileURLType() throws {
        let adapter = FakePasteboardAdapter(changeCount: 1)
        let writer = ClipboardWriter(adapter: adapter)
        let path = "/Users/example/Documents/report.pdf"

        try writer.restore(ClipItem.fixture(primaryType: .file, payload: .fileURL(path), previewText: path))

        XCTAssertEqual(adapter.writtenFileURL?.path, path)
    }

    func testReaderReturnsImagePayloadCandidateAndWriterRestoresImageData() throws {
        let adapter = FakePasteboardAdapter(changeCount: 1)
        adapter.declaredTypes = ["public.png"]
        adapter.imageDataValue = Data([1, 2, 3])
        let reader = ClipboardReader(adapter: adapter)

        let candidate = try XCTUnwrap(reader.readCaptureCandidate(settings: .defaults))
        XCTAssertEqual(candidate.item.primaryType, .image)
        XCTAssertEqual(candidate.imageData, Data([1, 2, 3]))

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let payloadPath = directory.appendingPathComponent("image.bin")
        try Data([4, 5, 6]).write(to: payloadPath)

        var imageItem = candidate.item
        imageItem.payloadRef = payloadPath.path
        try ClipboardWriter(adapter: adapter).restore(imageItem)
        XCTAssertEqual(adapter.writtenImageData, Data([4, 5, 6]))
    }

    func testReaderRejectsImageWhenActualPayloadExceedsPrivacyLimit() {
        let adapter = FakePasteboardAdapter(changeCount: 1)
        adapter.declaredTypes = ["public.png"]
        adapter.estimatedByteSizeOverride = 0
        adapter.imageDataValue = Data(repeating: 1, count: 9)
        let reader = ClipboardReader(
            adapter: adapter,
            privacyEngine: PrivacyRuleEngine(maxAllowedBytes: 8),
        )

        XCTAssertNil(reader.readCaptureCandidate(settings: .defaults))
    }

    func testReaderHashesImageCandidatesFromPayloadBytes() throws {
        let adapter = FakePasteboardAdapter(changeCount: 1)
        adapter.declaredTypes = ["public.png"]
        let reader = ClipboardReader(adapter: adapter)

        adapter.imageDataValue = Data([1, 2, 3])
        let first = try XCTUnwrap(reader.readCaptureCandidate(settings: .defaults))
        adapter.imageDataValue = Data([3, 2, 1])
        let second = try XCTUnwrap(reader.readCaptureCandidate(settings: .defaults))

        XCTAssertNotEqual(first.item.contentHash, second.item.contentHash)
    }

    func testReaderSkipsImageWhenImageSavingIsDisabled() {
        let adapter = FakePasteboardAdapter(changeCount: 1)
        adapter.declaredTypes = ["public.png"]
        adapter.imageDataValue = Data([1, 2, 3])
        var settings = UserSettings.defaults
        settings.saveImages = false

        XCTAssertNil(ClipboardReader(adapter: adapter).readCaptureCandidate(settings: settings))
    }

    func testReaderSkipsFileURLWhenFileURLSavingIsDisabled() {
        let adapter = FakePasteboardAdapter(changeCount: 1)
        adapter.declaredTypes = ["public.file-url"]
        adapter.fileURLValue = URL(fileURLWithPath: "/tmp/report.pdf")
        var settings = UserSettings.defaults
        settings.saveFileURLs = false

        XCTAssertNil(ClipboardReader(adapter: adapter).readCaptureCandidate(settings: settings))
    }

    func testPasteControllerKeepsAutoPasteDisabledByDefault() throws {
        let adapter = FakePasteboardAdapter(changeCount: 1)
        let controller = PasteController(writer: ClipboardWriter(adapter: adapter), accessibility: FakeAccessibilityChecker(granted: false))

        let result = try controller.restore(ClipItem.fixture(), settings: .defaults)

        XCTAssertEqual(result, .restoredToClipboard)
        XCTAssertEqual(adapter.writtenString, "hello")
    }

    func testPasteControllerSettingsControlledIntentDoesNotAutoPasteWhenUserHasNotEnabledIt() throws {
        let adapter = FakePasteboardAdapter(changeCount: 1)
        let pasteCommandRecorder = PasteCommandRecorder()
        let controller = PasteController(
            writer: ClipboardWriter(adapter: adapter),
            accessibility: FakeAccessibilityChecker(granted: true),
            autoPasteDelay: 0,
            pasteCommand: { pasteCommandRecorder.record() },
        )

        let result = try controller.restore(
            ClipItem.fixture(),
            settings: .defaults,
            autoPasteIntent: .settingsControlled,
        )

        XCTAssertEqual(result, .restoredToClipboard)
        XCTAssertEqual(adapter.writtenString, "hello")
        XCTAssertEqual(pasteCommandRecorder.count, 0)
    }

    func testPasteControllerExplicitUserPasteBypassesAutoPasteSettingWhenPermissionGranted() throws {
        let adapter = FakePasteboardAdapter(changeCount: 1)
        let pasteCommandRecorder = PasteCommandRecorder()
        var prepared = false
        let controller = PasteController(
            writer: ClipboardWriter(adapter: adapter),
            accessibility: FakeAccessibilityChecker(granted: true),
            autoPasteDelay: 0,
            pasteCommand: { pasteCommandRecorder.record() },
        )

        let result = try controller.restore(
            ClipItem.fixture(),
            settings: .defaults,
            autoPasteIntent: .explicitUserPaste,
            prepareForAutoPaste: { prepared = true },
        )

        XCTAssertEqual(result, .autoPasted)
        XCTAssertEqual(adapter.writtenString, "hello")
        XCTAssertTrue(prepared)
        XCTAssertEqual(pasteCommandRecorder.count, 1)
    }

    func testPasteControllerExplicitUserPasteReportsUnavailableWhenPermissionIsMissing() throws {
        let adapter = FakePasteboardAdapter(changeCount: 1)
        let pasteCommandRecorder = PasteCommandRecorder()
        var prepared = false
        let controller = PasteController(
            writer: ClipboardWriter(adapter: adapter),
            accessibility: FakeAccessibilityChecker(granted: false),
            autoPasteDelay: 0,
            pasteCommand: { pasteCommandRecorder.record() },
        )

        let result = try controller.restore(
            ClipItem.fixture(),
            settings: .defaults,
            autoPasteIntent: .explicitUserPaste,
            prepareForAutoPaste: { prepared = true },
        )

        XCTAssertEqual(result, .autoPasteUnavailable)
        XCTAssertEqual(adapter.writtenString, "hello")
        XCTAssertFalse(prepared)
        XCTAssertEqual(pasteCommandRecorder.count, 0)
    }

    func testPasteControllerSettingsControlledIntentAutoPastesWhenUserEnabledIt() throws {
        let adapter = FakePasteboardAdapter(changeCount: 1)
        let pasteCommandRecorder = PasteCommandRecorder()
        var prepared = false
        var settings = UserSettings.defaults
        settings.defaultPasteBehavior = .autoPasteWhenAllowed
        let controller = PasteController(
            writer: ClipboardWriter(adapter: adapter),
            accessibility: FakeAccessibilityChecker(granted: true),
            autoPasteDelay: 0,
            pasteCommand: { pasteCommandRecorder.record() },
        )

        let result = try controller.restore(
            ClipItem.fixture(),
            settings: settings,
            autoPasteIntent: .settingsControlled,
            prepareForAutoPaste: { prepared = true },
        )

        XCTAssertEqual(result, .autoPasted)
        XCTAssertEqual(adapter.writtenString, "hello")
        XCTAssertTrue(prepared)
        XCTAssertEqual(pasteCommandRecorder.count, 1)
    }

    func testPasteControllerSettingsControlledIntentIgnoresLegacyAutoPasteToggle() throws {
        let adapter = FakePasteboardAdapter(changeCount: 1)
        let pasteCommandRecorder = PasteCommandRecorder()
        var settings = UserSettings.defaults
        settings.autoPasteEnabled = true
        let controller = PasteController(
            writer: ClipboardWriter(adapter: adapter),
            accessibility: FakeAccessibilityChecker(granted: true),
            autoPasteDelay: 0,
            pasteCommand: { pasteCommandRecorder.record() },
        )

        let result = try controller.restore(
            ClipItem.fixture(),
            settings: settings,
            autoPasteIntent: .settingsControlled,
        )

        XCTAssertEqual(result, .restoredToClipboard)
        XCTAssertEqual(adapter.writtenString, "hello")
        XCTAssertEqual(pasteCommandRecorder.count, 0)
    }

    func testWriterFallsBackToPreviewTextWhenImagePayloadIsMissing() throws {
        let adapter = FakePasteboardAdapter(changeCount: 1)
        let writer = ClipboardWriter(adapter: adapter)
        let item = ClipItem.fixture(
            primaryType: .image,
            payload: .image(ImagePayload(byteCount: 12)),
            previewText: "Image fallback",
        )

        try writer.restore(item)

        XCTAssertEqual(adapter.writtenString, "Image fallback")
        XCTAssertNil(adapter.writtenImageData)
    }

    func testWriterThrowsForInvalidURLPayload() {
        let adapter = FakePasteboardAdapter(changeCount: 1)
        let writer = ClipboardWriter(adapter: adapter)
        let item = ClipItem.fixture(
            primaryType: .url,
            payload: .url("://missing-scheme"),
            previewText: "://missing-scheme",
        )

        XCTAssertThrowsError(try writer.restore(item)) { error in
            XCTAssertEqual(error as? ClipboardError, .invalidURL)
        }
    }

    func testPasteControllerReportsUnavailableWhenAutoPasteNeedsPermission() throws {
        let adapter = FakePasteboardAdapter(changeCount: 1)
        var settings = UserSettings.defaults
        settings.defaultPasteBehavior = .autoPasteWhenAllowed
        let controller = PasteController(
            writer: ClipboardWriter(adapter: adapter),
            accessibility: FakeAccessibilityChecker(granted: false),
            autoPasteDelay: 0,
            pasteCommand: {},
        )

        let result = try controller.restore(ClipItem.fixture(), settings: settings)

        XCTAssertEqual(result, .autoPasteUnavailable)
        XCTAssertEqual(adapter.writtenString, "hello")
    }
}

final class AppKitPasteboardAdapterTests: XCTestCase {
    func testNamedPasteboardRoundTripsString() {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        let adapter = AppKitPasteboardAdapter(pasteboard: pasteboard)

        adapter.writeString("hello")

        XCTAssertEqual(adapter.readString(), "hello")
        XCTAssertTrue(adapter.snapshot().declaredTypes.contains(NSPasteboard.PasteboardType.string.rawValue))
    }

    func testNamedPasteboardRoundTripsURL() {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        let adapter = AppKitPasteboardAdapter(pasteboard: pasteboard)

        adapter.writeURL(URL(string: "https://clipdock.app/docs")!)

        XCTAssertEqual(adapter.readURL()?.absoluteString, "https://clipdock.app/docs")
        XCTAssertEqual(adapter.readString(), "https://clipdock.app/docs")
    }

    func testNamedPasteboardRoundTripsFileURL() {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        let adapter = AppKitPasteboardAdapter(pasteboard: pasteboard)
        let fileURL = URL(fileURLWithPath: "/tmp/clipdock-ui-fixture.txt")

        adapter.writeFileURL(fileURL)

        XCTAssertEqual(adapter.readFileURL()?.path, fileURL.path)
        XCTAssertEqual(adapter.readString(), fileURL.path)
    }

    func testNamedPasteboardRoundTripsImageData() {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        let adapter = AppKitPasteboardAdapter(pasteboard: pasteboard)
        let data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

        adapter.writeImageData(data)

        XCTAssertEqual(adapter.readImageData(), data)
        XCTAssertTrue(adapter.snapshot().declaredTypes.contains(NSPasteboard.PasteboardType.png.rawValue))
    }

    private func makePasteboard() -> NSPasteboard {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipDockTests.\(UUID().uuidString)"))
        pasteboard.clearContents()
        return pasteboard
    }
}

final class PasteCommandRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func record() {
        lock.lock()
        value += 1
        lock.unlock()
    }
}

final class FakePasteboardAdapter: PasteboardAdapter {
    var changeCount: Int
    var declaredTypes: [String] = []
    var stringValue: String?
    var urlValue: URL?
    var fileURLValue: URL?
    var imageDataValue: Data?
    var sourceApp: SourceAppMetadata?
    var estimatedByteSizeOverride: Int?
    var writtenString: String?
    var writtenURL: URL?
    var writtenFileURL: URL?
    var writtenImageData: Data?

    init(changeCount: Int) {
        self.changeCount = changeCount
    }

    func snapshot() -> ClipboardSnapshot {
        ClipboardSnapshot(
            declaredTypes: declaredTypes,
            sourceApp: sourceApp,
            estimatedByteSize: estimatedByteSizeOverride ?? stringValue?.utf8.count ?? imageDataValue?.count ?? 0,
            previewText: stringValue ?? urlValue?.absoluteString ?? fileURLValue?.path,
        )
    }

    func readString() -> String? { stringValue }
    func readURL() -> URL? { urlValue ?? stringValue.flatMap(URL.init(string:)) }
    func readFileURL() -> URL? { fileURLValue }
    func readImageData() -> Data? { imageDataValue }
    func writeString(_ value: String) { writtenString = value }
    func writeURL(_ value: URL) { writtenURL = value }
    func writeFileURL(_ value: URL) { writtenFileURL = value }
    func writeImageData(_ data: Data) { writtenImageData = data }
}

struct FakeAccessibilityChecker: AccessibilityChecking {
    let granted: Bool
    var hasAccessibilityPermission: Bool { granted }
}
