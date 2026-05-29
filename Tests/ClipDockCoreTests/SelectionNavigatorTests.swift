@testable import ClipDockCore
import XCTest

final class SelectionNavigatorTests: XCTestCase {
    func testSelectsFirstItemWhenCurrentSelectionIsMissing() {
        let items = [
            ClipItem.fixture(contentHash: "a"),
            ClipItem.fixture(contentHash: "b"),
        ]

        let selected = SelectionNavigator.move(from: nil, in: items, direction: .down)

        XCTAssertEqual(selected, items[0].id)
    }

    func testMovesDownAndUpWithinItems() {
        let items = [
            ClipItem.fixture(contentHash: "a"),
            ClipItem.fixture(contentHash: "b"),
            ClipItem.fixture(contentHash: "c"),
        ]

        XCTAssertEqual(SelectionNavigator.move(from: items[0].id, in: items, direction: .down), items[1].id)
        XCTAssertEqual(SelectionNavigator.move(from: items[1].id, in: items, direction: .up), items[0].id)
    }

    func testClampsAtEdges() {
        let items = [
            ClipItem.fixture(contentHash: "a"),
            ClipItem.fixture(contentHash: "b"),
        ]

        XCTAssertEqual(SelectionNavigator.move(from: items[0].id, in: items, direction: .up), items[0].id)
        XCTAssertEqual(SelectionNavigator.move(from: items[1].id, in: items, direction: .down), items[1].id)
    }

    func testReturnsNilWhenItemsAreEmpty() {
        XCTAssertNil(SelectionNavigator.move(from: nil, in: [], direction: .down))
    }
}
