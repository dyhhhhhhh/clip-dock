import AppKit
import ClipDockCore
import SwiftUI

struct LauncherResultsList: View {
    let displayedItems: [ClipItem]
    let isEmpty: Bool
    let selectedID: ClipItem.ID?
    let select: (ClipItem) -> Void
    let restore: (ClipItem) -> Void
    let toggleFavorite: (ClipItem) -> Void
    let openExternally: (ClipItem) -> Void
    let revealInFinder: (ClipItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(displayedItems) { item in
                LauncherRowView(
                    item: item,
                    isSelected: item.id == selectedID,
                    toggleFavorite: {
                        toggleFavorite(item)
                    },
                    openExternally: {
                        openExternally(item)
                    },
                    revealInFinder: {
                        revealInFinder(item)
                    },
                )
                .equatable()
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    restore(item)
                }
                .onTapGesture {
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
    let toggleFavorite: () -> Void
    let openExternally: () -> Void
    let revealInFinder: () -> Void
    @State private var isHovering = false

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
                } else {
                    Text(item.primaryType.label)
                        .font(.caption)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.72) : Design.muted)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Spacer()

            Group {
                if isHovering {
                    HStack(spacing: 5) {
                        if let openSystemImageName = item.openSystemImageName {
                            rowIconButton(
                                systemImage: openSystemImageName,
                                title: item.openActionTitle,
                                identifier: "clipdock.launcher.row.\(item.id.uuidString).open",
                                action: openExternally,
                            )
                        }
                        if item.filePresentation != nil {
                            rowIconButton(
                                systemImage: "folder",
                                title: "在 Finder 中显示",
                                identifier: "clipdock.launcher.row.\(item.id.uuidString).finder",
                                action: revealInFinder,
                            )
                        }
                        rowIconButton(
                            systemImage: item.isFavorite ? "star.fill" : "star",
                            title: item.isFavorite ? "取消收藏" : "收藏",
                            isActive: item.isFavorite,
                            identifier: "clipdock.launcher.row.\(item.id.uuidString).favorite",
                            action: toggleFavorite,
                        )
                    }
                    .transition(.opacity)
                } else {
                    HStack(spacing: 8) {
                        Text(DatePresentation.relative(item.capturedAt))
                            .font(.caption)
                            .foregroundStyle(isSelected ? Color.white.opacity(0.72) : Design.muted)
                        if item.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.white : Design.primary)
                        }
                    }
                }
            }
            .frame(minWidth: 86, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
        .background(rowBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovering && !isSelected ? Design.hairline.opacity(0.95) : Color.clear, lineWidth: 1),
        )
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .foregroundStyle(isSelected ? Color.white : Design.ink)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("clipdock.launcher.row.\(item.id.uuidString)")
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? Design.primary : (isHovering ? Design.surface2 : Color.clear))
    }

    @ViewBuilder private var thumbnail: some View {
        if let filePresentation = item.filePresentation {
            Image(nsImage: filePresentation.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .background(isSelected ? Color.white.opacity(0.16) : Design.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.white.opacity(0.2) : Design.hairline, lineWidth: 1),
                )
        } else if item.primaryType == .image,
           let payloadRef = item.payloadRef,
           let image = ImageThumbnailCache.shared.thumbnail(for: payloadRef) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.white.opacity(0.2) : Design.hairline, lineWidth: 1),
                )
        } else {
            Image(systemName: item.primaryType.systemImageName)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(isSelected ? Color.white.opacity(0.16) : Design.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func rowIconButton(
        systemImage: String,
        title: String,
        isActive: Bool = false,
        identifier: String,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : (isActive ? Design.primary : Design.ink))
                .frame(width: 26, height: 26)
                .background(isSelected ? Color.white.opacity(0.14) : (isActive ? Design.primary.opacity(0.18) : Design.surface1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.white.opacity(0.22) : (isActive ? Design.primary.opacity(0.45) : Design.hairline), lineWidth: 1),
                )
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
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

private extension ClipItem {
    var openSystemImageName: String? {
        switch primaryType {
        case .image: "eye"
        case .url: "safari"
        case .text: "text.alignleft"
        case .file: "arrow.up.right.square"
        case .unknown: nil
        }
    }

    var openActionTitle: String {
        switch primaryType {
        case .image: "打开图片"
        case .url: "用浏览器打开"
        case .text: "用文本编辑器打开"
        case .file: "打开文件"
        case .unknown: "打开"
        }
    }
}
