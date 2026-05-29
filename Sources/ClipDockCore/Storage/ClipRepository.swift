import Foundation

public struct ClipRepositoryFilter: Equatable, Sendable {
    public var type: ClipType?
    public var favoriteOnly: Bool
    public var sourceAppKeyword: String?
    public var before: Date?

    public init(type: ClipType? = nil, favoriteOnly: Bool = false, sourceAppKeyword: String? = nil, before: Date? = nil) {
        self.type = type
        self.favoriteOnly = favoriteOnly
        self.sourceAppKeyword = sourceAppKeyword
        self.before = before
    }
}

public struct ClipStorageStats: Equatable, Sendable {
    public var itemCount: Int
    public var maxHistoryCount: Int
    public var databaseByteSize: Int64
    public var payloadByteSize: Int64
    public var totalByteSize: Int64

    public init(
        itemCount: Int,
        maxHistoryCount: Int,
        databaseByteSize: Int64,
        payloadByteSize: Int64,
        totalByteSize: Int64,
    ) {
        self.itemCount = itemCount
        self.maxHistoryCount = maxHistoryCount
        self.databaseByteSize = databaseByteSize
        self.payloadByteSize = payloadByteSize
        self.totalByteSize = totalByteSize
    }

    public static func empty(maxHistoryCount: Int) -> ClipStorageStats {
        ClipStorageStats(
            itemCount: 0,
            maxHistoryCount: maxHistoryCount,
            databaseByteSize: 0,
            payloadByteSize: 0,
            totalByteSize: 0,
        )
    }
}

public protocol ClipRepository: AnyObject {
    func upsert(_ item: ClipItem) throws
    func item(id: UUID) throws -> ClipItem?
    func recent(limit: Int) throws -> [ClipItem]
    func search(keyword: String, filter: ClipRepositoryFilter, limit: Int) throws -> [ClipItem]
    func setFavorite(_ favorite: Bool, id: UUID) throws
    func markUsed(id: UUID, at date: Date) throws
    func delete(id: UUID) throws
    func clear() throws
    func enforceRetention(settings: UserSettings, now: Date) throws
    func storageStats(settings: UserSettings) throws -> ClipStorageStats
}

public final class InMemoryClipRepository: ClipRepository {
    private var itemsByID: [UUID: ClipItem] = [:]
    private var idByContentKey: [String: UUID] = [:]

    public init(items: [ClipItem] = []) {
        for item in items {
            itemsByID[item.id] = item
            idByContentKey[contentKey(for: item)] = item.id
        }
    }

    public func upsert(_ item: ClipItem) throws {
        let key = contentKey(for: item)
        let id = idByContentKey[key] ?? item.id
        var stored = item
        if var existing = itemsByID[id] {
            stored.id = existing.id
            stored.isFavorite = existing.isFavorite || item.isFavorite
            stored.useCount = existing.useCount
            stored.lastUsedAt = existing.lastUsedAt
            existing = stored
            itemsByID[id] = existing
        } else {
            itemsByID[id] = stored
        }
        idByContentKey[key] = id
    }

    public func item(id: UUID) throws -> ClipItem? {
        itemsByID[id]
    }

    public func recent(limit: Int) throws -> [ClipItem] {
        Array(sortedItems().prefix(limit))
    }

    public func search(keyword: String, filter: ClipRepositoryFilter, limit: Int) throws -> [ClipItem] {
        let lowered = keyword.lowercased()
        let results = sortedItems().filter { item in
            matches(item, keyword: lowered, filter: filter)
        }
        return Array(results.prefix(limit))
    }

    public func setFavorite(_ favorite: Bool, id: UUID) throws {
        guard var item = itemsByID[id] else { return }
        item.isFavorite = favorite
        itemsByID[id] = item
    }

    public func markUsed(id: UUID, at date: Date = Date()) throws {
        guard var item = itemsByID[id] else { return }
        item.lastUsedAt = date
        item.useCount += 1
        itemsByID[id] = item
    }

    public func delete(id: UUID) throws {
        guard let item = itemsByID.removeValue(forKey: id) else { return }
        idByContentKey.removeValue(forKey: contentKey(for: item))
    }

    public func clear() throws {
        itemsByID.removeAll()
        idByContentKey.removeAll()
    }

    public func enforceRetention(settings: UserSettings, now: Date) throws {
        let cutoff = now.addingTimeInterval(-TimeInterval(settings.retentionDays) * 86400)
        for item in itemsByID.values where !item.isFavorite && item.capturedAt < cutoff {
            try delete(id: item.id)
        }

        let nonFavorites = sortedItems().filter { !$0.isFavorite }
        let allowedNonFavorites = max(settings.maxHistoryCount, 0)
        if nonFavorites.count > allowedNonFavorites {
            for item in nonFavorites.dropFirst(allowedNonFavorites) {
                try delete(id: item.id)
            }
        }
    }

    public func storageStats(settings: UserSettings) throws -> ClipStorageStats {
        ClipStorageStats(
            itemCount: itemsByID.count,
            maxHistoryCount: settings.maxHistoryCount,
            databaseByteSize: 0,
            payloadByteSize: 0,
            totalByteSize: 0,
        )
    }

    private func sortedItems() -> [ClipItem] {
        itemsByID.values.sorted {
            if $0.capturedAt == $1.capturedAt {
                return $0.id.uuidString < $1.id.uuidString
            }
            return $0.capturedAt > $1.capturedAt
        }
    }

    private func matches(_ item: ClipItem, keyword: String, filter: ClipRepositoryFilter) -> Bool {
        if let type = filter.type, item.primaryType != type { return false }
        if filter.favoriteOnly, !item.isFavorite { return false }
        if let before = filter.before, item.capturedAt >= before { return false }
        if let source = filter.sourceAppKeyword?.lowercased(), !source.isEmpty {
            let name = item.sourceApp?.name?.lowercased() ?? ""
            let bundle = item.sourceApp?.bundleIdentifier?.lowercased() ?? ""
            guard name.contains(source) || bundle.contains(source) else { return false }
        }
        guard !keyword.isEmpty else { return true }
        return item.previewText.lowercased().contains(keyword)
            || (item.title?.lowercased().contains(keyword) ?? false)
    }

    private func contentKey(for item: ClipItem) -> String {
        "\(item.primaryType.rawValue):\(item.contentHash)"
    }
}
