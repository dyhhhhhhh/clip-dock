@testable import ClipDockCore
import XCTest

final class KeyboardShortcutTests: XCTestCase {
    func testParsesSymbolShortcut() {
        let shortcut = KeyboardShortcutSpec.parse("⌘⇧V")

        XCTAssertEqual(shortcut?.key, "v")
        XCTAssertEqual(shortcut?.modifiers, [.command, .shift])
    }

    func testParsesWordShortcut() {
        let shortcut = KeyboardShortcutSpec.parse("cmd+option+space")

        XCTAssertEqual(shortcut?.key, "space")
        XCTAssertEqual(shortcut?.modifiers, [.command, .option])
    }

    func testRejectsShortcutWithoutModifier() {
        XCTAssertNil(KeyboardShortcutSpec.parse("v"))
    }

    func testMapsSupportedShortcutsToCarbonKeyCodesAndModifiers() {
        let shortcut = KeyboardShortcutSpec.parse("cmd+shift+v")

        XCTAssertEqual(shortcut?.carbonKeyCode, 9)
        XCTAssertEqual(shortcut?.carbonModifierFlags, 768)
    }

    func testMapsNamedKeysToCarbonKeyCodes() {
        XCTAssertEqual(KeyboardShortcutSpec.parse("cmd+option+space")?.carbonKeyCode, 49)
        XCTAssertEqual(KeyboardShortcutSpec.parse("cmd+return")?.carbonKeyCode, 36)
        XCTAssertEqual(KeyboardShortcutSpec.parse("cmd+escape")?.carbonKeyCode, 53)
    }

    func testFormatsShortcutForDisplayAfterRecording() {
        XCTAssertEqual(KeyboardShortcutSpec(key: "v", modifiers: [.command, .shift]).displayString, "⌘⇧V")
        XCTAssertEqual(KeyboardShortcutSpec(key: "space", modifiers: [.command, .option]).displayString, "⌘⌥Space")
    }

    func testShortcutDraftRevertsInvalidEditsToCommittedValue() {
        var draft = KeyboardShortcutDraft(committedValue: "⌘⇧V")

        draft.clear()
        XCTAssertEqual(draft.draftValue, "")
        XCTAssertNil(draft.finishEditing())

        XCTAssertEqual(draft.draftValue, "⌘⇧V")
        XCTAssertEqual(draft.committedValue, "⌘⇧V")
    }

    func testShortcutDraftCommitsValidRecordedShortcut() {
        var draft = KeyboardShortcutDraft(committedValue: "⌘⇧V")

        let committed = draft.record(KeyboardShortcutSpec(key: "space", modifiers: [.command, .option]))

        XCTAssertEqual(committed, "⌘⌥Space")
        XCTAssertEqual(draft.draftValue, "⌘⌥Space")
        XCTAssertEqual(draft.committedValue, "⌘⌥Space")
    }
}
