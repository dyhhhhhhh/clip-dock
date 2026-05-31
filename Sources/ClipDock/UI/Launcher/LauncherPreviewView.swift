import AppKit
import ClipDockCore
import SwiftUI

struct LauncherPreviewView: View {
    let item: ClipItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("预览")
                    .font(.caption)
                    .foregroundStyle(Design.muted)
                Spacer()
                Text(item.primaryType.label)
                    .font(.caption)
                    .foregroundStyle(Design.muted)
            }
            if let filePresentation = item.filePresentation {
                HStack(spacing: 12) {
                    Image(nsImage: filePresentation.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 38, height: 38)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(filePresentation.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Text(filePresentation.displayPath)
                            .font(.caption)
                            .foregroundStyle(Design.muted)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Design.surface1)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text(item.previewText)
                    .font(.system(.body, design: item.primaryType == .text ? .monospaced : .default))
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Design.surface1)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("clipdock.launcher.preview")
    }
}

struct LauncherFooter: View {
    var body: some View {
        HStack(spacing: 14) {
            ShortcutHint(key: "Enter", label: "粘贴")
            ShortcutHint(key: "Space", label: "预览")
            ShortcutHint(key: "⌘D", label: "删除")
            ShortcutHint(key: "⌘P", label: "收藏")
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(Design.muted)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("clipdock.launcher.footer")
    }
}

struct ShortcutHint: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Design.surface1)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(label)
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
}
