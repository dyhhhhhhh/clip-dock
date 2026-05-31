import AppKit
import Foundation

public protocol PasteboardAdapter: AnyObject {
    var changeCount: Int { get }
    func snapshot() -> ClipboardSnapshot
    func readString() -> String?
    func readURL() -> URL?
    func readFileURL() -> URL?
    func readImageData() -> Data?
    func writeString(_ value: String)
    func writeURL(_ value: URL)
    func writeFileURL(_ value: URL)
    func writeImageData(_ data: Data)
}

public final class AppKitPasteboardAdapter: PasteboardAdapter {
    private let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public var changeCount: Int { pasteboard.changeCount }

    public func snapshot() -> ClipboardSnapshot {
        let types = pasteboard.types?.map(\.rawValue) ?? []
        return ClipboardSnapshot(
            declaredTypes: types,
            sourceApp: SourceAppMetadata(
                name: NSWorkspace.shared.frontmostApplication?.localizedName,
                bundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            ),
            estimatedByteSize: 0,
            previewText: nil,
        )
    }

    public func readString() -> String? {
        pasteboard.string(forType: .string)
    }

    public func readURL() -> URL? {
        if let string = pasteboard.string(forType: .URL), let url = URL(string: string) {
            return url
        }
        if let string = readString(), let url = URL(string: string), url.scheme != nil {
            return url
        }
        return nil
    }

    public func readFileURL() -> URL? {
        if let string = pasteboard.string(forType: .fileURL) {
            return URL(string: string)
        }
        return nil
    }

    public func readImageData() -> Data? {
        pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff)
    }

    public func writeString(_ value: String) {
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }

    public func writeURL(_ value: URL) {
        pasteboard.clearContents()
        pasteboard.setString(value.absoluteString, forType: .URL)
        pasteboard.setString(value.absoluteString, forType: .string)
    }

    public func writeFileURL(_ value: URL) {
        pasteboard.clearContents()
        pasteboard.setString(value.absoluteString, forType: .fileURL)
        pasteboard.setString(value.absoluteString, forType: .URL)
        pasteboard.setString(value.path, forType: .string)
    }

    public func writeImageData(_ data: Data) {
        pasteboard.clearContents()
        pasteboard.setData(data, forType: .png)
    }
}
