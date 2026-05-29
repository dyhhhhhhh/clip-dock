import Foundation
import GRDB

public final class SQLiteClipRepository: ClipRepository {
    public let schemaVersion = 1

    private let directory: URL
    private let databaseURL: URL
    private let payloadStore: PayloadStore?
    private let databaseQueue: DatabaseQueue

    public init(directory: URL, payloadStore: PayloadStore? = nil) throws {
        self.directory = directory
        self.payloadStore = payloadStore
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        databaseURL = directory.appendingPathComponent("clips.sqlite")
        databaseQueue = try DatabaseQueue(path: databaseURL.path)
        try migrate()
    }

    public static func defaultDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true,
        )
        return base.appendingPathComponent("ClipDock", isDirectory: true)
    }

    public func upsert(_ item: ClipItem) throws {
        try databaseQueue.write { db in
            if let existing = try fetchItem(
                db,
                sql: "SELECT * FROM clips WHERE primary_type = ? AND content_hash = ? LIMIT 1",
                arguments: [item.primaryType.rawValue, item.contentHash],
            ) {
                var stored = item
                stored.id = existing.id
                stored.isFavorite = existing.isFavorite || item.isFavorite
                stored.useCount = existing.useCount
                stored.lastUsedAt = existing.lastUsedAt
                try update(stored, in: db)
            } else {
                try insert(item, in: db)
            }
        }
    }

    public func item(id: UUID) throws -> ClipItem? {
        try databaseQueue.read { db in
            try fetchItem(
                db,
                sql: "SELECT * FROM clips WHERE id = ? LIMIT 1",
                arguments: [id.uuidString],
            )
        }
    }

    public func recent(limit: Int) throws -> [ClipItem] {
        try databaseQueue.read { db in
            try fetchItems(
                db,
                sql: "SELECT * FROM clips ORDER BY captured_at DESC, id ASC LIMIT ?",
                arguments: [max(limit, 0)],
            )
        }
    }

    public func search(keyword: String, filter: ClipRepositoryFilter, limit: Int) throws -> [ClipItem] {
        try databaseQueue.read { db in
            var conditions: [String] = []
            var arguments: StatementArguments = []

            if let type = filter.type {
                conditions.append("primary_type = ?")
                arguments += [type.rawValue]
            }
            if filter.favoriteOnly {
                conditions.append("is_favorite = 1")
            }
            if let before = filter.before {
                conditions.append("captured_at < ?")
                arguments += [before.timeIntervalSince1970]
            }
            if let source = filter.sourceAppKeyword?.lowercased(), !source.isEmpty {
                conditions.append("(LOWER(COALESCE(source_app_name, '')) LIKE ? OR LOWER(COALESCE(source_bundle_identifier, '')) LIKE ?)")
                let pattern = "%\(source)%"
                arguments += [pattern, pattern]
            }
            let loweredKeyword = keyword.lowercased()
            if !loweredKeyword.isEmpty {
                conditions.append("(LOWER(preview_text) LIKE ? OR LOWER(COALESCE(title, '')) LIKE ?)")
                let pattern = "%\(loweredKeyword)%"
                arguments += [pattern, pattern]
            }
            arguments += [max(limit, 0)]

            let whereClause = conditions.isEmpty ? "" : " WHERE \(conditions.joined(separator: " AND "))"
            return try fetchItems(
                db,
                sql: "SELECT * FROM clips\(whereClause) ORDER BY captured_at DESC, id ASC LIMIT ?",
                arguments: arguments,
            )
        }
    }

    public func setFavorite(_ favorite: Bool, id: UUID) throws {
        try databaseQueue.write { db in
            try db.execute(
                sql: "UPDATE clips SET is_favorite = ? WHERE id = ?",
                arguments: [favorite ? 1 : 0, id.uuidString],
            )
        }
    }

    public func markUsed(id: UUID, at date: Date = Date()) throws {
        try databaseQueue.write { db in
            try db.execute(
                sql: "UPDATE clips SET last_used_at = ?, use_count = use_count + 1 WHERE id = ?",
                arguments: [date.timeIntervalSince1970, id.uuidString],
            )
        }
    }

    public func delete(id: UUID) throws {
        let payloadRef = try item(id: id)?.payloadRef
        try databaseQueue.write { db in
            try db.execute(sql: "DELETE FROM clips WHERE id = ?", arguments: [id.uuidString])
        }
        try payloadStore?.deletePayload(ref: payloadRef)
    }

    public func clear() throws {
        try databaseQueue.write { db in
            try db.execute(sql: "DELETE FROM clips")
        }
        try payloadStore?.clear()
    }

    public func enforceRetention(settings: UserSettings, now: Date = Date()) throws {
        let cutoff = now.addingTimeInterval(-TimeInterval(settings.retentionDays) * 86400).timeIntervalSince1970
        let oldRefs = try databaseQueue.read { db in
            try String.fetchAll(
                db,
                sql: "SELECT payload_ref FROM clips WHERE is_favorite = 0 AND captured_at < ? AND payload_ref IS NOT NULL",
                arguments: [cutoff],
            )
        }

        try databaseQueue.write { db in
            try db.execute(
                sql: "DELETE FROM clips WHERE is_favorite = 0 AND captured_at < ?",
                arguments: [cutoff],
            )
        }

        for ref in oldRefs {
            try payloadStore?.deletePayload(ref: ref)
        }

        let allowedNonFavorites = max(settings.maxHistoryCount, 0)
        let excessRows = try databaseQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT id, payload_ref
                FROM clips
                WHERE is_favorite = 0
                ORDER BY captured_at DESC, id ASC
                LIMIT -1 OFFSET ?
                """,
                arguments: [allowedNonFavorites],
            )
        }

        for row in excessRows {
            let id: String = row["id"]
            let payloadRef: String? = row["payload_ref"]
            try databaseQueue.write { db in
                try db.execute(sql: "DELETE FROM clips WHERE id = ?", arguments: [id])
            }
            try payloadStore?.deletePayload(ref: payloadRef)
        }
    }

    public func storageStats(settings: UserSettings) throws -> ClipStorageStats {
        let itemCount = try databaseQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM clips") ?? 0
        }
        let databaseSize = try databaseByteSize()
        let payloadSize = try payloadStore?.byteSize() ?? 0
        return ClipStorageStats(
            itemCount: itemCount,
            maxHistoryCount: settings.maxHistoryCount,
            databaseByteSize: databaseSize,
            payloadByteSize: payloadSize,
            totalByteSize: databaseSize + payloadSize,
        )
    }

    private func migrate() throws {
        try databaseQueue.write { db in
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS clips (
                id TEXT PRIMARY KEY NOT NULL,
                content_hash TEXT NOT NULL,
                primary_type TEXT NOT NULL,
                captured_at REAL NOT NULL,
                last_used_at REAL,
                use_count INTEGER NOT NULL,
                is_favorite INTEGER NOT NULL,
                is_sensitive INTEGER NOT NULL,
                expires_at REAL,
                tags_json TEXT NOT NULL,
                preview_text TEXT NOT NULL,
                title TEXT,
                payload_json TEXT NOT NULL,
                payload_ref TEXT,
                source_app_name TEXT,
                source_bundle_identifier TEXT,
                byte_size INTEGER NOT NULL
            )
            """)
            try db.execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS clips_content_key_idx ON clips(primary_type, content_hash)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS clips_captured_at_idx ON clips(captured_at DESC)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS clips_primary_type_idx ON clips(primary_type)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS clips_is_favorite_idx ON clips(is_favorite)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS clips_source_bundle_identifier_idx ON clips(source_bundle_identifier)")
            try db.execute(sql: "PRAGMA user_version = 1")
        }
    }

    private func insert(_ item: ClipItem, in db: Database) throws {
        try db.execute(
            sql: """
            INSERT INTO clips (
                id,
                content_hash,
                primary_type,
                captured_at,
                last_used_at,
                use_count,
                is_favorite,
                is_sensitive,
                expires_at,
                tags_json,
                preview_text,
                title,
                payload_json,
                payload_ref,
                source_app_name,
                source_bundle_identifier,
                byte_size
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: arguments(for: item),
        )
    }

    private func update(_ item: ClipItem, in db: Database) throws {
        var arguments = try arguments(for: item)
        arguments += [item.id.uuidString]
        try db.execute(
            sql: """
            UPDATE clips
            SET id = ?,
                content_hash = ?,
                primary_type = ?,
                captured_at = ?,
                last_used_at = ?,
                use_count = ?,
                is_favorite = ?,
                is_sensitive = ?,
                expires_at = ?,
                tags_json = ?,
                preview_text = ?,
                title = ?,
                payload_json = ?,
                payload_ref = ?,
                source_app_name = ?,
                source_bundle_identifier = ?,
                byte_size = ?
            WHERE id = ?
            """,
            arguments: arguments,
        )
    }

    private func arguments(for item: ClipItem) throws -> StatementArguments {
        [
            item.id.uuidString,
            item.contentHash,
            item.primaryType.rawValue,
            item.capturedAt.timeIntervalSince1970,
            item.lastUsedAt?.timeIntervalSince1970,
            item.useCount,
            item.isFavorite ? 1 : 0,
            item.isSensitive ? 1 : 0,
            item.expiresAt?.timeIntervalSince1970,
            try encodeJSON(item.tags),
            item.previewText,
            item.title,
            try encodeJSON(item.payload),
            item.payloadRef,
            item.sourceApp?.name,
            item.sourceApp?.bundleIdentifier,
            item.byteSize,
        ]
    }

    private func fetchItem(_ db: Database, sql: String, arguments: StatementArguments = []) throws -> ClipItem? {
        guard let row = try Row.fetchOne(db, sql: sql, arguments: arguments) else { return nil }
        return try decodeItem(row)
    }

    private func fetchItems(_ db: Database, sql: String, arguments: StatementArguments = []) throws -> [ClipItem] {
        try Row.fetchAll(db, sql: sql, arguments: arguments).map(decodeItem)
    }

    private func decodeItem(_ row: Row) throws -> ClipItem {
        let idString: String = row["id"]
        guard let id = UUID(uuidString: idString) else {
            throw SQLiteClipRepositoryError.invalidUUID(idString)
        }
        let typeRawValue: String = row["primary_type"]
        let type = ClipType(rawValue: typeRawValue) ?? .unknown
        let capturedAt: Double = row["captured_at"]
        let lastUsedAtValue: Double? = row["last_used_at"]
        let expiresAtValue: Double? = row["expires_at"]
        let tagsJSON: String = row["tags_json"]
        let payloadJSON: String = row["payload_json"]
        let sourceAppName: String? = row["source_app_name"]
        let sourceBundleIdentifier: String? = row["source_bundle_identifier"]
        let sourceApp: SourceAppMetadata? = sourceAppName == nil && sourceBundleIdentifier == nil
            ? nil
            : SourceAppMetadata(name: sourceAppName, bundleIdentifier: sourceBundleIdentifier)

        return ClipItem(
            id: id,
            contentHash: row["content_hash"],
            primaryType: type,
            capturedAt: Date(timeIntervalSince1970: capturedAt),
            lastUsedAt: lastUsedAtValue.map(Date.init(timeIntervalSince1970:)),
            useCount: row["use_count"],
            isFavorite: (row["is_favorite"] as Int) != 0,
            isSensitive: (row["is_sensitive"] as Int) != 0,
            expiresAt: expiresAtValue.map(Date.init(timeIntervalSince1970:)),
            tags: try decodeJSON([String].self, from: tagsJSON),
            previewText: row["preview_text"],
            title: row["title"],
            payload: try decodeJSON(ClipPayload.self, from: payloadJSON),
            payloadRef: row["payload_ref"],
            sourceApp: sourceApp,
            byteSize: row["byte_size"],
        )
    }

    private func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONEncoder.clipDock.encode(value)
        return String(decoding: data, as: UTF8.self)
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        try JSONDecoder.clipDock.decode(type, from: Data(json.utf8))
    }

    private func databaseByteSize() throws -> Int64 {
        let urls = [
            databaseURL,
            URL(fileURLWithPath: databaseURL.path + "-wal"),
            URL(fileURLWithPath: databaseURL.path + "-shm"),
        ]
        return try urls.reduce(Int64(0)) { total, url in
            guard FileManager.default.fileExists(atPath: url.path) else { return total }
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return total + Int64((attributes[.size] as? NSNumber)?.int64Value ?? 0)
        }
    }
}

public enum SQLiteClipRepositoryError: Error, Equatable {
    case invalidUUID(String)
}
