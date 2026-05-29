import AppKit
import ClipDockCore

struct SourceAppPresentation {
    var name: String
    var icon: NSImage

    private static let iconCache = NSCache<NSString, NSImage>()

    static func resolve(_ sourceApp: SourceAppMetadata?) -> SourceAppPresentation {
        let normalized = NormalizedSourceApp(sourceApp)
        return SourceAppPresentation(
            name: normalized.name,
            icon: icon(forBundleIdentifier: normalized.bundleIdentifier),
        )
    }

    private static func icon(forBundleIdentifier bundleIdentifier: String?) -> NSImage {
        let cacheKey = NSString(string: bundleIdentifier ?? "__default__")
        if let cachedIcon = iconCache.object(forKey: cacheKey) {
            return cachedIcon
        }

        let icon: NSImage
        guard let bundleIdentifier,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        else {
            icon = NSImage(named: NSImage.applicationIconName) ?? NSImage(size: NSSize(width: 16, height: 16))
            iconCache.setObject(icon, forKey: cacheKey)
            return icon
        }
        icon = NSWorkspace.shared.icon(forFile: appURL.path)
        iconCache.setObject(icon, forKey: cacheKey)
        return icon
    }
}

private struct NormalizedSourceApp {
    var name: String
    var bundleIdentifier: String?

    init(_ sourceApp: SourceAppMetadata?) {
        let rawName = sourceApp?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawBundleIdentifier = sourceApp?.bundleIdentifier
        let lowerBundleIdentifier = rawBundleIdentifier?.lowercased()
        let lowerName = rawName?.lowercased()

        if lowerBundleIdentifier == "com.electron.lark.helper" || lowerName?.hasPrefix("lark helper") == true {
            name = "飞书"
            bundleIdentifier = "com.electron.lark"
            return
        }

        name = Self.normalizedName(rawName) ?? "未知"
        bundleIdentifier = rawBundleIdentifier
    }

    private static func normalizedName(_ rawName: String?) -> String? {
        guard let rawName, !rawName.isEmpty else { return nil }
        let helperSuffixes = [
            " Helper (Renderer)",
            " Helper (GPU)",
            " Helper (Plugin)",
            " Helper",
        ]
        for suffix in helperSuffixes where rawName.hasSuffix(suffix) {
            let stripped = String(rawName.dropLast(suffix.count))
            return stripped.isEmpty ? rawName : stripped
        }
        return rawName
    }
}

extension SourceAppMetadata {
    var displayName: String {
        SourceAppPresentation.resolve(self).name
    }
}
