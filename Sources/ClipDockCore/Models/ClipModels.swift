import Foundation

public enum ClipType: String, Codable, CaseIterable, Equatable, Sendable {
    case text
    case url
    case image
    case file
    case unknown
}

public enum ClipPayload: Codable, Equatable, Sendable {
    case text(String)
    case url(String)
    case image(ImagePayload)
    case fileURL(String)
    case none
}

public struct ImagePayload: Codable, Equatable, Sendable {
    public var byteCount: Int
    public var width: Int?
    public var height: Int?

    public init(byteCount: Int, width: Int? = nil, height: Int? = nil) {
        self.byteCount = byteCount
        self.width = width
        self.height = height
    }
}

public struct SourceAppMetadata: Codable, Equatable, Sendable {
    public var name: String?
    public var bundleIdentifier: String?

    public init(name: String? = nil, bundleIdentifier: String? = nil) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
    }
}

public struct ClipItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var contentHash: String
    public var primaryType: ClipType
    public var capturedAt: Date
    public var lastUsedAt: Date?
    public var useCount: Int
    public var isFavorite: Bool
    public var isSensitive: Bool
    public var expiresAt: Date?
    public var tags: [String]
    public var previewText: String
    public var title: String?
    public var payload: ClipPayload
    public var payloadRef: String?
    public var sourceApp: SourceAppMetadata?
    public var byteSize: Int

    public var sourceBundleID: String? { sourceApp?.bundleIdentifier }
    public var sourceAppName: String? { sourceApp?.name }

    public init(
        id: UUID = UUID(),
        contentHash: String,
        primaryType: ClipType,
        capturedAt: Date = Date(),
        lastUsedAt: Date? = nil,
        useCount: Int = 0,
        isFavorite: Bool = false,
        isSensitive: Bool = false,
        expiresAt: Date? = nil,
        tags: [String] = [],
        previewText: String,
        title: String? = nil,
        payload: ClipPayload = .none,
        payloadRef: String? = nil,
        sourceApp: SourceAppMetadata? = nil,
        byteSize: Int = 0,
    ) {
        self.id = id
        self.contentHash = contentHash
        self.primaryType = primaryType
        self.capturedAt = capturedAt
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
        self.isFavorite = isFavorite
        self.isSensitive = isSensitive
        self.expiresAt = expiresAt
        self.tags = tags
        self.previewText = previewText
        self.title = title
        self.payload = payload
        self.payloadRef = payloadRef
        self.sourceApp = sourceApp
        self.byteSize = byteSize
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case contentHash
        case primaryType
        case capturedAt
        case lastUsedAt
        case useCount
        case isFavorite
        case legacyIsPinned = "isPinned"
        case isSensitive
        case expiresAt
        case tags
        case previewText
        case title
        case payload
        case payloadRef
        case sourceApp
        case byteSize
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        contentHash = try container.decode(String.self, forKey: .contentHash)
        primaryType = try container.decode(ClipType.self, forKey: .primaryType)
        capturedAt = try container.decode(Date.self, forKey: .capturedAt)
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        useCount = try container.decodeIfPresent(Int.self, forKey: .useCount) ?? 0
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite)
            ?? container.decodeIfPresent(Bool.self, forKey: .legacyIsPinned)
            ?? false
        isSensitive = try container.decodeIfPresent(Bool.self, forKey: .isSensitive) ?? false
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        previewText = try container.decode(String.self, forKey: .previewText)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        payload = try container.decodeIfPresent(ClipPayload.self, forKey: .payload) ?? .none
        payloadRef = try container.decodeIfPresent(String.self, forKey: .payloadRef)
        sourceApp = try container.decodeIfPresent(SourceAppMetadata.self, forKey: .sourceApp)
        byteSize = try container.decodeIfPresent(Int.self, forKey: .byteSize) ?? previewText.utf8.count
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(contentHash, forKey: .contentHash)
        try container.encode(primaryType, forKey: .primaryType)
        try container.encode(capturedAt, forKey: .capturedAt)
        try container.encodeIfPresent(lastUsedAt, forKey: .lastUsedAt)
        try container.encode(useCount, forKey: .useCount)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(isSensitive, forKey: .isSensitive)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
        try container.encode(tags, forKey: .tags)
        try container.encode(previewText, forKey: .previewText)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encode(payload, forKey: .payload)
        try container.encodeIfPresent(payloadRef, forKey: .payloadRef)
        try container.encodeIfPresent(sourceApp, forKey: .sourceApp)
        try container.encode(byteSize, forKey: .byteSize)
    }
}

public struct UserSettings: Codable, Equatable, Sendable {
    public var maxHistoryCount: Int
    public var retentionDays: Int
    public var saveImages: Bool
    public var saveFileURLs: Bool
    public var pollingInterval: TimeInterval
    public var recordingPaused: Bool
    public var ignoreSensitiveContent: Bool
    public var restoreLastClipboardOnStartup: Bool
    public var autoPasteEnabled: Bool
    public var ignoredBundleIdentifiers: Set<String>
    public var lowPowerPolling: Bool
    public var launchAtLogin: Bool
    public var globalShortcut: String
    public var defaultPasteBehavior: PasteBehavior
    public var deduplicationStrategy: DeduplicationStrategy

    public static let defaults = UserSettings()

    public init(
        maxHistoryCount: Int = 1000,
        retentionDays: Int = 30,
        saveImages: Bool = true,
        saveFileURLs: Bool = true,
        pollingInterval: TimeInterval = 0.8,
        recordingPaused: Bool = false,
        ignoreSensitiveContent: Bool = true,
        restoreLastClipboardOnStartup: Bool = false,
        autoPasteEnabled: Bool = false,
        ignoredBundleIdentifiers: Set<String> = IgnoredAppStore.recommendedIgnoredBundleIDs,
        lowPowerPolling: Bool = false,
        launchAtLogin: Bool = false,
        globalShortcut: String = "⌘⇧V",
        defaultPasteBehavior: PasteBehavior = .restoreOnly,
        deduplicationStrategy: DeduplicationStrategy = .byTypeAndContentHash,
    ) {
        self.maxHistoryCount = maxHistoryCount
        self.retentionDays = retentionDays
        self.saveImages = saveImages
        self.saveFileURLs = saveFileURLs
        self.pollingInterval = pollingInterval
        self.recordingPaused = recordingPaused
        self.ignoreSensitiveContent = ignoreSensitiveContent
        self.restoreLastClipboardOnStartup = restoreLastClipboardOnStartup
        self.autoPasteEnabled = autoPasteEnabled
        self.ignoredBundleIdentifiers = ignoredBundleIdentifiers
        self.lowPowerPolling = lowPowerPolling
        self.launchAtLogin = launchAtLogin
        self.globalShortcut = globalShortcut
        self.defaultPasteBehavior = defaultPasteBehavior
        self.deduplicationStrategy = deduplicationStrategy
    }

    private enum CodingKeys: String, CodingKey {
        case maxHistoryCount
        case retentionDays
        case saveImages
        case saveFileURLs
        case pollingInterval
        case recordingPaused
        case ignoreSensitiveContent
        case restoreLastClipboardOnStartup
        case autoPasteEnabled
        case ignoredBundleIdentifiers
        case lowPowerPolling
        case launchAtLogin
        case globalShortcut
        case defaultPasteBehavior
        case deduplicationStrategy
    }

    public init(from decoder: Decoder) throws {
        let defaults = UserSettings.defaults
        let container = try decoder.container(keyedBy: CodingKeys.self)
        maxHistoryCount = try container.decodeIfPresent(Int.self, forKey: .maxHistoryCount) ?? defaults.maxHistoryCount
        retentionDays = try container.decodeIfPresent(Int.self, forKey: .retentionDays) ?? defaults.retentionDays
        saveImages = try container.decodeIfPresent(Bool.self, forKey: .saveImages) ?? defaults.saveImages
        saveFileURLs = try container.decodeIfPresent(Bool.self, forKey: .saveFileURLs) ?? defaults.saveFileURLs
        pollingInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .pollingInterval) ?? defaults.pollingInterval
        recordingPaused = try container.decodeIfPresent(Bool.self, forKey: .recordingPaused) ?? defaults.recordingPaused
        ignoreSensitiveContent = try container.decodeIfPresent(Bool.self, forKey: .ignoreSensitiveContent) ?? defaults.ignoreSensitiveContent
        restoreLastClipboardOnStartup = try container.decodeIfPresent(Bool.self, forKey: .restoreLastClipboardOnStartup) ?? defaults.restoreLastClipboardOnStartup
        autoPasteEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoPasteEnabled) ?? defaults.autoPasteEnabled
        ignoredBundleIdentifiers = try container.decodeIfPresent(Set<String>.self, forKey: .ignoredBundleIdentifiers) ?? defaults.ignoredBundleIdentifiers
        lowPowerPolling = try container.decodeIfPresent(Bool.self, forKey: .lowPowerPolling) ?? defaults.lowPowerPolling
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? defaults.launchAtLogin
        let storedGlobalShortcut = try container.decodeIfPresent(String.self, forKey: .globalShortcut) ?? defaults.globalShortcut
        globalShortcut = KeyboardShortcutSpec.parse(storedGlobalShortcut) == nil ? defaults.globalShortcut : storedGlobalShortcut
        defaultPasteBehavior = try container.decodeIfPresent(PasteBehavior.self, forKey: .defaultPasteBehavior) ?? defaults.defaultPasteBehavior
        deduplicationStrategy = try container.decodeIfPresent(DeduplicationStrategy.self, forKey: .deduplicationStrategy) ?? defaults.deduplicationStrategy
    }
}

public enum PasteBehavior: String, Codable, Equatable, Sendable {
    case restoreOnly
    case autoPasteWhenAllowed
}

public enum DeduplicationStrategy: String, Codable, Equatable, Sendable, CaseIterable {
    case byTypeAndContentHash
}

public struct CaptureDecision: Codable, Equatable, Sendable {
    public var isAllowed: Bool
    public var reason: CaptureDecisionReason

    public static let allow = CaptureDecision(isAllowed: true, reason: .allowed)

    public static func ignore(_ reason: CaptureDecisionReason) -> CaptureDecision {
        CaptureDecision(isAllowed: false, reason: reason)
    }
}

public enum CaptureDecisionReason: String, Codable, Equatable, Sendable {
    case allowed
    case recordingPaused
    case transientType
    case concealedType
    case autoGeneratedType
    case ignoredApplication
    case sensitiveContent
    case oversizedContent
    case unsupportedType
}

public extension JSONEncoder {
    static var clipDock: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

public extension JSONDecoder {
    static var clipDock: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
