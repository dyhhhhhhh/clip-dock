import Foundation

public enum LauncherResultScope {
    public static let defaultVisibleLimit = 8

    public static func visibleItems(from items: [ClipItem], limit: Int = defaultVisibleLimit) -> [ClipItem] {
        Array(items.prefix(max(limit, 0)))
    }
}
