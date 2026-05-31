import AppKit
import ClipDockCore
import SwiftUI

struct HistoryListPane: View {
    let items: [ClipItem]
    let selectedID: ClipItem.ID?
    let select: (ClipItem) -> Void
    let restore: (ClipItem) -> Void
    let toggleFavorite: (ClipItem) -> Void
    let openExternally: (ClipItem) -> Void
    let revealInFinder: (ClipItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HistoryTableHeader()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        HistoryTableRow(
                            item: item,
                            isSelected: item.id == selectedID,
                            select: {
                                select(item)
                            },
                            restore: {
                                restore(item)
                            },
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
                        Divider()
                    }
                    if items.isEmpty {
                        ContentUnavailableView("没有历史记录", systemImage: "tray")
                            .frame(minHeight: 260)
                    }
                }
            }
        }
        .frame(minWidth: HistoryWindowMetrics.listMinWidth, idealWidth: HistoryWindowMetrics.listIdealWidth, maxWidth: .infinity)
    }
}

struct HistoryTableHeader: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("内容")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("来源")
                .frame(width: HistoryTableMetrics.sourceWidth, alignment: .leading)
            Text("时间 / 操作")
                .frame(width: HistoryTableMetrics.actionWidth, alignment: .trailing)
        }
        .font(.caption)
        .foregroundStyle(Design.muted)
        .padding(.horizontal, 16)
        .frame(height: 30)
        .background(Design.canvas)
    }
}

struct HistoryTableRow: View, Equatable {
    let item: ClipItem
    let isSelected: Bool
    let select: () -> Void
    let restore: () -> Void
    let toggleFavorite: () -> Void
    let openExternally: () -> Void
    let revealInFinder: () -> Void
    @State private var isHovering = false

    static func == (lhs: HistoryTableRow, rhs: HistoryTableRow) -> Bool {
        lhs.item == rhs.item && lhs.isSelected == rhs.isSelected
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                thumbnail
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.displayTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(item.primaryType.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.72) : Design.muted)
                        .lineLimit(1)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, HistoryTableMetrics.contentSourceSpacing)
            .clipped()

            SourceAppLabel(sourceApp: item.sourceApp, isSelected: isSelected)
                .frame(width: HistoryTableMetrics.sourceWidth, alignment: .leading)
                .layoutPriority(1)

            Group {
                if isHovering || ProcessInfo.processInfo.environment["CLIPDOCK_UI_TEST_MODE"] == "1" {
                    HStack(spacing: 5) {
                        if let openSystemImageName = item.openSystemImageName {
                            rowIconButton(
                                systemImage: openSystemImageName,
                                title: item.openActionTitle,
                                identifier: "clipdock.history.row.\(item.id.uuidString).open",
                                action: openExternally,
                            )
                        }
                        if item.filePresentation != nil {
                            rowIconButton(
                                systemImage: "folder",
                                title: "在 Finder 中显示",
                                identifier: "clipdock.history.row.\(item.id.uuidString).finder",
                                action: revealInFinder,
                            )
                        }
                        rowIconButton(
                            systemImage: item.isFavorite ? "star.fill" : "star",
                            title: item.isFavorite ? "取消收藏" : "收藏",
                            isActive: item.isFavorite,
                            identifier: "clipdock.history.row.\(item.id.uuidString).favorite",
                            action: toggleFavorite,
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
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
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .frame(width: HistoryTableMetrics.actionWidth, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 50)
        .background(rowBackground)
        .overlay(alignment: .leading) {
            GeometryReader { proxy in
                HistoryRowClickCapture(
                    singleClick: select,
                    doubleClick: restore,
                    hoverChanged: { hovering in
                        withAnimation(.easeOut(duration: 0.12)) {
                            isHovering = hovering
                        }
                    },
                )
                .frame(
                    width: max(0, proxy.size.width - HistoryTableMetrics.actionWidth),
                    height: proxy.size.height,
                    alignment: .leading,
                )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovering && !isSelected ? Design.hairline.opacity(0.95) : Color.clear, lineWidth: 1)
                .allowsHitTesting(false),
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
        .accessibilityIdentifier("clipdock.history.row.\(item.id.uuidString)")
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
                .frame(width: 32, height: 32)
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
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.white.opacity(0.2) : Design.hairline, lineWidth: 1),
                )
        } else {
            Image(systemName: item.primaryType.systemImageName)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 32, height: 32)
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

private struct HistoryRowClickCapture: NSViewRepresentable {
    let singleClick: () -> Void
    let doubleClick: () -> Void
    let hoverChanged: (Bool) -> Void

    func makeNSView(context: Context) -> HistoryRowClickCaptureView {
        let view = HistoryRowClickCaptureView()
        view.singleClick = singleClick
        view.doubleClick = doubleClick
        view.hoverChanged = hoverChanged
        return view
    }

    func updateNSView(_ nsView: HistoryRowClickCaptureView, context: Context) {
        nsView.singleClick = singleClick
        nsView.doubleClick = doubleClick
        nsView.hoverChanged = hoverChanged
    }
}

private final class HistoryRowClickCaptureView: NSView {
    var singleClick: () -> Void = {}
    var doubleClick: () -> Void = {}
    var hoverChanged: (Bool) -> Void = { _ in }

    private var trackingAreaToken: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaToken {
            removeTrackingArea(trackingAreaToken)
        }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil,
        )
        addTrackingArea(trackingArea)
        trackingAreaToken = trackingArea
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2 {
            doubleClick()
        } else {
            singleClick()
        }
    }

    override func mouseEntered(with event: NSEvent) {
        hoverChanged(true)
    }

    override func mouseExited(with event: NSEvent) {
        hoverChanged(false)
    }

    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }
}

struct SourceAppLabel: View {
    let sourceApp: SourceAppMetadata?
    let isSelected: Bool

    var body: some View {
        let presentation = SourceAppPresentation.resolve(sourceApp)

        HStack(spacing: 6) {
            Image(nsImage: presentation.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(presentation.name)
                .font(.caption)
                .foregroundStyle(isSelected ? Color.white.opacity(0.72) : Design.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum HistoryTableMetrics {
    static let sourceWidth: CGFloat = 112
    static let actionWidth: CGFloat = 88
    static let contentSourceSpacing: CGFloat = 18
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
