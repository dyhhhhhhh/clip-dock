import Foundation

public struct PreviewState: Equatable, Sendable {
    public var previewedItemID: ClipItem.ID?

    public init(previewedItemID: ClipItem.ID? = nil) {
        self.previewedItemID = previewedItemID
    }

    public var isPresented: Bool {
        previewedItemID != nil
    }

    public mutating func toggle(itemID: ClipItem.ID?) {
        guard let itemID else {
            dismiss()
            return
        }
        previewedItemID = previewedItemID == itemID ? nil : itemID
    }

    public mutating func dismiss() {
        previewedItemID = nil
    }
}
