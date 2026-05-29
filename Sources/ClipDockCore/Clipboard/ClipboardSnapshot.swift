import Foundation

public struct ClipboardSnapshot: Equatable, Sendable {
    public var declaredTypes: [String]
    public var sourceApp: SourceAppMetadata?
    public var estimatedByteSize: Int
    public var previewText: String?

    public init(
        declaredTypes: [String],
        sourceApp: SourceAppMetadata? = nil,
        estimatedByteSize: Int = 0,
        previewText: String? = nil,
    ) {
        self.declaredTypes = declaredTypes
        self.sourceApp = sourceApp
        self.estimatedByteSize = estimatedByteSize
        self.previewText = previewText
    }

    public static func text(_ value: String) -> ClipboardSnapshot {
        ClipboardSnapshot(
            declaredTypes: ["public.utf8-plain-text"],
            estimatedByteSize: value.utf8.count,
            previewText: value,
        )
    }
}

public struct ClipboardChangeEvent: Equatable, Sendable {
    public var changeCount: Int
    public init(changeCount: Int) {
        self.changeCount = changeCount
    }
}
