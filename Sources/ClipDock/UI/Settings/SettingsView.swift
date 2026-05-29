import AppKit
import ClipDockCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedSection: SettingsSection = .general
    @State private var activeChoiceMenuID: String?

    var body: some View {
        VStack(spacing: 12) {
            SettingsSectionTabs(selection: $selectedSection)

            selectedSection.content
                .environmentObject(appState)
        }
        .environment(\.settingsChoiceMenuID, $activeChoiceMenuID)
        .padding(14)
        .clipDockPanel()
        .accessibilityIdentifier("clipdock.settings.root")
        .overlayPreferenceValue(SettingsChoiceMenuBoundsPreferenceKey.self) { boundsByID in
            GeometryReader { proxy in
                SettingsChoiceMenuOutsideClickMonitor(
                    activeID: activeChoiceMenuID,
                    framesByID: resolvedChoiceMenuFrames(boundsByID, in: proxy),
                ) {
                    activeChoiceMenuID = nil
                }
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            appState.refreshGlobalHotKeyStatus()
        }
        .onChange(of: appState.settings) {
            appState.saveSettings()
        }
        .onChange(of: selectedSection) {
            activeChoiceMenuID = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            appState.refreshGlobalHotKeyStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            activeChoiceMenuID = nil
        }
    }

    private func resolvedChoiceMenuFrames(
        _ boundsByID: [String: [Anchor<CGRect>]],
        in proxy: GeometryProxy,
    ) -> [String: [CGRect]] {
        boundsByID.mapValues { anchors in
            anchors.map { proxy[$0].insetBy(dx: -2, dy: -2) }
        }
    }
}

struct SettingsSectionTabs: View {
    @Binding var selection: SettingsSection
    @Environment(\.settingsChoiceMenuID) private var activeChoiceMenuID

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SettingsSection.allCases) { section in
                Button {
                    activeChoiceMenuID.wrappedValue = nil
                    selection = section
                } label: {
                    Label(section.title, systemImage: section.systemImageName)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == section ? Color.white : Design.muted)
                .background(selection == section ? Design.primary : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: SettingsMetrics.controlRadius))
                .accessibilityIdentifier("clipdock.settings.tab.\(section.rawValue)")
            }
        }
        .padding(4)
        .frame(maxWidth: SettingsMetrics.cardWidth)
        .background(Design.surface1)
        .clipShape(RoundedRectangle(cornerRadius: SettingsMetrics.controlRadius + 2))
        .overlay(
            RoundedRectangle(cornerRadius: SettingsMetrics.controlRadius + 2)
                .stroke(Design.hairline, lineWidth: 1),
        )
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SettingsStack {
            SettingsCard(title: "启动与快捷键") {
                SettingsRow("登录时启动") {
                    SettingsToggle(isOn: $appState.settings.launchAtLogin, identifier: "clipdock.settings.general.launchAtLogin")
                }
                ShortcutSettingsBlock()
            }
            SettingsCard(title: "默认行为") {
                SettingsRow("默认粘贴行为", zIndex: 10, dismissesChoiceMenu: false) {
                    SettingsChoiceMenu(
                        selection: $appState.settings.defaultPasteBehavior,
                        choices: PasteBehavior.settingsChoices,
                        identifier: "clipdock.settings.general.defaultPasteBehavior",
                    )
                }
                SettingsRow("自动粘贴") {
                    SettingsToggle(isOn: $appState.settings.autoPasteEnabled, identifier: "clipdock.settings.general.autoPasteEnabled")
                }
                SettingsActionRow {
                    Button {
                        appState.requestGlobalHotKeyPermission()
                    } label: {
                        Label("请求辅助功能权限", systemImage: "hand.raised")
                    }
                    .accessibilityIdentifier("clipdock.settings.general.requestPermission")
                    Button {
                        appState.openAccessibilitySettings()
                    } label: {
                        Label("打开系统权限设置", systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("clipdock.settings.general.systemSettings")
                }
                SettingsNote("辅助功能权限仅用于自动粘贴；未授权时仍可恢复到系统剪贴板。")
                SettingsRow("启动后恢复最近剪贴板") {
                    SettingsToggle(isOn: $appState.settings.restoreLastClipboardOnStartup, identifier: "clipdock.settings.general.restoreLastClipboardOnStartup")
                }
            }
        }
        .accessibilityIdentifier("clipdock.settings.section.general")
    }
}

struct HistorySettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SettingsStack {
            SettingsCard(title: "历史记录") {
                SettingsRow("最大历史条数") {
                    SettingsNumberStepper(
                        value: $appState.settings.maxHistoryCount,
                        range: 100 ... 20000,
                        step: 100,
                        suffix: "",
                        identifier: "clipdock.settings.history.maxHistoryCount",
                    )
                }
                SettingsRow("保留时间") {
                    SettingsNumberStepper(
                        value: $appState.settings.retentionDays,
                        range: 1 ... 365,
                        step: 1,
                        suffix: "天",
                        identifier: "clipdock.settings.history.retentionDays",
                    )
                }
                SettingsRow("保存图片") {
                    SettingsToggle(isOn: $appState.settings.saveImages, identifier: "clipdock.settings.history.saveImages")
                }
                SettingsRow("保存文件 URL") {
                    SettingsToggle(isOn: $appState.settings.saveFileURLs, identifier: "clipdock.settings.history.saveFileURLs")
                }
                SettingsRow("去重策略", zIndex: 10, dismissesChoiceMenu: false) {
                    SettingsChoiceMenu(
                        selection: $appState.settings.deduplicationStrategy,
                        choices: DeduplicationStrategy.settingsChoices,
                        identifier: "clipdock.settings.history.deduplicationStrategy",
                    )
                }
            }
            SettingsCard(title: "清理策略") {
                SettingsNote("收藏项默认不会被自动清理。")
            }
        }
        .accessibilityIdentifier("clipdock.settings.section.history")
    }
}

struct PrivacySettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var newBundleID = ""
    @State private var confirmingClear = false
    @State private var confirmingClearRecent = false

    var body: some View {
        SettingsStack {
            SettingsCard(title: "内容与过滤") {
                SettingsRow("暂停记录") {
                    SettingsToggle(isOn: $appState.settings.recordingPaused, identifier: "clipdock.settings.privacy.recordingPaused")
                }
                SettingsRow("忽略敏感内容") {
                    SettingsToggle(isOn: $appState.settings.ignoreSensitiveContent, identifier: "clipdock.settings.privacy.ignoreSensitiveContent")
                }
            }
            SettingsCard(title: "应用黑名单") {
                ForEach(Array(appState.settings.ignoredBundleIdentifiers).sorted(), id: \.self) { bundleID in
                    HStack(spacing: 12) {
                        Text(bundleID)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Design.muted)
                            .lineLimit(1)
                        Spacer()
                        Button("移除") {
                            appState.settings.ignoredBundleIdentifiers.remove(bundleID)
                        }
                        .buttonStyle(SettingsActionButtonStyle())
                        .accessibilityIdentifier("clipdock.settings.privacy.removeIgnoredApp")
                    }
                    .frame(minHeight: 30)
                }
                SettingsInputActionRow(
                    placeholder: "Bundle Identifier",
                    text: $newBundleID,
                    buttonTitle: "添加应用",
                    identifier: "clipdock.settings.privacy.ignoredBundleIdentifier",
                    buttonIdentifier: "clipdock.settings.privacy.addIgnoredApp",
                ) {
                    guard !newBundleID.isEmpty else { return }
                    appState.settings.ignoredBundleIdentifiers.insert(newBundleID)
                    newBundleID = ""
                }
            }
            SettingsCard(title: "危险区域") {
                SettingsRow("清空最近历史") {
                    Button("清空最近 1 小时", role: .destructive) { confirmingClearRecent = true }
                        .buttonStyle(SettingsDangerButtonStyle())
                        .accessibilityIdentifier("clipdock.settings.privacy.clearRecentHistory")
                }
                SettingsRow("清空全部历史") {
                    Button("清空全部历史", role: .destructive) { confirmingClear = true }
                        .buttonStyle(SettingsDangerButtonStyle())
                        .accessibilityIdentifier("clipdock.settings.privacy.clearAllHistory")
                }
            }
        }
        .accessibilityIdentifier("clipdock.settings.section.privacy")
        .confirmationDialog("清空最近 1 小时历史？", isPresented: $confirmingClearRecent) {
            Button("清空最近 1 小时", role: .destructive) {
                appState.clearRecentHistory(since: Date().addingTimeInterval(-3600))
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作会删除最近 1 小时内捕获的本地历史记录，无法撤销。")
        }
        .confirmationDialog("清空全部历史？", isPresented: $confirmingClear) {
            Button("清空历史", role: .destructive) { appState.clearHistory() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作会删除本地历史记录，无法撤销。")
        }
    }
}

struct AdvancedSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SettingsStack {
            SettingsCard(title: "存储与索引") {
                SettingsRow("存储位置") {
                    Text(appState.storagePath)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Design.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: SettingsMetrics.pathWidth, alignment: .trailing)
                        .accessibilityIdentifier("clipdock.settings.advanced.storagePath")
                }
                SettingsRow("搜索索引") {
                    Button("重建搜索索引") {
                        appState.refresh()
                    }
                    .buttonStyle(SettingsActionButtonStyle())
                    .accessibilityIdentifier("clipdock.settings.advanced.rebuildIndex")
                }
                SettingsRow("Pasteboard 类型") {
                    Button("刷新类型") {
                        appState.refreshPasteboardTypes()
                    }
                    .buttonStyle(SettingsActionButtonStyle())
                    .accessibilityIdentifier("clipdock.settings.advanced.refreshPasteboardTypes")
                }
            }
            SettingsCard(title: "轮询与功耗") {
                SettingsRow("低功耗轮询模式") {
                    SettingsToggle(isOn: $appState.settings.lowPowerPolling, identifier: "clipdock.settings.advanced.lowPowerPolling")
                }
                SettingsNote("开启后剪贴板轮询间隔至少为 2 秒。")
            }
            SettingsCard(title: "Pasteboard 类型") {
                ForEach(appState.debugPasteboardTypes, id: \.self) { type in
                    Text(type)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
                if appState.debugPasteboardTypes.isEmpty {
                    SettingsNote("点击刷新后显示当前 pasteboard 类型。")
                }
            }
        }
        .accessibilityIdentifier("clipdock.settings.section.advanced")
    }
}

private extension DeduplicationStrategy {
    var label: String {
        switch self {
        case .byTypeAndContentHash:
            "按类型和内容哈希去重"
        }
    }

    static var settingsChoices: [SettingsChoice<DeduplicationStrategy>] {
        allCases.map { SettingsChoice(value: $0, title: $0.label, systemImageName: "number") }
    }
}

private extension PasteBehavior {
    var label: String {
        switch self {
        case .restoreOnly:
            "仅恢复剪贴板"
        case .autoPasteWhenAllowed:
            "允许时自动粘贴"
        }
    }

    var systemImageName: String {
        switch self {
        case .restoreOnly:
            "doc.on.clipboard"
        case .autoPasteWhenAllowed:
            "keyboard"
        }
    }

    static var settingsChoices: [SettingsChoice<PasteBehavior>] {
        [
            SettingsChoice(value: .restoreOnly, title: PasteBehavior.restoreOnly.label, systemImageName: PasteBehavior.restoreOnly.systemImageName),
            SettingsChoice(value: .autoPasteWhenAllowed, title: PasteBehavior.autoPasteWhenAllowed.label, systemImageName: PasteBehavior.autoPasteWhenAllowed.systemImageName),
        ]
    }
}

private enum SettingsMetrics {
    static let cardWidth: CGFloat = 620
    static let labelWidth: CGFloat = 170
    static let controlWidth: CGFloat = 236
    static let stepperWidth: CGFloat = 142
    static let pathWidth: CGFloat = 330
    static let controlHeight: CGFloat = 30
    static let controlRadius: CGFloat = 8
    static let rowSpacing: CGFloat = 16
    static let dropdownGap: CGFloat = 6
}

struct SettingsStack<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.settingsChoiceMenuID) private var activeChoiceMenuID

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(.vertical, 4)
            .frame(maxWidth: SettingsMetrics.cardWidth, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .top)
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        activeChoiceMenuID.wrappedValue = nil
                    },
            )
        }
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    let zIndex: Double
    let dismissesChoiceMenu: Bool
    @ViewBuilder var content: Content
    @Environment(\.settingsChoiceMenuID) private var activeChoiceMenuID

    init(_ title: String, zIndex: Double = 0, dismissesChoiceMenu: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.zIndex = zIndex
        self.dismissesChoiceMenu = dismissesChoiceMenu
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: SettingsMetrics.rowSpacing) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Design.ink)
                .frame(width: SettingsMetrics.labelWidth, alignment: .leading)
            content
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(minHeight: 34)
        .zIndex(zIndex)
        .simultaneousGesture(TapGesture().onEnded {
            if dismissesChoiceMenu {
                activeChoiceMenuID.wrappedValue = nil
            }
        })
    }
}

struct ShortcutSettingsBlock: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 10) {
            SettingsRow("全局快捷键") {
                SettingsShortcutField(text: $appState.settings.globalShortcut, identifier: "clipdock.settings.general.globalShortcut")
            }
            if !appState.globalShortcutIsValid {
                shortcutWarning
            }
            Divider()
                .overlay(Design.hairline.opacity(0.8))
                .padding(.leading, SettingsMetrics.labelWidth + SettingsMetrics.rowSpacing)
                .padding(.vertical, 2)
            statusRow
        }
    }

    private var shortcutWarning: some View {
        Label("快捷键格式无效，请使用类似 ⌘⇧V 或 cmd+option+space 的格式。", systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, SettingsMetrics.labelWidth + SettingsMetrics.rowSpacing)
    }

    private var statusRow: some View {
        HStack(alignment: .center, spacing: SettingsMetrics.rowSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text("快捷键状态")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Design.ink)
                Text("系统热键注册，与辅助功能权限无关。")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Design.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: SettingsMetrics.labelWidth, alignment: .leading)

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                SettingsStatusBadge(status: appState.globalHotKeyStatus)
                Button {
                    appState.refreshGlobalHotKeyStatus()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(SettingsActionButtonStyle())
                .accessibilityIdentifier("clipdock.settings.general.refreshPermission")
            }
        }
        .frame(minHeight: 42)
    }
}

struct SettingsStatusBadge: View {
    let status: GlobalHotKeyStatus

    var body: some View {
        Label(status.label, systemImage: status.systemImageName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(status == .active ? Design.ink : Design.muted)
            .padding(.horizontal, 10)
            .frame(height: SettingsMetrics.controlHeight)
            .background(Design.surface2)
            .clipShape(RoundedRectangle(cornerRadius: SettingsMetrics.controlRadius))
            .overlay(
                RoundedRectangle(cornerRadius: SettingsMetrics.controlRadius)
                    .stroke(status == .active ? Design.primary.opacity(0.45) : Design.hairlineStrong.opacity(0.65), lineWidth: 1),
            )
    }
}

struct SettingsNote: View {
    let text: String
    @Environment(\.settingsChoiceMenuID) private var activeChoiceMenuID

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Design.muted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, SettingsMetrics.labelWidth + SettingsMetrics.rowSpacing)
            .contentShape(Rectangle())
            .onTapGesture {
                activeChoiceMenuID.wrappedValue = nil
            }
    }
}

struct SettingsActionRow<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.settingsChoiceMenuID) private var activeChoiceMenuID

    var body: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            content
        }
        .padding(.leading, SettingsMetrics.labelWidth + SettingsMetrics.rowSpacing)
        .frame(minHeight: SettingsMetrics.controlHeight)
        .buttonStyle(SettingsActionButtonStyle())
        .simultaneousGesture(TapGesture().onEnded {
            activeChoiceMenuID.wrappedValue = nil
        })
    }
}

struct SettingsShortcutField: View {
    @EnvironmentObject private var appState: AppState
    @Binding var text: String
    let identifier: String
    @State private var isFocused = false
    @State private var isHovering = false
    @State private var draftText: String?

    var body: some View {
        HStack(spacing: 8) {
            ShortcutRecorderTextField(
                displayText: Binding(
                    get: { draftText ?? text },
                    set: { draftText = $0 },
                ),
                isFocused: $isFocused,
                onRecord: commit,
                onClear: clearDraft,
            )
            Button {
                clearDraft()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isHovering ? Design.ink : Design.muted)
            }
            .buttonStyle(.plain)
            .opacity((draftText ?? text).isEmpty ? 0 : 1)
        }
        .padding(.horizontal, 10)
        .frame(width: SettingsMetrics.controlWidth, height: SettingsMetrics.controlHeight)
        .background(Design.surface2)
        .clipShape(RoundedRectangle(cornerRadius: SettingsMetrics.controlRadius))
        .overlay(
            RoundedRectangle(cornerRadius: SettingsMetrics.controlRadius)
                .stroke(isFocused ? Design.primary.opacity(0.72) : Design.hairline, lineWidth: isFocused ? 1.5 : 1),
        )
        .accessibilityIdentifier(identifier)
        .onHover { hovering in
            isHovering = hovering
        }
        .onChange(of: isFocused) { _, focused in
            if focused {
                draftText = text
                appState.setGlobalHotKeySuppressed(true)
            } else {
                finishEditing()
            }
        }
        .onDisappear {
            if isFocused {
                finishEditing()
            }
        }
    }

    private func commit(_ shortcut: KeyboardShortcutSpec) {
        var draft = KeyboardShortcutDraft(committedValue: text)
        let committedValue = draft.record(shortcut)
        draftText = draft.draftValue
        text = committedValue
    }

    private func clearDraft() {
        draftText = ""
    }

    private func finishEditing() {
        var draft = KeyboardShortcutDraft(committedValue: text)
        draft.updateDraftValue(draftText ?? text)
        if let committedValue = draft.finishEditing() {
            text = committedValue
        }
        draftText = nil
        appState.setGlobalHotKeySuppressed(false)
    }
}

private struct ShortcutRecorderTextField: NSViewRepresentable {
    @Binding var displayText: String
    @Binding var isFocused: Bool
    let onRecord: (KeyboardShortcutSpec) -> Void
    let onClear: () -> Void

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.onShortcut = { shortcut in
            onRecord(shortcut)
        }
        view.onClear = {
            onClear()
        }
        view.onFocusChange = { focused in
            isFocused = focused
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.displayText = displayText
    }
}

private final class ShortcutRecorderNSView: NSView {
    var onShortcut: ((KeyboardShortcutSpec) -> Void)?
    var onClear: (() -> Void)?
    var onFocusChange: ((Bool) -> Void)?

    private let label = NSTextField(labelWithString: "")

    var displayText = "" {
        didSet {
            label.stringValue = displayText
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        label.alignment = .center
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = NSColor.labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        onFocusChange?(true)
        return true
    }

    override func resignFirstResponder() -> Bool {
        onFocusChange?(false)
        return true
    }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case 51, 117:
            onClear?()
        case 53:
            window?.makeFirstResponder(nil)
        default:
            guard let shortcut = KeyboardShortcutSpec(event: event) else {
                NSSound.beep()
                return
            }
            onShortcut?(shortcut)
        }
    }
}

private extension KeyboardShortcutSpec {
    init?(event: NSEvent) {
        let modifiers = event.shortcutModifiers
        guard !modifiers.isEmpty, let key = event.shortcutKey else {
            return nil
        }
        self.init(key: key, modifiers: modifiers)
    }
}

private extension NSEvent {
    var shortcutModifiers: Set<KeyboardModifier> {
        let flags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        var result = Set<KeyboardModifier>()
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.control) { result.insert(.control) }
        return result
    }

    var shortcutKey: String? {
        guard let characters = charactersIgnoringModifiers?.lowercased() else { return nil }
        switch characters {
        case " ":
            return "space"
        case "\r", "\n":
            return "return"
        case "\u{1b}":
            return "escape"
        default:
            return characters.count == 1 ? characters : nil
        }
    }
}

struct SettingsToggle: View {
    @Binding var isOn: Bool
    let identifier: String

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.14)) {
                isOn.toggle()
            }
        } label: {
            RoundedRectangle(cornerRadius: 999)
                .fill(isOn ? Design.primary : Design.surface3)
                .frame(width: 42, height: 24)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(isOn ? Color.white.opacity(0.92) : Color.white.opacity(0.82))
                        .frame(width: 18, height: 18)
                        .padding(.horizontal, 3)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 999)
                        .stroke(isOn ? Design.primary.opacity(0.55) : Design.hairlineStrong.opacity(0.7), lineWidth: 1),
                )
        }
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier)
            .accessibilityLabel("开关")
            .accessibilityValue(isOn ? "已开启" : "已关闭")
    }
}

struct SettingsChoice<Value: Equatable>: Identifiable {
    let id: String
    let value: Value
    let title: String
    let systemImageName: String?

    init(value: Value, title: String, systemImageName: String? = nil) {
        self.id = title
        self.value = value
        self.title = title
        self.systemImageName = systemImageName
    }
}

struct SettingsChoiceMenu<Value: Equatable>: View {
    @Binding var selection: Value
    let choices: [SettingsChoice<Value>]
    let identifier: String
    @State private var isHovering = false
    @Environment(\.settingsChoiceMenuID) private var activeChoiceMenuID

    private var selectedChoice: SettingsChoice<Value>? {
        choices.first { $0.value == selection }
    }

    private var isPresented: Bool {
        activeChoiceMenuID.wrappedValue == identifier
    }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.10)) {
                activeChoiceMenuID.wrappedValue = isPresented ? nil : identifier
            }
        } label: {
            HStack(spacing: 8) {
                if let systemImageName = selectedChoice?.systemImageName {
                    Image(systemName: systemImageName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isPresented ? Design.primary : Design.muted)
                        .frame(width: 15)
                }
                Text(selectedChoice?.title ?? "选择")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isPresented ? Design.ink : Design.muted)
            }
            .foregroundStyle(Design.ink)
            .padding(.horizontal, 10)
            .frame(width: SettingsMetrics.controlWidth, height: SettingsMetrics.controlHeight)
            .background(SettingsControlBackground(isActive: isPresented, isHovering: isHovering))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .settingsChoiceMenuBounds(id: identifier)
        .overlay(alignment: .topLeading) {
            if isPresented {
                VStack(spacing: 4) {
                    ForEach(choices) { choice in
                        SettingsChoiceRow(
                            title: choice.title,
                            systemImageName: choice.systemImageName,
                            isSelected: choice.value == selection,
                        ) {
                            selection = choice.value
                            withAnimation(.easeOut(duration: 0.08)) {
                                activeChoiceMenuID.wrappedValue = nil
                            }
                        }
                    }
                }
                .padding(5)
                .frame(width: SettingsMetrics.controlWidth)
                .background(Design.surface1)
                .clipShape(RoundedRectangle(cornerRadius: SettingsMetrics.controlRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: SettingsMetrics.controlRadius)
                        .stroke(Design.hairlineStrong.opacity(0.75), lineWidth: 1),
                )
                .shadow(color: .black.opacity(0.32), radius: 14, x: 0, y: 8)
                .offset(y: SettingsMetrics.controlHeight + SettingsMetrics.dropdownGap)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .settingsChoiceMenuBounds(id: identifier)
            }
        }
        .zIndex(isPresented ? 20 : 0)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}

struct SettingsChoiceRow: View {
    let title: String
    let systemImageName: String?
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImageName {
                    Image(systemName: systemImageName)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 15)
                }
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .opacity(isSelected ? 1 : 0)
            }
            .foregroundStyle(isSelected ? Color.white : Design.ink)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Design.primary : (isHovering ? Design.surface2 : Color.clear))
            .clipShape(RoundedRectangle(cornerRadius: SettingsMetrics.controlRadius))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}

struct SettingsNumberStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let suffix: String
    let identifier: String

    var body: some View {
        HStack(spacing: 6) {
            stepButton(systemImageName: "minus") {
                value = max(range.lowerBound, value - step)
            }
            Text(displayValue)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Design.ink)
                .frame(maxWidth: .infinity)
            stepButton(systemImageName: "plus") {
                value = min(range.upperBound, value + step)
            }
        }
        .padding(.horizontal, 4)
        .frame(width: SettingsMetrics.stepperWidth, height: SettingsMetrics.controlHeight)
        .background(SettingsControlBackground(isActive: false, isHovering: false))
        .accessibilityIdentifier(identifier)
    }

    private var displayValue: String {
        suffix.isEmpty ? "\(value)" : "\(value) \(suffix)"
    }

    private func stepButton(systemImageName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImageName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Design.muted)
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SettingsControlBackground: View {
    let isActive: Bool
    let isHovering: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: SettingsMetrics.controlRadius)
            .fill(isActive || isHovering ? Design.surface3 : Design.surface2)
            .overlay(
                RoundedRectangle(cornerRadius: SettingsMetrics.controlRadius)
                    .stroke(isActive ? Design.primary.opacity(0.72) : Design.hairlineStrong.opacity(isHovering ? 0.85 : 0.55), lineWidth: isActive ? 1.5 : 1),
            )
    }
}

struct SettingsActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(configuration.isPressed ? Design.ink.opacity(0.72) : Design.ink)
            .padding(.horizontal, 10)
            .frame(height: SettingsMetrics.controlHeight)
            .background(configuration.isPressed ? Design.surface3 : Design.surface2)
            .clipShape(RoundedRectangle(cornerRadius: SettingsMetrics.controlRadius))
            .overlay(
                RoundedRectangle(cornerRadius: SettingsMetrics.controlRadius)
                    .stroke(Design.hairlineStrong.opacity(0.65), lineWidth: 1),
            )
    }
}

struct SettingsDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(configuration.isPressed ? Design.danger.opacity(0.75) : Design.danger)
            .padding(.horizontal, 10)
            .frame(height: SettingsMetrics.controlHeight)
            .background(Design.danger.opacity(configuration.isPressed ? 0.16 : 0.10))
            .clipShape(RoundedRectangle(cornerRadius: SettingsMetrics.controlRadius))
            .overlay(
                RoundedRectangle(cornerRadius: SettingsMetrics.controlRadius)
                    .stroke(Design.danger.opacity(0.36), lineWidth: 1),
            )
    }
}

struct SettingsInputActionRow: View {
    let placeholder: String
    @Binding var text: String
    let buttonTitle: String
    let identifier: String
    let buttonIdentifier: String
    let action: () -> Void
    @Environment(\.settingsChoiceMenuID) private var activeChoiceMenuID

    var body: some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .frame(height: SettingsMetrics.controlHeight)
                .background(Design.surface2)
                .clipShape(RoundedRectangle(cornerRadius: SettingsMetrics.controlRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: SettingsMetrics.controlRadius)
                        .stroke(Design.hairline, lineWidth: 1),
                )
                .accessibilityIdentifier(identifier)
            Button(buttonTitle, action: action)
                .buttonStyle(SettingsActionButtonStyle())
                .accessibilityIdentifier(buttonIdentifier)
        }
        .padding(.leading, SettingsMetrics.labelWidth + SettingsMetrics.rowSpacing)
        .simultaneousGesture(TapGesture().onEnded {
            activeChoiceMenuID.wrappedValue = nil
        })
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    @Environment(\.settingsChoiceMenuID) private var activeChoiceMenuID

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .contentShape(Rectangle())
                .onTapGesture {
                    activeChoiceMenuID.wrappedValue = nil
                }
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: SettingsMetrics.controlRadius + 2)
                .fill(Design.surface1),
        )
        .overlay(
            RoundedRectangle(cornerRadius: SettingsMetrics.controlRadius + 2)
                .stroke(Design.hairline, lineWidth: 1),
        )
    }
}

private struct SettingsChoiceMenuIDKey: EnvironmentKey {
    static let defaultValue: Binding<String?> = .constant(nil)
}

private struct SettingsChoiceMenuBoundsPreferenceKey: PreferenceKey {
    static var defaultValue: [String: [Anchor<CGRect>]] = [:]

    static func reduce(value: inout [String: [Anchor<CGRect>]], nextValue: () -> [String: [Anchor<CGRect>]]) {
        for (id, anchors) in nextValue() {
            value[id, default: []].append(contentsOf: anchors)
        }
    }
}

private extension EnvironmentValues {
    var settingsChoiceMenuID: Binding<String?> {
        get { self[SettingsChoiceMenuIDKey.self] }
        set { self[SettingsChoiceMenuIDKey.self] = newValue }
    }
}

private extension View {
    func settingsChoiceMenuBounds(id: String) -> some View {
        anchorPreference(key: SettingsChoiceMenuBoundsPreferenceKey.self, value: .bounds) { anchor in
            [id: [anchor]]
        }
    }
}

private struct SettingsChoiceMenuOutsideClickMonitor: NSViewRepresentable {
    let activeID: String?
    let framesByID: [String: [CGRect]]
    let close: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> MonitoringView {
        let view = MonitoringView()
        context.coordinator.view = view
        context.coordinator.install()
        return view
    }

    func updateNSView(_ nsView: MonitoringView, context: Context) {
        context.coordinator.view = nsView
        context.coordinator.activeID = activeID
        context.coordinator.framesByID = framesByID
        context.coordinator.close = close
    }

    static func dismantleNSView(_ nsView: MonitoringView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class MonitoringView: NSView {
        override var isFlipped: Bool { true }
    }

    final class Coordinator {
        weak var view: MonitoringView?
        var activeID: String?
        var framesByID: [String: [CGRect]] = [:]
        var close: (() -> Void)?
        private var localMonitor: Any?
        private var globalMonitor: Any?

        func install() {
            guard localMonitor == nil else { return }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                self?.handleLocalMouseDown(event)
                return event
            }
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.closeIfActive()
                }
            }
        }

        func uninstall() {
            if let localMonitor {
                NSEvent.removeMonitor(localMonitor)
                self.localMonitor = nil
            }
            if let globalMonitor {
                NSEvent.removeMonitor(globalMonitor)
                self.globalMonitor = nil
            }
        }

        private func handleLocalMouseDown(_ event: NSEvent) {
            guard let activeID else { return }
            guard let view, event.window === view.window else {
                closeIfActive()
                return
            }

            let activeFrames = framesByID[activeID] ?? []
            guard !activeFrames.isEmpty else {
                closeIfActive()
                return
            }

            let point = view.convert(event.locationInWindow, from: nil)
            let isInsideActiveMenu = activeFrames.contains { $0.contains(point) }
            if !isInsideActiveMenu {
                closeIfActive()
            }
        }

        private func closeIfActive() {
            guard activeID != nil else { return }
            close?()
        }
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case history
    case privacy
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "通用"
        case .history: "历史"
        case .privacy: "隐私"
        case .advanced: "高级"
        }
    }

    var systemImageName: String {
        switch self {
        case .general: "gearshape"
        case .history: "clock"
        case .privacy: "lock"
        case .advanced: "gearshape.2"
        }
    }

    @ViewBuilder var content: some View {
        switch self {
        case .general: GeneralSettingsView()
        case .history: HistorySettingsView()
        case .privacy: PrivacySettingsView()
        case .advanced: AdvancedSettingsView()
        }
    }
}
