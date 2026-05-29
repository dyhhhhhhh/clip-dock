import ClipDockCore
import SwiftUI

struct HistoryWindowView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openSettings) private var openSettings
    @State private var sortOption: HistorySortOption = .newest
    @State private var presentedToolbarDropdown: HistoryToolbarDropdown?

    private var filteredItems: [ClipItem] {
        sortOption.sorted(appState.historyVisibleClips)
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(
                selectedFilter: appState.historyFilter,
                items: appState.clips,
                storageStats: appState.storageStats,
                selectFilter: selectHistoryFilter,
                openSettings: openSettingsWindow,
            )
            .frame(minWidth: HistoryWindowMetrics.sidebarWidth, idealWidth: HistoryWindowMetrics.sidebarWidth, maxWidth: HistoryWindowMetrics.sidebarWidth)
            .layoutPriority(2)

            Divider()
            contentArea
        }
        .clipDockPanel()
        .accessibilityIdentifier("clipdock.history.root")
    }

    private var contentArea: some View {
        let items = filteredItems
        let selectedItem = appState.selectedClip(in: items)

        return VStack(spacing: 0) {
            HistoryToolbar(
                searchText: $appState.searchText,
                sortOption: $sortOption,
                selectedFilter: appState.historyFilter,
                presentedDropdown: $presentedToolbarDropdown,
                selectFilter: selectHistoryFilter,
            )
            .zIndex(2)

            HStack(spacing: 0) {
                HistoryListPane(
                    items: items,
                    selectedID: selectedItem?.id,
                    select: selectClip,
                    restore: restoreClip,
                    toggleFavorite: toggleFavorite,
                    openExternally: openExternally,
                    revealInFinder: revealInFinder,
                )

                Divider()

                DetailPaneView(
                    item: selectedItem,
                    openExternally: openExternally,
                    revealInFinder: revealInFinder,
                    restore: restoreClip,
                    toggleFavorite: toggleFavorite,
                    delete: deleteClip,
                )
                    .frame(minWidth: HistoryWindowMetrics.detailMinWidth, idealWidth: HistoryWindowMetrics.detailIdealWidth, maxWidth: .infinity)
                    .layoutPriority(1)
            }
            .zIndex(1)
            .onTapGesture(perform: dismissToolbarDropdown)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func selectHistoryFilter(_ filter: HistoryFilter) {
        appState.selectHistoryFilter(filter)
    }

    private func openSettingsWindow() {
        openSettings()
        appState.bringWindowToFront(title: "ClipDock Settings")
    }

    private func selectClip(_ item: ClipItem) {
        appState.selectClip(item.id)
    }

    private func restoreClip(_ item: ClipItem) {
        appState.restore(item)
    }

    private func toggleFavorite(_ item: ClipItem) {
        appState.toggleFavorite(item)
    }

    private func openExternally(_ item: ClipItem) {
        appState.openExternally(item)
    }

    private func revealInFinder(_ item: ClipItem) {
        appState.revealInFinder(item)
    }

    private func deleteClip(_ item: ClipItem) {
        appState.delete(item)
    }

    private func dismissToolbarDropdown() {
        guard presentedToolbarDropdown != nil else { return }
        presentedToolbarDropdown = nil
    }
}
