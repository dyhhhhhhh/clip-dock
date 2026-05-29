import ClipDockCore
import SwiftUI

enum HistoryWindowMetrics {
    static let sidebarWidth: CGFloat = 208
    static let listMinWidth: CGFloat = 500
    static let listIdealWidth: CGFloat = 560
    static let detailMinWidth: CGFloat = 420
    static let detailIdealWidth: CGFloat = 460
    static let windowMinWidth: CGFloat = sidebarWidth + listMinWidth + detailMinWidth + 2
    static let windowIdealWidth: CGFloat = sidebarWidth + listIdealWidth + detailIdealWidth + 2
    static let windowMinHeight: CGFloat = 620
}

enum HistorySortOption: String, CaseIterable, Identifiable {
    case newest
    case oldest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: "最新在前"
        case .oldest: "最早在前"
        }
    }

    var systemImageName: String {
        switch self {
        case .newest: "arrow.down"
        case .oldest: "arrow.up"
        }
    }

    func sorted(_ items: [ClipItem]) -> [ClipItem] {
        items.sorted { lhs, rhs in
            switch self {
            case .newest:
                if lhs.capturedAt == rhs.capturedAt {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.capturedAt > rhs.capturedAt
            case .oldest:
                if lhs.capturedAt == rhs.capturedAt {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.capturedAt < rhs.capturedAt
            }
        }
    }
}

enum HistoryFilter: String, Identifiable, CaseIterable {
    case all
    case text
    case url
    case image
    case file
    case favorite
    case ignored
    case trash

    static let primaryCases: [HistoryFilter] = [.all, .text, .url, .image, .file, .favorite]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .text: "文本"
        case .url: "链接"
        case .image: "图片"
        case .file: "文件"
        case .favorite: "收藏"
        case .ignored: "已忽略"
        case .trash: "回收站"
        }
    }

    var systemImageName: String {
        switch self {
        case .all: "tray.full"
        case .text: "doc.text"
        case .url: "link"
        case .image: "photo"
        case .file: "doc"
        case .favorite: "star"
        case .ignored: "xmark.circle"
        case .trash: "trash"
        }
    }

    var queryPrefix: String {
        switch self {
        case .all: ""
        case .text: "type:text "
        case .url: "type:url "
        case .image: "type:image "
        case .file: "type:file "
        case .favorite: "is:favorite "
        case .ignored, .trash: ""
        }
    }

    func matches(_ item: ClipItem) -> Bool {
        switch self {
        case .all: true
        case .text: item.primaryType == .text
        case .url: item.primaryType == .url
        case .image: item.primaryType == .image
        case .file: item.primaryType == .file
        case .favorite: item.isFavorite
        case .ignored, .trash: false
        }
    }

    func count(in items: [ClipItem]) -> Int {
        items.filter(matches).count
    }
}
