import ClipDockCore
import SwiftUI

struct LauncherView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var filter: ClipType?
    @State private var favoriteOnly = false

    private var filteredItems: [ClipItem] {
        appState.visibleClips.filter { item in
            if let filter, item.primaryType != filter { return false }
            if favoriteOnly, !item.isFavorite { return false }
            return true
        }
    }

    var body: some View {
        let items = filteredItems
        let displayedItems = Array(items.prefix(8))
        let selectedItem = appState.selectedClip(in: items)
        let previewedItem = appState.previewedClip(in: items)

        VStack(spacing: 10) {
            LauncherDragHandle()
                .frame(width: 46, height: 7)
                .background(Design.hairlineStrong)
                .clipShape(Capsule())
                .accessibilityIdentifier("clipdock.launcher.dragHandle")

            searchField
            filterChips
            LauncherResultsList(
                displayedItems: displayedItems,
                isEmpty: items.isEmpty,
                selectedID: selectedItem?.id,
                select: selectClip,
            )

            if let item = previewedItem {
                LauncherPreviewView(item: item)
                    .transition(.opacity)
            }

            LauncherFooter()
        }
        .padding(16)
        .background(Design.canvas)
        .accessibilityIdentifier("clipdock.launcher.root")
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Design.hairline, lineWidth: 1),
        )
        .shadow(color: .black.opacity(0.45), radius: 28, x: 0, y: 18)
        .onSubmit {
            restoreAndClose(selectedItem)
        }
        .focusable()
        .onAppear {
            appState.moveSelection(.down, in: items)
        }
        .onMoveCommand { direction in
            handleMove(direction, items: items)
        }
        .onKeyPress(.space) {
            appState.togglePreview(in: items)
            return .handled
        }
        .onKeyPress(.return) {
            restoreAndClose(selectedItem)
            return .handled
        }
        .onKeyPress(.escape) {
            handleEscape(previewedItem: previewedItem)
            return .handled
        }
        .onKeyPress { press in
            guard let command = press.launcherCommand else {
                return .ignored
            }
            handle(command, selectedItem: selectedItem)
            return .handled
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Design.muted)
            TextField("搜索复制内容...", text: $appState.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .medium))
                .accessibilityIdentifier("clipdock.launcher.searchField")
            Text(appState.settings.globalShortcut)
                .font(.caption)
                .foregroundStyle(Design.muted)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Design.surface1)
        .accessibilityIdentifier("clipdock.launcher.resultsList")
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Design.primary, lineWidth: 1.5),
        )
    }

    private var filterChips: some View {
        HStack(spacing: 10) {
            chip("全部", identifier: "clipdock.launcher.filter.all", active: filter == nil) {
                filter = nil
            }
            ForEach([ClipType.text, .url, .image, .file], id: \.self) { type in
                chip(type.label, identifier: "clipdock.launcher.filter.\(type.rawValue)", active: filter == type) {
                    filter = type
                }
            }
            chip("收藏", identifier: "clipdock.launcher.filter.favorite", active: favoriteOnly) {
                favoriteOnly.toggle()
            }
            Spacer()
        }
        .accessibilityIdentifier("clipdock.launcher.filters")
    }

    private func chip(_ title: String, identifier: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
            .tint(active ? Design.primary : Design.surface2)
            .accessibilityIdentifier(identifier)
    }

    private func selectClip(_ item: ClipItem) {
        appState.selectClip(item.id)
    }

    private func handleMove(_ direction: MoveCommandDirection, items: [ClipItem]) {
        switch direction {
        case .up:
            appState.moveSelection(.up, in: items)
        case .down:
            appState.moveSelection(.down, in: items)
        default:
            break
        }
    }

    private func handleEscape(previewedItem: ClipItem?) {
        if previewedItem == nil {
            close()
        } else {
            appState.dismissPreview()
        }
    }

    private func handle(_ command: LauncherKeyCommand, selectedItem: ClipItem?) {
        switch command {
        case .delete:
            appState.delete(selectedItem)
        case .toggleFavorite:
            appState.toggleFavorite(selectedItem)
        }
    }

    private func restoreAndClose(_ item: ClipItem?) {
        appState.restore(item)
        close()
    }

    private func close() {
        appState.closeLauncher()
        dismiss()
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

private extension KeyPress {
    var launcherCommand: LauncherKeyCommand? {
        guard phase == .down else { return nil }
        return LauncherKeyCommand.resolve(
            key: normalizedKey ?? "",
            modifiers: keyboardModifiers,
        )
    }

    var normalizedKey: String? {
        let value = String(key.character).lowercased()
        switch value {
        case " ":
            return "space"
        case "\r", "\n":
            return "return"
        case "\u{1b}":
            return "escape"
        default:
            return value
        }
    }

    var keyboardModifiers: Set<KeyboardModifier> {
        var result = Set<KeyboardModifier>()
        if modifiers.contains(.command) { result.insert(.command) }
        if modifiers.contains(.shift) { result.insert(.shift) }
        if modifiers.contains(.option) { result.insert(.option) }
        if modifiers.contains(.control) { result.insert(.control) }
        return result
    }
}
