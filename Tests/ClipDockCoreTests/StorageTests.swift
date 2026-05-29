@testable import ClipDockCore
import XCTest

final class StorageTests: XCTestCase {
    func testInMemoryRepositoryCRUDFavoriteDeleteClearAndDeduplicate() throws {
        let repository = InMemoryClipRepository()
        let first = ClipItem.fixture(contentHash: "same", previewText: "A")
        let duplicate = ClipItem.fixture(contentHash: "same", previewText: "A later")

        try repository.upsert(first)
        try repository.upsert(duplicate)
        XCTAssertEqual(try repository.recent(limit: 10).count, 1)
        XCTAssertEqual(try repository.recent(limit: 10).first?.previewText, "A later")

        try repository.setFavorite(true, id: first.id)
        XCTAssertTrue(try XCTUnwrap(repository.item(id: first.id)).isFavorite)

        try repository.delete(id: first.id)
        XCTAssertEqual(try repository.recent(limit: 10).count, 0)

        try repository.upsert(ClipItem.fixture(contentHash: "b"))
        try repository.clear()
        XCTAssertEqual(try repository.recent(limit: 10).count, 0)
    }

    func testSQLiteRepositoryPersistsAcrossInitialization() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let firstRepository = try SQLiteClipRepository(directory: directory)
        try firstRepository.upsert(ClipItem.fixture(contentHash: "persisted", previewText: "Saved"))

        let secondRepository = try SQLiteClipRepository(directory: directory)
        let items = try secondRepository.recent(limit: 10)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.previewText, "Saved")
        XCTAssertEqual(secondRepository.schemaVersion, 1)
    }

    func testSQLiteRepositoryCleansPayloadsWhenDeletingAndClearing() throws {
        let directory = try temporaryDirectory()
        let payloadDirectory = directory.appendingPathComponent("Payloads", isDirectory: true)
        try FileManager.default.createDirectory(at: payloadDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payloadStore = try PayloadStore(directory: payloadDirectory)
        let repository = try SQLiteClipRepository(directory: directory, payloadStore: payloadStore)
        let firstPayload = try XCTUnwrap(payloadStore.saveImagePayload(Data([1, 2, 3]), contentHash: "image-one", settings: .defaults))
        var first = ClipItem.fixture(contentHash: "image-one", primaryType: .image, payload: .image(ImagePayload(byteCount: 3)), previewText: "Image")
        first.payloadRef = firstPayload

        try repository.upsert(first)
        try repository.delete(id: first.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstPayload))

        let secondPayload = try XCTUnwrap(payloadStore.saveImagePayload(Data([4, 5, 6]), contentHash: "image-two", settings: .defaults))
        var second = ClipItem.fixture(contentHash: "image-two", primaryType: .image, payload: .image(ImagePayload(byteCount: 3)), previewText: "Image")
        second.payloadRef = secondPayload
        try repository.upsert(second)
        try repository.clear()
        XCTAssertFalse(FileManager.default.fileExists(atPath: secondPayload))
    }

    func testSQLiteRepositoryCRUDSearchFavoriteDeleteClearAndDeduplicate() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = try SQLiteClipRepository(directory: directory)
        let first = ClipItem.fixture(
            contentHash: "same",
            primaryType: .text,
            capturedAt: Date(timeIntervalSince1970: 1),
            previewText: "alpha",
        )
        let duplicate = ClipItem.fixture(
            contentHash: "same",
            primaryType: .text,
            capturedAt: Date(timeIntervalSince1970: 2),
            previewText: "alpha updated",
        )
        let url = ClipItem.fixture(
            contentHash: "url",
            primaryType: .url,
            capturedAt: Date(timeIntervalSince1970: 3),
            isFavorite: true,
            payload: .url("https://clipdock.app"),
            previewText: "https://clipdock.app",
        )

        try repository.upsert(first)
        try repository.upsert(duplicate)
        try repository.upsert(url)

        XCTAssertEqual(try repository.recent(limit: 10).map(\.contentHash), ["url", "same"])
        XCTAssertEqual(try repository.item(id: first.id)?.previewText, "alpha updated")
        XCTAssertEqual(try repository.search(keyword: "clipdock", filter: ClipRepositoryFilter(type: .url), limit: 10).map(\.contentHash), ["url"])
        XCTAssertEqual(try repository.search(keyword: "", filter: ClipRepositoryFilter(favoriteOnly: true), limit: 10).map(\.contentHash), ["url"])

        try repository.setFavorite(true, id: first.id)
        XCTAssertTrue(try XCTUnwrap(repository.item(id: first.id)).isFavorite)

        try repository.markUsed(id: first.id, at: Date(timeIntervalSince1970: 4))
        XCTAssertEqual(try repository.item(id: first.id)?.useCount, 1)
        XCTAssertEqual(try repository.item(id: first.id)?.lastUsedAt, Date(timeIntervalSince1970: 4))

        try repository.delete(id: first.id)
        XCTAssertNil(try repository.item(id: first.id))

        try repository.clear()
        XCTAssertTrue(try repository.recent(limit: 10).isEmpty)
    }

    func testSQLiteRepositoryReportsStorageStats() throws {
        let directory = try temporaryDirectory()
        let payloadDirectory = directory.appendingPathComponent("Payloads", isDirectory: true)
        try FileManager.default.createDirectory(at: payloadDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payloadStore = try PayloadStore(directory: payloadDirectory)
        let repository = try SQLiteClipRepository(directory: directory, payloadStore: payloadStore)
        let payloadRef = try XCTUnwrap(payloadStore.saveImagePayload(Data(repeating: 7, count: 64), contentHash: "image-stats", settings: .defaults))
        var item = ClipItem.fixture(contentHash: "image-stats", primaryType: .image, payload: .image(ImagePayload(byteCount: 64)), previewText: "Image")
        item.payloadRef = payloadRef

        try repository.upsert(item)
        let stats = try repository.storageStats(settings: UserSettings(maxHistoryCount: 500))

        XCTAssertEqual(stats.itemCount, 1)
        XCTAssertEqual(stats.maxHistoryCount, 500)
        XCTAssertGreaterThan(stats.databaseByteSize, 0)
        XCTAssertEqual(stats.payloadByteSize, 64)
        XCTAssertEqual(stats.totalByteSize, stats.databaseByteSize + stats.payloadByteSize)
    }

    func testPayloadStoreUsesImageExtensionWhenFormatIsKnown() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payloadStore = try PayloadStore(directory: directory)
        let pngHeader = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

        let payload = try XCTUnwrap(payloadStore.saveImagePayload(pngHeader, contentHash: "image-png", settings: .defaults))

        XCTAssertEqual(URL(fileURLWithPath: payload).pathExtension, "png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: payload))
    }

    func testRetentionCleanupRemovesOldAndExcessRecordsButKeepsFavoritesByDefault() throws {
        let repository = InMemoryClipRepository()
        let now = Date(timeIntervalSince1970: 10000)
        let old = ClipItem.fixture(contentHash: "old", capturedAt: now.addingTimeInterval(-90 * 86400))
        let favoriteOld = ClipItem.fixture(contentHash: "favorite-old", capturedAt: now.addingTimeInterval(-90 * 86400), isFavorite: true)
        let fresh = ClipItem.fixture(contentHash: "fresh", capturedAt: now)

        try repository.upsert(old)
        try repository.upsert(favoriteOld)
        try repository.upsert(fresh)
        try repository.enforceRetention(settings: UserSettings(maxHistoryCount: 1, retentionDays: 30), now: now)

        let items = try repository.recent(limit: 10)
        XCTAssertEqual(Set(items.map(\.contentHash)), ["favorite-old", "fresh"])
    }

    func testSQLiteRepositoryRetentionCleanupRemovesAssociatedPayloads() throws {
        let directory = try temporaryDirectory()
        let payloadDirectory = directory.appendingPathComponent("Payloads", isDirectory: true)
        try FileManager.default.createDirectory(at: payloadDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payloadStore = try PayloadStore(directory: payloadDirectory)
        let repository = try SQLiteClipRepository(directory: directory, payloadStore: payloadStore)
        let payload = try XCTUnwrap(payloadStore.saveImagePayload(Data([1, 2, 3]), contentHash: "old-image", settings: .defaults))
        var item = ClipItem.fixture(
            contentHash: "old-image",
            primaryType: .image,
            capturedAt: Date(timeIntervalSince1970: 0),
            payload: .image(ImagePayload(byteCount: 3)),
            previewText: "Image",
        )
        item.payloadRef = payload

        try repository.upsert(item)
        try repository.enforceRetention(settings: UserSettings(maxHistoryCount: 100, retentionDays: 30), now: Date(timeIntervalSince1970: 90 * 86400))

        XCTAssertFalse(FileManager.default.fileExists(atPath: payload))
        XCTAssertTrue(try repository.recent(limit: 10).isEmpty)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
