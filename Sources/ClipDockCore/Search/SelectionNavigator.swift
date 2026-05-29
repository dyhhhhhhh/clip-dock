import Foundation

public enum SelectionDirection: Sendable {
    case up
    case down
}

public enum SelectionNavigator {
    public static func move(from selectedID: ClipItem.ID?, in items: [ClipItem], direction: SelectionDirection) -> ClipItem.ID? {
        guard !items.isEmpty else { return nil }
        guard let selectedID, let currentIndex = items.firstIndex(where: { $0.id == selectedID }) else {
            return items[0].id
        }

        switch direction {
        case .up:
            return items[max(items.startIndex, currentIndex - 1)].id
        case .down:
            return items[min(items.index(before: items.endIndex), currentIndex + 1)].id
        }
    }
}
