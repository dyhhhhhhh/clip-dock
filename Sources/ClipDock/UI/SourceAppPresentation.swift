import AppKit
import ClipDockCore

struct SourceAppPresentation {
    var name: String
    var icon: NSImage

    private static let knownAppNamesByBundleIdentifier: [String: String] = [
        "com.1password.1password": "1Password",
        "com.agilebits.onepassword7": "1Password 7",
        "com.apple.keychainaccess": "Keychain Access",
        "com.bitwarden.desktop": "Bitwarden",
        "com.dashlane.dashlane": "Dashlane",
        "com.lastpass.lastpass": "LastPass",
        "com.yubico.yubioath": "Yubico Authenticator",
    ]
    private static let iconCache = NSCache<NSString, NSImage>()

    static func resolve(_ sourceApp: SourceAppMetadata?) -> SourceAppPresentation {
        let normalized = NormalizedSourceApp(sourceApp)
        return SourceAppPresentation(
            name: normalized.name,
            icon: icon(forBundleIdentifier: normalized.bundleIdentifier),
        )
    }

    static func resolve(bundleIdentifier: String) -> SourceAppPresentation {
        let normalizedBundleIdentifier = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        return SourceAppPresentation(
            name: applicationName(forBundleIdentifier: normalizedBundleIdentifier)
                ?? knownAppName(forBundleIdentifier: normalizedBundleIdentifier)
                ?? fallbackName(forBundleIdentifier: normalizedBundleIdentifier),
            icon: icon(forBundleIdentifier: normalizedBundleIdentifier),
        )
    }

    fileprivate static func applicationName(forBundleIdentifier bundleIdentifier: String?) -> String? {
        guard let bundleIdentifier,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        else {
            return nil
        }

        let bundle = Bundle(url: appURL)
        let localizedName = bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String
            ?? bundle?.localizedInfoDictionary?["CFBundleName"] as? String
        let name = localizedName
            ?? bundle?.infoDictionary?["CFBundleDisplayName"] as? String
            ?? bundle?.infoDictionary?["CFBundleName"] as? String
            ?? appURL.deletingPathExtension().lastPathComponent
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? nil : trimmedName
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

    private static func knownAppName(forBundleIdentifier bundleIdentifier: String) -> String? {
        knownAppNamesByBundleIdentifier[bundleIdentifier.lowercased()]
    }

    private static func fallbackName(forBundleIdentifier bundleIdentifier: String) -> String {
        let lastComponent = bundleIdentifier
            .split(separator: ".")
            .last
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let lastComponent, !lastComponent.isEmpty else {
            return "未知应用"
        }
        return lastComponent
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

        name = Self.normalizedName(rawName)
            ?? SourceAppPresentation.applicationName(forBundleIdentifier: rawBundleIdentifier)
            ?? "未知"
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
