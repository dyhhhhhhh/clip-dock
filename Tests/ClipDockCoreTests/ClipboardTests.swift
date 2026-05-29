@testable import ClipDockCore
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

    func testPasteControllerKeepsAutoPasteDisabledByDefault() throws {
        let adapter = FakePasteboardAdapter(changeCount: 1)
        let controller = PasteController(writer: ClipboardWriter(adapter: adapter), accessibility: FakeAccessibilityChecker(granted: false))

        let result = try controller.restore(ClipItem.fixture(), settings: .defaults)

        XCTAssertEqual(result, .restoredToClipboard)
        XCTAssertEqual(adapter.writtenString, "hello")
    }

    func testPasteControllerCanForceAutoPasteForExplicitAction() throws {
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
            forceAutoPaste: true,
            prepareForAutoPaste: { prepared = true },
        )

        XCTAssertEqual(result, .autoPasted)
        XCTAssertEqual(adapter.writtenString, "hello")
        XCTAssertTrue(prepared)
        XCTAssertEqual(pasteCommandRecorder.count, 1)
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
    var writtenString: String?
    var writtenURL: URL?
    var writtenImageData: Data?

    init(changeCount: Int) {
        self.changeCount = changeCount
    }

    func snapshot() -> ClipboardSnapshot {
        ClipboardSnapshot(
            declaredTypes: declaredTypes,
            sourceApp: sourceApp,
            estimatedByteSize: stringValue?.utf8.count ?? imageDataValue?.count ?? 0,
            previewText: stringValue ?? urlValue?.absoluteString ?? fileURLValue?.path,
        )
    }

    func readString() -> String? { stringValue }
    func readURL() -> URL? { urlValue ?? stringValue.flatMap(URL.init(string:)) }
    func readFileURL() -> URL? { fileURLValue }
    func readImageData() -> Data? { imageDataValue }
    func writeString(_ value: String) { writtenString = value }
    func writeURL(_ value: URL) { writtenURL = value }
    func writeImageData(_ data: Data) { writtenImageData = data }
}

struct FakeAccessibilityChecker: AccessibilityChecking {
    let granted: Bool
    var hasAccessibilityPermission: Bool { granted }
}
