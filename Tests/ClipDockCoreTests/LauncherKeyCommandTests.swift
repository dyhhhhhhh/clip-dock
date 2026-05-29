@testable import ClipDockCore
import XCTest

final class LauncherKeyCommandTests: XCTestCase {
    func testResolvesCommandDToDelete() {
        XCTAssertEqual(LauncherKeyCommand.resolve(key: "d", modifiers: [.command]), .delete)
    }

    func testResolvesCommandPToToggleFavorite() {
        XCTAssertEqual(LauncherKeyCommand.resolve(key: "p", modifiers: [.command]), .toggleFavorite)
    }

    func testIgnoresCommandsWithoutExactCommandModifier() {
        XCTAssertNil(LauncherKeyCommand.resolve(key: "d", modifiers: []))
        XCTAssertNil(LauncherKeyCommand.resolve(key: "d", modifiers: [.command, .shift]))
        XCTAssertNil(LauncherKeyCommand.resolve(key: "x", modifiers: [.command]))
    }
}
