import AppKit
import ClipDockCore
import SwiftUI

struct LauncherResultsList: View {
    let displayedItems: [ClipItem]
    let isEmpty: Bool
    let selectedID: ClipItem.ID?
    let select: (ClipItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(displayedItems) { item in
                LauncherRowView(
                    item: item,
                    isSelected: item.id == selectedID,
                )
                .equatable()
                .contentShape(Rectangle())
                .onImmediatePress {
                    select(item)
                }
                if item.id != displayedItems.last?.id {
                    Divider()
                }
            }
            if isEmpty {
                ContentUnavailableView("没有匹配内容", systemImage: "doc.text.magnifyingglass")
                    .frame(height: 220)
            }
        }
        .background(Design.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Design.hairline, lineWidth: 1),
        )
    }
}

struct LauncherRowView: View, Equatable {
    let item: ClipItem
    let isSelected: Bool

    static func == (lhs: LauncherRowView, rhs: LauncherRowView) -> Bool {
        lhs.item == rhs.item && lhs.isSelected == rhs.isSelected
    }

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                if let filePresentation = item.filePresentation {
                    Text(filePresentation.displayPath)
                        .font(.caption)
                        .foregroundStyle(Design.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if item.primaryType == .image {
                    Text("\(item.primaryType.label) · \(ByteCountFormatter.string(fromByteCount: Int64(item.byteSize), countStyle: .file))")
                        .font(.caption)
                        .foregroundStyle(Design.muted)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(DatePresentation.relative(item.capturedAt))
                    .font(.caption)
                    .foregroundStyle(Design.muted)
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Design.primary)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
        .background(isSelected ? Design.primary.opacity(0.20) : Color.clear)
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle()
                    .fill(Design.primary)
                    .frame(width: 3)
            }
        }
    }

    @ViewBuilder private var thumbnail: some View {
        if let filePresentation = item.filePresentation {
            Image(nsImage: filePresentation.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .background(isSelected ? Design.primary.opacity(0.18) : Design.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Image(systemName: item.primaryType.systemImageName)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 34, height: 34)
                .background(isSelected ? Design.primary.opacity(0.18) : Design.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

private extension ClipType {
    var label: String {
        switch self {
        case .text: "文本"
        case .url: "链接"
        case .image: "图片"
        case .file: "文件"
        case .unknown: "未知"
        }
    }

    var systemImageName: String {
        switch self {
        case .text: "chevron.left.forwardslash.chevron.right"
        case .url: "link"
        case .image: "photo"
        case .file: "doc"
        case .unknown: "questionmark.square"
        }
    }
}
