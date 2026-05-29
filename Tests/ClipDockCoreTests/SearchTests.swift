@testable import ClipDockCore
import XCTest

final class SearchTests: XCTestCase {
    func testSearchReturnsRecentForEmptyQueryAndFiltersByTypeAndFavorite() throws {
        let repository = InMemoryClipRepository()
        try repository.upsert(ClipItem.fixture(contentHash: "1", primaryType: .text, capturedAt: Date(timeIntervalSince1970: 1), previewText: "alpha"))
        try repository.upsert(ClipItem.fixture(contentHash: "2", primaryType: .url, capturedAt: Date(timeIntervalSince1970: 2), isFavorite: true, previewText: "https://clipdock.app"))
        let service = ClipSearchService(repository: repository)

        XCTAssertEqual(try service.search(.parse("")).map(\.contentHash), ["2", "1"])
        XCTAssertEqual(try service.search(.parse("type:url")).map(\.contentHash), ["2"])
        XCTAssertEqual(try service.search(.parse("is:favorite")).map(\.contentHash), ["2"])
    }

    func testQueryParserGracefullyKeepsUnknownSyntaxAsKeyword() {
        let query = SearchQuery.parse("type:text app:Safari is:favorite before:7d weird:value docker")

        XCTAssertEqual(query.type, .text)
        XCTAssertEqual(query.sourceAppKeyword, "Safari")
        XCTAssertTrue(query.favoriteOnly)
        XCTAssertEqual(query.beforeDays, 7)
        XCTAssertEqual(query.keywords, ["weird:value", "docker"])
    }

    func testSearchRankingIsDeterministic() throws {
        let repository = InMemoryClipRepository()
        try repository.upsert(ClipItem.fixture(contentHash: "prefix", capturedAt: Date(timeIntervalSince1970: 2), previewText: "docker compose"))
        try repository.upsert(ClipItem.fixture(contentHash: "exact", capturedAt: Date(timeIntervalSince1970: 1), isFavorite: true, previewText: "docker"))
        let service = ClipSearchService(repository: repository)

        XCTAssertEqual(try service.search(.parse("docker")).map(\.contentHash), ["exact", "prefix"])
    }

    func testSQLiteSearchMatchesInMemoryFilteringSemantics() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = try SQLiteClipRepository(directory: directory)
        var safariText = ClipItem.fixture(contentHash: "text", primaryType: .text, capturedAt: Date(timeIntervalSince1970: 1), previewText: "docker notes")
        safariText.sourceApp = SourceAppMetadata(name: "Safari", bundleIdentifier: "com.apple.Safari")
        var terminalURL = ClipItem.fixture(contentHash: "url", primaryType: .url, capturedAt: Date(timeIntervalSince1970: 2), isFavorite: true, payload: .url("https://clipdock.app"), previewText: "https://clipdock.app")
        terminalURL.sourceApp = SourceAppMetadata(name: "Terminal", bundleIdentifier: "com.apple.Terminal")

        try repository.upsert(safariText)
        try repository.upsert(terminalURL)

        let service = ClipSearchService(repository: repository)
        XCTAssertEqual(try service.search(.parse("app:Safari docker")).map(\.contentHash), ["text"])
        XCTAssertEqual(try service.search(.parse("type:url is:pinned")).map(\.contentHash), ["url"])
        XCTAssertEqual(try service.search(.parse("before:1d")).map(\.contentHash), ["url", "text"])
    }
}

extension ClipItem {
    static func fixture(
        id: UUID = UUID(),
        contentHash: String = "hash",
        primaryType: ClipType = .text,
        capturedAt: Date = Date(timeIntervalSince1970: 1),
        isFavorite: Bool = false,
        payload: ClipPayload = .text("hello"),
        previewText: String = "hello",
    ) -> ClipItem {
        ClipItem(
            id: id,
            contentHash: contentHash,
            primaryType: primaryType,
            capturedAt: capturedAt,
            lastUsedAt: nil,
            useCount: 0,
            isFavorite: isFavorite,
            previewText: previewText,
            title: nil,
            payload: payload,
            payloadRef: nil,
            sourceApp: nil,
            byteSize: previewText.utf8.count,
        )
    }
}
