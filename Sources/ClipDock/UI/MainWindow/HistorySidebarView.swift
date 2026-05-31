import ClipDockCore
import SwiftUI

struct SidebarView: View {
    let selectedFilter: HistoryFilter
    let items: [ClipItem]
    let storageStats: ClipStorageStats
    let selectFilter: (HistoryFilter) -> Void
    let openSettings: () -> Void

    private var storageProgress: Double {
        guard storageStats.maxHistoryCount > 0 else { return 0 }
        return min(Double(storageStats.itemCount) / Double(storageStats.maxHistoryCount), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ClipDockBrandIcon(size: 18)
                Text("ClipDock")
                    .font(.headline)
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)

            VStack(spacing: 4) {
                ForEach(HistoryFilter.primaryCases) { filter in
                    SidebarFilterRow(
                        filter: filter,
                        count: filter.count(in: items),
                        isSelected: selectedFilter == filter,
                    ) {
                        selectFilter(filter)
                    }
                }
            }

            Divider()
                .padding(.vertical, 4)
            SidebarFilterRow(filter: .ignored, count: 0, isSelected: selectedFilter == .ignored) { selectFilter(.ignored) }
            SidebarFilterRow(filter: .trash, count: 0, isSelected: selectedFilter == .trash) { selectFilter(.trash) }
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("存储使用情况")
                    .font(.caption)
                    .foregroundStyle(Design.muted)
                ProgressView(value: storageProgress)
                HStack {
                    Text("历史数量")
                    Spacer()
                    Text("\(storageStats.itemCount) / \(storageStats.maxHistoryCount)")
                }
                .font(.caption2)
                .foregroundStyle(Design.muted)
                HStack {
                    Text("本地空间")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: storageStats.totalByteSize, countStyle: .file))
                }
                .font(.caption2)
                .foregroundStyle(Design.muted)
                .accessibilityIdentifier("clipdock.history.storageUsage")
            }
            .padding(12)
            .background(Design.surface1)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(12)

            SidebarActionRow(
                title: "设置",
                systemImageName: "gearshape",
                identifier: "clipdock.history.openSettings",
                action: openSettings,
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .background(Design.surface1)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("clipdock.history.sidebar")
    }
}

struct SidebarActionRow: View {
    let title: String
    let systemImageName: String
    let identifier: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImageName)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovering ? Design.surface2 : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Design.ink)
        .accessibilityIdentifier(identifier)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}

struct SidebarFilterRow: View {
    let filter: HistoryFilter
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: filter.systemImageName)
                    .frame(width: 16)
                Text(filter.title)
                Spacer()
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(Design.muted)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Design.primary : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : Design.ink)
        .padding(.horizontal, 8)
        .accessibilityIdentifier("clipdock.history.filter.\(filter.rawValue)")
    }
}
