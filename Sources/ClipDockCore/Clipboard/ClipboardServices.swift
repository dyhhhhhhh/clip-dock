import AppKit
import Foundation

public final class ClipboardMonitor {
    public var onChange: ((ClipboardChangeEvent) -> Void)?
    public let adapter: PasteboardAdapter
    public var pollingInterval: TimeInterval
    private var lastChangeCount: Int
    private var timer: Timer?

    public init(adapter: PasteboardAdapter, pollingInterval: TimeInterval) {
        self.adapter = adapter
        self.pollingInterval = pollingInterval
        lastChangeCount = adapter.changeCount
    }

    public func start(settingsProvider: @escaping () -> UserSettings) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            self?.tick(settings: settingsProvider())
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func tick(settings: UserSettings) {
        guard !settings.recordingPaused else {
            lastChangeCount = adapter.changeCount
            return
        }
        let current = adapter.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current
        onChange?(ClipboardChangeEvent(changeCount: current))
    }
}

public struct ClipboardCaptureCandidate: Equatable, Sendable {
    public var item: ClipItem
    public var imageData: Data?

    public init(item: ClipItem, imageData: Data? = nil) {
        self.item = item
        self.imageData = imageData
    }
}

public struct ClipboardReader {
    public var adapter: PasteboardAdapter
    public var privacyEngine: PrivacyRuleEngine

    public init(adapter: PasteboardAdapter, privacyEngine: PrivacyRuleEngine = PrivacyRuleEngine()) {
        self.adapter = adapter
        self.privacyEngine = privacyEngine
    }

    public func readCandidate(settings: UserSettings) -> ClipItem? {
        readCaptureCandidate(settings: settings)?.item
    }

    public func readCaptureCandidate(settings: UserSettings) -> ClipboardCaptureCandidate? {
        let snapshot = adapter.snapshot()
        guard privacyEngine.evaluate(snapshot: snapshot, settings: settings).isAllowed else {
            return nil
        }

        if let fileURL = adapter.readFileURL(), settings.saveFileURLs {
            return ClipboardCaptureCandidate(
                item: makeItem(type: .file, previewText: fileURL.path, payload: .fileURL(fileURL.path), source: snapshot.sourceApp),
            )
        }
        if let url = adapter.readURL() {
            let candidate = makeItem(type: .url, previewText: url.absoluteString, payload: .url(url.absoluteString), source: snapshot.sourceApp)
            return privacyEngine.evaluate(snapshot: contentSnapshot(for: candidate, source: snapshot.sourceApp), settings: settings).isAllowed
                ? ClipboardCaptureCandidate(item: candidate)
                : nil
        }
        if let imageData = adapter.readImageData(), settings.saveImages {
            let payload = ClipPayload.image(ImagePayload(byteCount: imageData.count))
            let item = makeItem(
                type: .image,
                previewText: "图片 • \(ByteCountFormatter.string(fromByteCount: Int64(imageData.count), countStyle: .file))",
                payload: payload,
                source: snapshot.sourceApp,
                byteSize: imageData.count,
            )
            return ClipboardCaptureCandidate(item: item, imageData: imageData)
        }
        if let text = adapter.readString(), !text.isEmpty {
            let candidate = makeItem(type: .text, previewText: text, payload: .text(text), source: snapshot.sourceApp)
            return privacyEngine.evaluate(snapshot: contentSnapshot(for: candidate, source: snapshot.sourceApp), settings: settings).isAllowed
                ? ClipboardCaptureCandidate(item: candidate)
                : nil
        }
        return nil
    }

    private func makeItem(
        type: ClipType,
        previewText: String,
        payload: ClipPayload,
        source: SourceAppMetadata?,
        byteSize: Int? = nil,
    ) -> ClipItem {
        let trimmedPreview = String(previewText.prefix(500))
        let hashInput = "\(type.rawValue):\(previewText)"
        return ClipItem(
            contentHash: Hashing.sha256(hashInput),
            primaryType: type,
            capturedAt: Date(),
            previewText: trimmedPreview,
            payload: payload,
            sourceApp: source,
            byteSize: byteSize ?? previewText.utf8.count,
        )
    }

    private func contentSnapshot(for item: ClipItem, source: SourceAppMetadata?) -> ClipboardSnapshot {
        ClipboardSnapshot(
            declaredTypes: [item.primaryType.rawValue],
            sourceApp: source,
            estimatedByteSize: item.byteSize,
            previewText: item.previewText,
        )
    }
}

public struct ClipboardWriter {
    public var adapter: PasteboardAdapter

    public init(adapter: PasteboardAdapter) {
        self.adapter = adapter
    }

    public func restore(_ item: ClipItem) throws {
        switch item.payload {
        case let .text(value):
            adapter.writeString(value)
        case let .url(value):
            guard let url = URL(string: value) else { throw ClipboardError.invalidURL }
            adapter.writeURL(url)
        case let .fileURL(value):
            adapter.writeURL(URL(fileURLWithPath: value))
        case .image:
            if let payloadRef = item.payloadRef,
               let data = try? Data(contentsOf: URL(fileURLWithPath: payloadRef))
            {
                adapter.writeImageData(data)
            } else {
                adapter.writeString(item.previewText)
            }
        case .none:
            adapter.writeString(item.previewText)
        }
    }
}

public enum ClipboardError: Error, Equatable {
    case invalidURL
}

public protocol AccessibilityChecking {
    var hasAccessibilityPermission: Bool { get }
}

public struct AppKitAccessibilityChecker: AccessibilityChecking {
    public init() {}
    public var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }
}

public enum PasteResult: Equatable {
    case restoredToClipboard
    case autoPasted
    case autoPasteUnavailable
}

public struct PasteController {
    public var writer: ClipboardWriter
    public var accessibility: AccessibilityChecking
    public var autoPasteDelay: TimeInterval
    public var pasteCommand: @Sendable () -> Void

    public init(
        writer: ClipboardWriter,
        accessibility: AccessibilityChecking = AppKitAccessibilityChecker(),
        autoPasteDelay: TimeInterval = 0.15,
    ) {
        self.init(
            writer: writer,
            accessibility: accessibility,
            autoPasteDelay: autoPasteDelay,
            pasteCommand: { PasteController.pasteWithCommandV() },
        )
    }

    public init(
        writer: ClipboardWriter,
        accessibility: AccessibilityChecking,
        autoPasteDelay: TimeInterval,
        pasteCommand: @escaping @Sendable () -> Void,
    ) {
        self.writer = writer
        self.accessibility = accessibility
        self.autoPasteDelay = autoPasteDelay
        self.pasteCommand = pasteCommand
    }

    public func restore(
        _ item: ClipItem,
        settings: UserSettings,
        forceAutoPaste: Bool = false,
        prepareForAutoPaste: (() -> Void)? = nil,
    ) throws -> PasteResult {
        try writer.restore(item)
        guard forceAutoPaste || settings.autoPasteEnabled || settings.defaultPasteBehavior == .autoPasteWhenAllowed else {
            return .restoredToClipboard
        }
        guard accessibility.hasAccessibilityPermission else {
            return .autoPasteUnavailable
        }
        prepareForAutoPaste?()
        if autoPasteDelay > 0 {
            let pasteCommand = pasteCommand
            DispatchQueue.main.asyncAfter(deadline: .now() + autoPasteDelay) {
                pasteCommand()
            }
        } else {
            pasteCommand()
        }
        return .autoPasted
    }

    private static func pasteWithCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
