import AppKit
import ClipDockCore
import SwiftUI

struct DetailPaneView: View {
    let item: ClipItem?
    let openExternally: (ClipItem) -> Void
    let revealInFinder: (ClipItem) -> Void
    let restore: (ClipItem) -> Void
    let toggleFavorite: (ClipItem) -> Void
    let delete: (ClipItem) -> Void
    @State private var showingProperties = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let item {
                HStack {
                    Text("预览")
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    if let openSystemImageName = item.openSystemImageName {
                        detailIconButton(systemImage: openSystemImageName, title: item.openActionTitle) {
                            openExternally(item)
                        }
                    }
                    if item.filePresentation != nil {
                        detailIconButton(systemImage: "folder", title: "在 Finder 中显示") {
                            revealInFinder(item)
                        }
                    }
                    detailIconButton(systemImage: "doc.on.clipboard", title: "复制到剪贴板") {
                        restore(item)
                    }
                    detailIconButton(systemImage: item.isFavorite ? "star.fill" : "star", title: item.isFavorite ? "取消收藏" : "收藏", isActive: item.isFavorite) {
                        toggleFavorite(item)
                    }
                    detailIconButton(systemImage: "trash", title: "删除", isDestructive: true) {
                        delete(item)
                    }
                    detailIconButton(systemImage: "info.circle", title: "属性", isActive: showingProperties) {
                        showingProperties.toggle()
                    }
                    .popover(isPresented: $showingProperties, arrowEdge: .bottom) {
                        propertyPopover(for: item)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity)

                previewContent(for: item)
                    .frame(maxWidth: .infinity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)
            } else {
                ContentUnavailableView("没有选中项目", systemImage: "doc.text.magnifyingglass")
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(20)
        .background(Design.canvas)
        .accessibilityIdentifier("clipdock.history.detailPane")
    }

    @ViewBuilder private func previewContent(for item: ClipItem) -> some View {
        ZStack(alignment: .topLeading) {
            previewBody(for: item)
        }
        .background(Design.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Design.hairline, lineWidth: 1),
        )
    }

    @ViewBuilder private func previewBody(for item: ClipItem) -> some View {
        if item.primaryType == .image, let image = previewImage(for: item) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let filePresentation = item.filePresentation {
            VStack(alignment: .leading, spacing: 14) {
                Image(nsImage: filePresentation.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 6) {
                    Text(filePresentation.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(2)
                    Text(filePresentation.displayPath)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Design.muted)
                        .textSelection(.enabled)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ScrollView {
                Text(item.previewText)
                    .font(item.primaryType == .text ? .system(.body, design: .monospaced) : .system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func previewImage(for item: ClipItem) -> NSImage? {
        guard let payloadRef = item.payloadRef else { return nil }
        return ImageThumbnailCache.shared.thumbnail(for: payloadRef, maxPixelSize: 900)
    }

    private func detailIconButton(
        systemImage: String,
        title: String,
        isActive: Bool = false,
        isDestructive: Bool = false,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isDestructive ? Design.danger : (isActive ? Design.primary : Design.ink))
                .frame(width: 32, height: 32)
                .background(isDestructive ? Design.danger.opacity(0.18) : (isActive ? Design.primary.opacity(0.18) : Design.surface2))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isDestructive ? Design.danger.opacity(0.35) : (isActive ? Design.primary.opacity(0.45) : Design.hairline), lineWidth: 1),
                )
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }

    private func propertyPopover(for item: ClipItem) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
            GridRow { Text("来源"); Text(item.sourceApp?.displayName ?? "未知") }
            GridRow { Text("时间"); Text(DatePresentation.absolute(item.capturedAt)) }
            GridRow { Text("类型"); Text(item.primaryType.label) }
            GridRow { Text("大小"); Text("\(item.byteSize) 字节") }
            if let filePresentation = item.filePresentation {
                GridRow { Text("路径"); Text(filePresentation.displayPath).textSelection(.enabled) }
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Design.ink)
        .padding(16)
        .background(Design.surface1)
        .clipDockPanel()
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
