import Foundation

public final class PayloadStore {
    private let directory: URL

    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func saveImagePayload(_ data: Data, contentHash: String, settings: UserSettings) throws -> String? {
        guard settings.saveImages else { return nil }
        let fileExtension = ImagePayloadFile.preferredExtension(for: data)
        let url = directory.appendingPathComponent("\(contentHash).\(fileExtension)")
        try data.write(to: url, options: [.atomic])
        return url.path
    }

    public func deletePayload(ref: String?) throws {
        guard let ref, FileManager.default.fileExists(atPath: ref) else { return }
        guard isManagedPayloadPath(ref) else { return }
        try FileManager.default.removeItem(atPath: ref)
    }

    public func clear() throws {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for file in files {
            try FileManager.default.removeItem(at: file)
        }
    }

    public func byteSize() throws -> Int64 {
        try FileManager.default.clipDockDirectoryByteSize(at: directory)
    }

    private func isManagedPayloadPath(_ path: String) -> Bool {
        let payloadURL = URL(fileURLWithPath: path).standardizedFileURL
        let directoryPath = directory.standardizedFileURL.path
        return payloadURL.path.hasPrefix(directoryPath + "/")
    }
}

extension FileManager {
    func clipDockDirectoryByteSize(at directory: URL) throws -> Int64 {
        guard fileExists(atPath: directory.path) else { return 0 }
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = enumerator(at: directory, includingPropertiesForKeys: Array(keys)) else {
            return 0
        }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: keys)
            guard values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}

public enum ImagePayloadFile {
    public static func preferredExtension(for data: Data) -> String {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            return "png"
        }
        if data.starts(with: [0x49, 0x49, 0x2A, 0x00]) || data.starts(with: [0x4D, 0x4D, 0x00, 0x2A]) {
            return "tiff"
        }
        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "jpg"
        }
        if data.starts(with: [0x47, 0x49, 0x46, 0x38]) {
            return "gif"
        }
        return "bin"
    }
}
