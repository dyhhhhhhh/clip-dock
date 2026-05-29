import SwiftUI

struct HistoryToolbarControlLabel: View {
    let title: String
    let leadingSystemImageName: String
    let trailingSystemImageName: String?
    let width: CGFloat
    let isActive: Bool
    let isHovering: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: leadingSystemImageName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isActive ? Design.primary : Design.ink)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 6)
            if let trailingSystemImageName {
                Image(systemName: trailingSystemImageName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isActive ? Design.ink : Design.muted)
            }
        }
        .foregroundStyle(Design.ink)
        .padding(.horizontal, 13)
        .frame(width: width, height: HistoryToolbarMetrics.controlHeight)
        .background(HistoryToolbarControlBackground(isActive: isActive, isHovering: isHovering))
        .contentShape(Rectangle())
    }
}

struct HistoryOptionMenu<Content: View>: View {
    let width: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 4) {
            content
        }
        .padding(6)
        .frame(width: width)
        .foregroundStyle(Design.ink)
        .background(Design.surface1)
        .clipShape(RoundedRectangle(cornerRadius: HistoryToolbarMetrics.optionPopoverRadius))
        .overlay(
            RoundedRectangle(cornerRadius: HistoryToolbarMetrics.optionPopoverRadius)
                .stroke(Design.hairlineStrong.opacity(0.7), lineWidth: 1),
        )
        .shadow(color: .black.opacity(0.34), radius: 16, x: 0, y: 8)
    }
}

struct HistoryOptionRow: View {
    let title: String
    let systemImageName: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImageName)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 16)
                    .foregroundStyle(isSelected ? Color.white : Design.muted)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 8)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(.horizontal, 9)
            .frame(height: 30)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Design.primary : (isHovering ? Design.surface2 : Color.clear))
            .clipShape(RoundedRectangle(cornerRadius: HistoryToolbarMetrics.optionRowRadius))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : Design.ink)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}

struct HistoryToolbarControlBackground: View {
    let isActive: Bool
    let isHovering: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: HistoryToolbarMetrics.controlRadius)
            .fill(isHovering || isActive ? Design.surface3 : Design.surface2)
            .overlay(
                RoundedRectangle(cornerRadius: HistoryToolbarMetrics.controlRadius)
                    .stroke(isActive ? Design.primary.opacity(0.72) : Design.hairlineStrong.opacity(isHovering ? 0.95 : 0.62), lineWidth: isActive ? 1.5 : 1),
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: HistoryToolbarMetrics.controlRadius)
                    .stroke(Color.white.opacity(isHovering || isActive ? 0.10 : 0.05), lineWidth: 1)
            }
            .shadow(color: Design.primary.opacity(isActive ? 0.18 : 0), radius: 8)
    }
}

enum HistoryToolbarDropdown {
    case sort
    case filter
}

enum HistoryToolbarMetrics {
    static let controlHeight: CGFloat = 38
    static let controlRadius: CGFloat = 9
    static let dropdownGap: CGFloat = 6
    static var optionPopoverRadius: CGFloat { controlRadius }
    static var optionRowRadius: CGFloat { controlRadius }
    static let sortControlWidth: CGFloat = 158
    static let filterControlWidth: CGFloat = 138
}
