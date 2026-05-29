import AppKit
import ClipDockCore
import SwiftUI

struct ClipRowView: View {
    let item: ClipItem
    var compact = false

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayTitle)
                    .lineLimit(compact ? 1 : 2)
                    .font(.system(size: compact ? 13 : 14, weight: .medium))
                HStack(spacing: 8) {
                    Text(item.sourceApp?.displayName ?? "未知来源")
                    Text(DatePresentation.relative(item.capturedAt))
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(Design.muted)
            }
            Spacer()
        }
        .padding(.vertical, compact ? 4 : 8)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var thumbnail: some View {
        if let filePresentation = item.filePresentation {
            Image(nsImage: filePresentation.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .background(Design.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Image(systemName: item.primaryType.systemImageName)
                .frame(width: 28, height: 28)
                .background(Design.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

private extension ClipType {
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
