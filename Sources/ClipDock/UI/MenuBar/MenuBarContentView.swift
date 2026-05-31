import AppKit
import ClipDockCore
import SwiftUI

struct MenuBarContentActions {
    var dismiss: (() -> Void)?
    var openHistory: (() -> Void)?
    var openLauncher: (() -> Void)?
    var openSettings: (() -> Void)?

    static let environment = MenuBarContentActions()
}

struct MenuBarContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    private let actions: MenuBarContentActions

    init(actions: MenuBarContentActions = .environment) {
        self.actions = actions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Divider()
            recentList
            Divider()
            VStack(spacing: 0) {
                menuToggle(
                    "暂停记录",
                    systemImage: "pause.circle",
                    activeSystemImage: "pause.circle.fill",
                    isOn: $appState.settings.recordingPaused,
                    identifier: "clipdock.menu.pauseToggle",
                ) {
                    appState.saveSettings()
                }
                Divider()
                menuAction("清空历史...", systemImage: "trash", role: .destructive, identifier: "clipdock.menu.clearHistory") {
                    confirmAndClearHistory()
                }
            }
            Divider()
            menuAction("打开主窗口", systemImage: "house", identifier: "clipdock.menu.openHistory") {
                dismissMenuThen {
                    if let openHistory = actions.openHistory {
                        openHistory()
                    } else {
                        openWindow(id: "history")
                        appState.bringWindowToFront(title: "ClipDock")
                    }
                }
            }
            menuAction(
                "打开 Launcher",
                systemImage: "rectangle.inset.filled.and.person.filled",
                shortcut: launcherShortcutLabel,
                identifier: "clipdock.menu.openLauncher",
            ) {
                dismissMenuThen {
                    if let openLauncher = actions.openLauncher {
                        openLauncher()
                    } else {
                        appState.openLauncher()
                    }
                }
            }
            menuAction("设置...", systemImage: "gearshape", identifier: "clipdock.menu.openSettings") {
                dismissMenuThen {
                    if let openSettings = actions.openSettings {
                        openSettings()
                    } else {
                        openSettings()
                        appState.bringWindowToFront(title: "ClipDock Settings")
                    }
                }
            }
            Divider()
            menuAction("退出 ClipDock", systemImage: "power", identifier: "clipdock.menu.quit") { NSApp.terminate(nil) }
        }
        .padding(12)
        .clipDockPanel()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("clipdock.menu.panel")
    }

    private var header: some View {
        HStack {
            ClipDockBrandIcon(size: 24)
            Text("ClipDock")
                .font(.headline)
            Spacer()
            Text(appState.settings.recordingPaused ? "已暂停" : "标准模式")
                .font(.caption)
                .foregroundStyle(Design.muted)
        }
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("最近复制")
                    .font(.caption)
                    .foregroundStyle(Design.muted)
                Spacer()
                Button("全部历史") {
                    dismissMenuThen {
                        openWindow(id: "history")
                        appState.bringWindowToFront(title: "ClipDock")
                    }
                }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .accessibilityIdentifier("clipdock.menu.allHistory")
            }
            ForEach(appState.clips.prefix(5)) { item in
                MenuBarRowView(
                    item: item,
                    restore: {
                        appState.restore(item)
                    },
                    toggleFavorite: {
                        appState.toggleFavorite(item)
                    },
                    openExternally: {
                        appState.openExternally(item)
                    },
                    revealInFinder: {
                        appState.revealInFinder(item)
                    },
                )
                    .equatable()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.restore(item)
                    }
                    .onTapGesture(count: 2) {
                        restoreAndPasteFromMenu(item)
                    }
            }
            if appState.clips.isEmpty {
                Text("还没有可显示的剪贴板历史")
                    .font(.caption)
                    .foregroundStyle(Design.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            }
        }
    }

    private var launcherShortcutLabel: String {
        KeyboardShortcutSpec.parse(appState.settings.globalShortcut)?.displayString ?? appState.settings.globalShortcut
    }

    private func menuAction(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        shortcut: String? = nil,
        identifier: String,
        action: @escaping () -> Void,
    ) -> some View {
        Button(role: role, action: action) {
            menuRowLabel(title, systemImage: systemImage, shortcut: shortcut)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func restoreAndPasteFromMenu(_ item: ClipItem) {
        dismissMenu()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            appState.restoreAndAutoPaste(item)
        }
    }

    private func dismissMenuThen(_ action: @escaping @MainActor () -> Void) {
        dismissMenu()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            action()
        }
    }

    private func confirmAndClearHistory() {
        dismissMenu()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            let alert = NSAlert()
            alert.messageText = "清空全部历史记录？"
            alert.informativeText = "此操作会删除本地保存的全部剪贴板历史记录，无法撤销。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "清空历史记录")
            alert.addButton(withTitle: "取消")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                appState.clearHistory()
            }
        }
    }

    private func dismissMenu() {
        if let dismissAction = actions.dismiss {
            dismissAction()
        } else {
            dismiss()
        }
    }

    private func menuToggle(
        _ title: String,
        systemImage: String,
        activeSystemImage: String,
        isOn: Binding<Bool>,
        identifier: String,
        onChange: @escaping () -> Void,
    ) -> some View {
        let savingBinding = Binding(
            get: { isOn.wrappedValue },
            set: { newValue in
                isOn.wrappedValue = newValue
                onChange()
            },
        )

        return Toggle(isOn: savingBinding) {
            menuRowLabel(
                title,
                systemImage: isOn.wrappedValue ? activeSystemImage : systemImage,
                iconColor: isOn.wrappedValue ? Design.primary : Design.ink,
            )
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .tint(Design.primary)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(title)
        .accessibilityValue(isOn.wrappedValue ? "已开启" : "已关闭")
    }

    private func menuRowLabel(_ title: String, systemImage: String, iconColor: Color = Design.ink, shortcut: String? = nil) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: MenuMetrics.iconWidth, alignment: .center)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Design.ink)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let shortcut, !shortcut.isEmpty {
                Text(shortcut)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Design.muted)
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .frame(height: 22)
                    .background(Design.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Design.hairlineStrong.opacity(0.55), lineWidth: 1),
                    )
            }
        }
        .frame(maxWidth: .infinity, minHeight: MenuMetrics.rowHeight, alignment: .center)
        .contentShape(Rectangle())
    }
}

private enum MenuMetrics {
    static let rowHeight: CGFloat = 32
    static let iconWidth: CGFloat = 18
}

struct MenuBarRowView: View, Equatable {
    let item: ClipItem
    let restore: () -> Void
    let toggleFavorite: () -> Void
    let openExternally: () -> Void
    let revealInFinder: () -> Void
    @State private var isHovering = false

    static func == (lhs: MenuBarRowView, rhs: MenuBarRowView) -> Bool {
        lhs.item == rhs.item
    }

    var body: some View {
        let sourcePresentation = SourceAppPresentation.resolve(item.sourceApp)

        HStack(spacing: 10) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack(spacing: 5) {
                    Image(nsImage: sourcePresentation.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    Text(sourcePresentation.name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Design.muted)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Spacer()
            if isHovering || ProcessInfo.processInfo.environment["CLIPDOCK_UI_TEST_MODE"] == "1" {
                HStack(spacing: 4) {
                    if let openSystemImageName = item.openSystemImageName {
                        rowIconButton(
                            systemImage: openSystemImageName,
                            title: item.openActionTitle,
                            identifier: "clipdock.menu.recent.row.\(item.id.uuidString).open",
                            action: openExternally,
                        )
                    }
                    if item.filePresentation != nil {
                        rowIconButton(
                            systemImage: "folder",
                            title: "在 Finder 中显示",
                            identifier: "clipdock.menu.recent.row.\(item.id.uuidString).finder",
                            action: revealInFinder,
                        )
                    }
                    rowIconButton(
                        systemImage: item.isFavorite ? "star.fill" : "star",
                        title: item.isFavorite ? "取消收藏" : "收藏",
                        isActive: item.isFavorite,
                        identifier: "clipdock.menu.recent.row.\(item.id.uuidString).favorite",
                        action: toggleFavorite,
                    )
                }
                .transition(.opacity)
            } else {
                HStack(spacing: 8) {
                    Text(DatePresentation.relative(item.capturedAt))
                        .font(.caption)
                        .foregroundStyle(Design.muted)
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Design.primary)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isHovering ? Design.surface2 : Color.clear),
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isHovering ? Design.hairline.opacity(0.95) : Color.clear, lineWidth: 1),
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .accessibilityAction(.default, restore)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("clipdock.menu.recent.row.\(item.id.uuidString)")
    }

    @ViewBuilder private var thumbnail: some View {
        if let filePresentation = item.filePresentation {
            Image(nsImage: filePresentation.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .background(Design.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Design.hairline, lineWidth: 1),
                )
        } else if item.primaryType == .image,
           let payloadRef = item.payloadRef,
           let image = ImageThumbnailCache.shared.thumbnail(for: payloadRef) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Design.hairline, lineWidth: 1),
                )
        } else {
            Image(systemName: item.primaryType.systemImageName)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(Design.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 5))
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
                .foregroundStyle(isActive ? Design.primary : Design.ink)
                .frame(width: 24, height: 24)
                .background(isActive ? Design.primary.opacity(0.18) : Design.surface1)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isActive ? Design.primary.opacity(0.45) : Design.hairline, lineWidth: 1),
                )
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
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
