import SwiftUI

struct HistorySortPicker: View {
    @Binding var selection: HistorySortOption
    @Binding var isPresented: Bool
    @State private var isHovering = false

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.10)) {
                isPresented.toggle()
            }
        } label: {
            HistoryToolbarControlLabel(
                title: selection.title,
                leadingSystemImageName: selection.systemImageName,
                trailingSystemImageName: "chevron.down",
                width: HistoryToolbarMetrics.sortControlWidth,
                isActive: isPresented,
                isHovering: isHovering,
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("clipdock.history.sortPicker")
        .overlay(alignment: .topLeading) {
            if isPresented {
                HistoryOptionMenu(width: HistoryToolbarMetrics.sortControlWidth) {
                    ForEach(HistorySortOption.allCases) { option in
                        HistoryOptionRow(
                            title: option.title,
                            systemImageName: option.systemImageName,
                            isSelected: selection == option,
                        ) {
                            selection = option
                            withAnimation(.easeOut(duration: 0.08)) {
                                isPresented = false
                            }
                        }
                    }
                }
                .offset(y: HistoryToolbarMetrics.controlHeight + HistoryToolbarMetrics.dropdownGap)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .zIndex(isPresented ? 10 : 0)
        .animation(.easeOut(duration: 0.10), value: isPresented)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}

struct HistoryFilterPicker: View {
    let selectedFilter: HistoryFilter
    @Binding var isPresented: Bool
    let selectFilter: (HistoryFilter) -> Void
    @State private var isHovering = false

    private let filters: [HistoryFilter] = [.all, .text, .url, .image, .file, .favorite]

    var body: some View {
        ZStack(alignment: .trailing) {
            Button {
                withAnimation(.easeOut(duration: 0.10)) {
                    isPresented.toggle()
                }
            } label: {
                HistoryToolbarControlLabel(
                    title: selectedFilter == .all ? "筛选" : selectedFilter.title,
                    leadingSystemImageName: "line.3.horizontal.decrease.circle",
                    trailingSystemImageName: showsClearButton ? nil : "chevron.down",
                    width: HistoryToolbarMetrics.filterControlWidth,
                    isActive: isPresented || selectedFilter != .all,
                    isHovering: isHovering,
                )
            }
            .buttonStyle(.plain)

            if showsClearButton {
                Button {
                    selectFilter(.all)
                    withAnimation(.easeOut(duration: 0.08)) {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Design.muted)
                        .frame(width: 28, height: HistoryToolbarMetrics.controlHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("清除筛选")
                .accessibilityLabel("清除筛选")
                .accessibilityIdentifier("clipdock.history.clearFilter")
                .transition(.opacity)
            }
        }
        .overlay(alignment: .topLeading) {
            if isPresented {
                HistoryOptionMenu(width: HistoryToolbarMetrics.filterControlWidth) {
                    ForEach(filters) { filter in
                        HistoryOptionRow(
                            title: filter.title,
                            systemImageName: filter.systemImageName,
                            isSelected: selectedFilter == filter,
                        ) {
                            selectFilter(filter)
                            withAnimation(.easeOut(duration: 0.08)) {
                                isPresented = false
                            }
                        }
                    }
                }
                .offset(y: HistoryToolbarMetrics.controlHeight + HistoryToolbarMetrics.dropdownGap)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .zIndex(isPresented ? 10 : 0)
        .animation(.easeOut(duration: 0.10), value: isPresented)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }

    private var showsClearButton: Bool {
        selectedFilter != .all && isHovering
    }
}
