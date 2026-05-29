import Foundation

public struct SearchQuery: Equatable, Sendable {
    public var rawText: String
    public var keywords: [String]
    public var type: ClipType?
    public var sourceAppKeyword: String?
    public var favoriteOnly: Bool
    public var beforeDays: Int?

    public init(
        rawText: String,
        keywords: [String] = [],
        type: ClipType? = nil,
        sourceAppKeyword: String? = nil,
        favoriteOnly: Bool = false,
        beforeDays: Int? = nil,
    ) {
        self.rawText = rawText
        self.keywords = keywords
        self.type = type
        self.sourceAppKeyword = sourceAppKeyword
        self.favoriteOnly = favoriteOnly
        self.beforeDays = beforeDays
    }

    public static func parse(_ text: String) -> SearchQuery {
        var query = SearchQuery(rawText: text)
        for token in text.split(separator: " ").map(String.init) {
            if let value = token.removePrefix("type:"), let type = ClipType(rawValue: value) {
                query.type = type
            } else if let value = token.removePrefix("app:"), !value.isEmpty {
                query.sourceAppKeyword = value
            } else if token == "is:favorite" || token == "is:pinned" {
                query.favoriteOnly = true
            } else if let value = token.removePrefix("before:"), value.hasSuffix("d"), let days = Int(value.dropLast()) {
                query.beforeDays = days
            } else {
                query.keywords.append(token)
            }
        }
        return query
    }

    public var keywordText: String {
        keywords.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public final class ClipSearchService {
    private let repository: ClipRepository
    private let ranker: SearchRanker

    public init(repository: ClipRepository, ranker: SearchRanker = SearchRanker()) {
        self.repository = repository
        self.ranker = ranker
    }

    public func search(_ query: SearchQuery, now: Date = Date(), limit: Int = 200) throws -> [ClipItem] {
        let before = query.beforeDays.map { now.addingTimeInterval(-TimeInterval($0) * 86400) }
        let filter = ClipRepositoryFilter(
            type: query.type,
            favoriteOnly: query.favoriteOnly,
            sourceAppKeyword: query.sourceAppKeyword,
            before: before,
        )
        let candidates = try repository.search(keyword: query.keywordText, filter: filter, limit: limit)
        guard !query.keywordText.isEmpty else { return candidates }
        return candidates.sorted {
            let lhs = ranker.score(item: $0, query: query.keywordText, now: now)
            let rhs = ranker.score(item: $1, query: query.keywordText, now: now)
            if lhs == rhs {
                if $0.capturedAt == $1.capturedAt {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return $0.capturedAt > $1.capturedAt
            }
            return lhs > rhs
        }
    }
}

public struct SearchRanker: Sendable {
    public init() {}

    public func score(item: ClipItem, query: String, now: Date) -> Int {
        let text = item.previewText.lowercased()
        let query = query.lowercased()
        var score = 0
        if text == query { score += 1000 }
        if text.hasPrefix(query) { score += 300 }
        if text.contains(query) { score += 100 }
        if item.isFavorite { score += 200 }
        let age = max(0, now.timeIntervalSince(item.capturedAt))
        score += max(0, 100 - Int(age / 3600))
        return score
    }
}

private extension String {
    func removePrefix(_ prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }
}
