import SwiftUI

struct HistoryToolbar: View {
    @Binding var searchText: String
    @Binding var sortOption: HistorySortOption
    let selectedFilter: HistoryFilter
    @Binding var presentedDropdown: HistoryToolbarDropdown?
    let selectFilter: (HistoryFilter) -> Void

    var body: some View {
        HStack(spacing: 12) {
            HistorySearchField(text: $searchText)
                .frame(minWidth: 320, idealWidth: 440, maxWidth: 520)
                .layoutPriority(1)
            Text("排序")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Design.ink)
            HistorySortPicker(selection: $sortOption, isPresented: dropdownBinding(for: .sort))
            HistoryFilterPicker(
                selectedFilter: selectedFilter,
                isPresented: dropdownBinding(for: .filter),
                selectFilter: selectFilter,
            )
            .help("筛选历史类型")
            .accessibilityIdentifier("clipdock.history.applyFilter")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Design.surface1)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("clipdock.history.toolbar")
    }

    private func dropdownBinding(for dropdown: HistoryToolbarDropdown) -> Binding<Bool> {
        Binding(
            get: { presentedDropdown == dropdown },
            set: { isPresented in
                presentedDropdown = isPresented ? dropdown : nil
            },
        )
    }
}

struct HistorySearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isFocused ? Design.primary : Design.muted)
                .frame(width: 16)
            TextField("搜索历史内容...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Design.ink)
                .focused($isFocused)
                .accessibilityIdentifier("clipdock.history.searchField")
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isHovering ? Design.ink : Design.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空搜索")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: HistoryToolbarMetrics.controlHeight)
        .background(HistoryToolbarControlBackground(isActive: isFocused, isHovering: isHovering))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}
