import AppKit
import ClipDockCore

struct FileItemPresentation {
    let url: URL
    let displayName: String
    let displayPath: String
    let icon: NSImage

    private static let iconCache = NSCache<NSString, NSImage>()

    static func resolve(_ item: ClipItem) -> FileItemPresentation? {
        guard item.primaryType == .file,
              let url = fileURL(from: item)
        else {
            return nil
        }

        let displayName = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        return FileItemPresentation(
            url: url,
            displayName: displayName,
            displayPath: url.path,
            icon: icon(for: url),
        )
    }

    private static func icon(for url: URL) -> NSImage {
        let key = NSString(string: url.path)
        if let cached = iconCache.object(forKey: key) {
            return cached
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        iconCache.setObject(icon, forKey: key)
        return icon
    }

    private static func fileURL(from item: ClipItem) -> URL? {
        if case let .fileURL(value) = item.payload {
            return fileURL(from: value)
        }
        return fileURL(from: item.previewText)
    }

    private static func fileURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.isFileURL {
            return url
        }
        return URL(fileURLWithPath: trimmed)
    }
}

extension ClipItem {
    var displayTitle: String {
        if let filePresentation {
            return filePresentation.displayName
        }
        let value = title ?? previewText
        if primaryType == .image {
            return value.replacingOccurrences(of: "Image •", with: "图片 •")
        }
        return value
    }

    var filePresentation: FileItemPresentation? {
        FileItemPresentation.resolve(self)
    }
}
