@testable import ClipDockCore
import XCTest

final class PreviewStateTests: XCTestCase {
    func testTogglesPreviewForSelectedItem() {
        let item = ClipItem.fixture(contentHash: "a")
        var state = PreviewState()

        state.toggle(itemID: item.id)
        XCTAssertEqual(state.previewedItemID, item.id)
        XCTAssertTrue(state.isPresented)

        state.toggle(itemID: item.id)
        XCTAssertNil(state.previewedItemID)
        XCTAssertFalse(state.isPresented)
    }

    func testSwitchesPreviewWhenDifferentItemIsSelected() {
        let first = ClipItem.fixture(contentHash: "a")
        let second = ClipItem.fixture(contentHash: "b")
        var state = PreviewState(previewedItemID: first.id)

        state.toggle(itemID: second.id)

        XCTAssertEqual(state.previewedItemID, second.id)
        XCTAssertTrue(state.isPresented)
    }

    func testDismissClearsPreview() {
        let item = ClipItem.fixture(contentHash: "a")
        var state = PreviewState(previewedItemID: item.id)

        state.dismiss()

        XCTAssertNil(state.previewedItemID)
        XCTAssertFalse(state.isPresented)
    }
}
