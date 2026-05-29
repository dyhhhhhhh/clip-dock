import Foundation

public enum LauncherKeyCommand: Equatable, Sendable {
    case delete
    case toggleFavorite

    public static func resolve(key: String, modifiers: Set<KeyboardModifier>) -> LauncherKeyCommand? {
        guard modifiers == [.command] else { return nil }
        switch key.lowercased() {
        case "d":
            return .delete
        case "p":
            return .toggleFavorite
        default:
            return nil
        }
    }
}
