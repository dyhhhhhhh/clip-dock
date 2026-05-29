import Foundation
#if os(macOS)
import Carbon
#endif

public enum KeyboardModifier: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case command
    case shift
    case option
    case control
}

public struct KeyboardShortcutSpec: Codable, Equatable, Sendable {
    public var key: String
    public var modifiers: Set<KeyboardModifier>

    public init(key: String, modifiers: Set<KeyboardModifier>) {
        self.key = key
        self.modifiers = modifiers
    }

    public static func parse(_ rawValue: String) -> KeyboardShortcutSpec? {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        guard !normalized.isEmpty else { return nil }

        var modifiers = Set<KeyboardModifier>()
        var remainder = normalized

        consume(["⌘", "cmd+", "command+"], from: &remainder) {
            modifiers.insert(.command)
        }
        consume(["⇧", "shift+"], from: &remainder) {
            modifiers.insert(.shift)
        }
        consume(["⌥", "option+", "opt+", "alt+"], from: &remainder) {
            modifiers.insert(.option)
        }
        consume(["⌃", "control+", "ctrl+"], from: &remainder) {
            modifiers.insert(.control)
        }

        guard !modifiers.isEmpty, let key = normalizeKey(remainder) else {
            return nil
        }
        return KeyboardShortcutSpec(key: key, modifiers: modifiers)
    }

    public var displayString: String {
        let modifierText = [
            modifiers.contains(.command) ? "⌘" : nil,
            modifiers.contains(.shift) ? "⇧" : nil,
            modifiers.contains(.option) ? "⌥" : nil,
            modifiers.contains(.control) ? "⌃" : nil,
        ]
        .compactMap { $0 }
        .joined()

        return modifierText + displayKey
    }

    private static func consume(_ prefixes: [String], from value: inout String, action: () -> Void) {
        var consumed = true
        while consumed {
            consumed = false
            for prefix in prefixes where value.hasPrefix(prefix) {
                value.removeFirst(prefix.count)
                action()
                consumed = true
                break
            }
        }
    }

    private static func normalizeKey(_ rawKey: String) -> String? {
        guard !rawKey.isEmpty else { return nil }
        switch rawKey {
        case "space", "spacebar", "␣":
            return "space"
        case "return", "enter", "↩":
            return "return"
        case "esc", "escape", "⎋":
            return "escape"
        default:
            guard rawKey.count == 1, rawKey.rangeOfCharacter(from: .alphanumerics) != nil else {
                return nil
            }
            return rawKey
        }
    }

    private var displayKey: String {
        switch key {
        case "space":
            return "Space"
        case "return":
            return "Return"
        case "escape":
            return "Esc"
        default:
            return key.uppercased()
        }
    }
}

public struct KeyboardShortcutDraft: Equatable, Sendable {
    public private(set) var committedValue: String
    public private(set) var draftValue: String

    public init(committedValue: String) {
        self.committedValue = Self.canonicalValue(for: committedValue)
        draftValue = self.committedValue
    }

    public mutating func updateDraftValue(_ value: String) {
        draftValue = value
    }

    public mutating func clear() {
        draftValue = ""
    }

    @discardableResult
    public mutating func record(_ shortcut: KeyboardShortcutSpec) -> String {
        commit(shortcut.displayString)
    }

    @discardableResult
    public mutating func finishEditing() -> String? {
        guard let shortcut = KeyboardShortcutSpec.parse(draftValue) else {
            draftValue = committedValue
            return nil
        }
        return commit(shortcut.displayString)
    }

    @discardableResult
    private mutating func commit(_ value: String) -> String {
        let canonical = Self.canonicalValue(for: value)
        committedValue = canonical
        draftValue = canonical
        return canonical
    }

    private static func canonicalValue(for value: String) -> String {
        KeyboardShortcutSpec.parse(value)?.displayString ?? value
    }
}

#if os(macOS)
public extension KeyboardShortcutSpec {
    var carbonKeyCode: UInt32? {
        Self.carbonKeyCodes[key]
    }

    var carbonModifierFlags: UInt32 {
        modifiers.reduce(UInt32(0)) { flags, modifier in
            switch modifier {
            case .command:
                flags | UInt32(cmdKey)
            case .shift:
                flags | UInt32(shiftKey)
            case .option:
                flags | UInt32(optionKey)
            case .control:
                flags | UInt32(controlKey)
            }
        }
    }

    private static let carbonKeyCodes: [String: UInt32] = [
        "a": 0,
        "s": 1,
        "d": 2,
        "f": 3,
        "h": 4,
        "g": 5,
        "z": 6,
        "x": 7,
        "c": 8,
        "v": 9,
        "b": 11,
        "q": 12,
        "w": 13,
        "e": 14,
        "r": 15,
        "y": 16,
        "t": 17,
        "1": 18,
        "2": 19,
        "3": 20,
        "4": 21,
        "6": 22,
        "5": 23,
        "9": 25,
        "7": 26,
        "8": 28,
        "0": 29,
        "o": 31,
        "u": 32,
        "i": 34,
        "p": 35,
        "l": 37,
        "j": 38,
        "k": 40,
        "n": 45,
        "m": 46,
        "return": 36,
        "space": 49,
        "escape": 53,
    ]
}
#endif
