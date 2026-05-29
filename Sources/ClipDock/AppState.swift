import AppKit
import ClipDockCore
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var settings: UserSettings
    @Published private(set) var clips: [ClipItem] = []
    @Published private(set) var visibleClips: [ClipItem] = []
    @Published private(set) var storageStats: ClipStorageStats
    @Published var searchText = "" {
        didSet { refreshSearchResults() }
    }
    @Published var historyFilter: HistoryFilter = .all
    @Published var selectedClipID: ClipItem.ID?
    @Published var previewState = PreviewState()
    @Published var lastError: String?
    @Published var lastPasteResult: PasteResult?
    @Published var debugPasteboardTypes: [String] = []
    @Published private(set) var globalHotKeyStatus: GlobalHotKeyStatus = .unavailable
    @Published private(set) var globalShortcutIsValid = true

    let storagePath: String
    private let repository: ClipRepository
    private let payloadStore: PayloadStore?
    private let settingsStore: SettingsStore
    private let adapter: PasteboardAdapter
    private let reader: ClipboardReader
    private let writer: ClipboardWriter
    private let pasteController: PasteController
    private let monitor: ClipboardMonitor
    private let searchService: ClipSearchService
    private var hotKeyController: GlobalHotKeyController?
    private var globalHotKeySuppressed = false
    private var launcherWindow: LauncherPanel?
    private var activationObserver: NSObjectProtocol?
    private var lastPasteTargetApplication: NSRunningApplication?

    init(
        repository: ClipRepository,
        payloadStore: PayloadStore? = nil,
        settingsStore: SettingsStore,
        adapter: PasteboardAdapter,
        storagePath: String,
    ) {
        let loadedSettings = settingsStore.load()
        self.repository = repository
        self.payloadStore = payloadStore
        self.settingsStore = settingsStore
        self.adapter = adapter
        settings = loadedSettings
        storageStats = .empty(maxHistoryCount: loadedSettings.maxHistoryCount)
        self.storagePath = storagePath
        reader = ClipboardReader(adapter: adapter)
        writer = ClipboardWriter(adapter: adapter)
        pasteController = PasteController(writer: ClipboardWriter(adapter: adapter))
        monitor = ClipboardMonitor(adapter: adapter, pollingInterval: loadedSettings.pollingInterval)
        searchService = ClipSearchService(repository: repository)
        startTrackingPasteTargetApplication()
        refresh()
        restoreLastClipboardOnStartupIfNeeded()
        startMonitoring()
        startGlobalHotKey()
    }

    static func live() -> AppState {
        do {
            let directory = try storageDirectory()
            let payloadStore = try PayloadStore(directory: directory.appendingPathComponent("Payloads", isDirectory: true))
            let repository = try SQLiteClipRepository(directory: directory, payloadStore: payloadStore)
            return AppState(
                repository: repository,
                payloadStore: payloadStore,
                settingsStore: UserDefaultsSettingsStore(),
                adapter: AppKitPasteboardAdapter(),
                storagePath: directory.path,
            )
        } catch {
            return AppState(
                repository: InMemoryClipRepository(),
                payloadStore: nil,
                settingsStore: UserDefaultsSettingsStore(),
                adapter: AppKitPasteboardAdapter(),
                storagePath: "In-memory fallback",
            )
        }
    }

    private static func storageDirectory() throws -> URL {
        if let override = ProcessInfo.processInfo.environment["CLIPDOCK_STORAGE_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return try SQLiteClipRepository.defaultDirectory()
    }

    var selectedClip: ClipItem? {
        guard let selectedClipID else { return clips.first }
        return clips.first { $0.id == selectedClipID }
    }

    func selectedClip(in items: [ClipItem]) -> ClipItem? {
        guard let selectedClipID else { return items.first }
        return items.first { $0.id == selectedClipID } ?? items.first
    }

    func previewedClip(in items: [ClipItem]) -> ClipItem? {
        guard let previewedItemID = previewState.previewedItemID else { return nil }
        return items.first { $0.id == previewedItemID }
    }

    var historyVisibleClips: [ClipItem] {
        visibleClips.filter { historyFilter.matches($0) }
    }

    func selectHistoryFilter(_ filter: HistoryFilter) {
        historyFilter = filter
        selectedClipID = selectedClip(in: historyVisibleClips)?.id
    }

    func startMonitoring() {
        monitor.pollingInterval = effectivePollingInterval
        monitor.onChange = { [weak self] _ in
            Task { @MainActor in
                self?.captureCurrentClipboard()
            }
        }
        monitor.start { [weak self] in
            MainActor.assumeIsolated {
                self?.settings ?? .defaults
            }
        }
    }

    func startGlobalHotKey() {
        guard let shortcut = KeyboardShortcutSpec.parse(settings.globalShortcut) else {
            globalShortcutIsValid = false
            globalHotKeyStatus = .unavailable
            return
        }
        globalShortcutIsValid = true
        hotKeyController = GlobalHotKeyController(shortcut: shortcut) { [weak self] in
            self?.openLauncher()
        }
        guard !globalHotKeySuppressed else {
            globalHotKeyStatus = .unavailable
            return
        }
        hotKeyController?.start()
        refreshGlobalHotKeyStatus()
    }

    func updateGlobalHotKeyShortcut() {
        guard let shortcut = KeyboardShortcutSpec.parse(settings.globalShortcut) else {
            globalShortcutIsValid = false
            globalHotKeyStatus = .unavailable
            return
        }
        globalShortcutIsValid = true
        guard !globalHotKeySuppressed else {
            hotKeyController?.stop()
            refreshGlobalHotKeyStatus()
            return
        }
        if hotKeyController == nil {
            startGlobalHotKey()
        } else {
            hotKeyController?.updateShortcut(shortcut)
            refreshGlobalHotKeyStatus()
        }
    }

    func setGlobalHotKeySuppressed(_ suppressed: Bool) {
        guard globalHotKeySuppressed != suppressed else { return }
        globalHotKeySuppressed = suppressed
        if suppressed {
            hotKeyController?.stop()
            refreshGlobalHotKeyStatus()
        } else {
            updateGlobalHotKeyShortcut()
        }
    }

    func refreshGlobalHotKeyStatus() {
        globalHotKeyStatus = hotKeyController?.status ?? .unavailable
    }

    func requestGlobalHotKeyPermission() {
        GlobalHotKeyController.requestAccessibilityPermissionPrompt()
        refreshGlobalHotKeyStatus()
    }

    func openAccessibilitySettings() {
        GlobalHotKeyController.openAccessibilitySettings()
    }

    func bringWindowToFront(title: String? = nil) {
        NSApp.activate()
        focusWindow(title: title)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            focusWindow(title: title)
        }
    }

    func openLauncher() {
        let hostingView = NSHostingView(rootView: LauncherView().environmentObject(self))
        if launcherWindow == nil {
            let panel = LauncherPanel(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 520),
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false,
            )
            panel.isReleasedWhenClosed = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.level = .floating
            panel.isMovable = true
            panel.isMovableByWindowBackground = true
            panel.hidesOnDeactivate = true
            panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]
            panel.onDismissRequest = { [weak self] in
                self?.closeLauncher()
            }
            panel.center()
            launcherWindow = panel
        }
        launcherWindow?.contentView = hostingView
        NSApp.activate()
        launcherWindow?.makeKeyAndOrderFront(nil)
        launcherWindow?.orderFrontRegardless()
        DispatchQueue.main.async { [weak launcherWindow] in
            launcherWindow?.beginOutsideClickMonitoring()
        }
    }

    func closeLauncher() {
        launcherWindow?.orderOut(nil)
    }

    func selectClip(_ id: ClipItem.ID?) {
        guard selectedClipID != id else { return }
        selectedClipID = id
    }

    func moveSelection(_ direction: SelectionDirection, in items: [ClipItem]) {
        selectClip(SelectionNavigator.move(from: selectedClipID, in: items, direction: direction))
    }

    func togglePreview(in items: [ClipItem]) {
        previewState.toggle(itemID: selectedClip(in: items)?.id)
    }

    func dismissPreview() {
        previewState.dismiss()
    }

    func captureCurrentClipboard() {
        guard let candidate = reader.readCaptureCandidate(settings: settings) else { return }
        do {
            var item = candidate.item
            if let imageData = candidate.imageData {
                item.payloadRef = try payloadStore?.saveImagePayload(
                    imageData,
                    contentHash: item.contentHash,
                    settings: settings,
                )
            }
            try repository.upsert(item)
            try repository.enforceRetention(settings: settings, now: Date())
            refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refresh() {
        do {
            clips = try repository.recent(limit: settings.maxHistoryCount)
            storageStats = try repository.storageStats(settings: settings)
            refreshSearchResults()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func refreshSearchResults() {
        do {
            visibleClips = try searchService.search(.parse(searchText))
        } catch {
            lastError = error.localizedDescription
            visibleClips = Array(clips.prefix(200))
        }
    }

    func restore(_ item: ClipItem?) {
        guard let item else { return }
        do {
            lastPasteResult = try pasteController.restore(item, settings: settings)
            try repository.markUsed(id: item.id, at: Date())
            refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restoreAndAutoPaste(_ item: ClipItem?) {
        guard let item else { return }
        let targetApplication = bestPasteTargetApplication()
        do {
            lastPasteResult = try pasteController.restore(
                item,
                settings: settings,
                forceAutoPaste: true,
                prepareForAutoPaste: {
                    targetApplication?.activate()
                },
            )
            if lastPasteResult == .autoPasteUnavailable {
                lastError = "自动粘贴需要开启辅助功能权限。已先恢复到系统剪贴板。"
                GlobalHotKeyController.requestAccessibilityPermissionPrompt()
            }
            try repository.markUsed(id: item.id, at: Date())
            refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func delete(_ item: ClipItem?) {
        guard let item else { return }
        do {
            try repository.delete(id: item.id)
            refresh()
            if !clips.contains(where: { $0.id == selectedClipID }) {
                selectedClipID = clips.first?.id
            }
            if previewState.previewedItemID == item.id {
                previewState.dismiss()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func clearHistory() {
        do {
            try repository.clear()
            refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func clearRecentHistory(since date: Date) {
        do {
            let recentItems = try repository.recent(limit: settings.maxHistoryCount)
            for item in recentItems where item.capturedAt >= date {
                try repository.delete(id: item.id)
            }
            refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func toggleFavorite(_ item: ClipItem?) {
        guard let item else { return }
        do {
            try repository.setFavorite(!item.isFavorite, id: item.id)
            refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func openExternally(_ item: ClipItem?) {
        guard let item else { return }
        do {
            switch item.primaryType {
            case .image:
                guard let payloadRef = item.payloadRef else {
                    lastError = "图片 payload 不存在，无法打开预览。"
                    return
                }
                NSWorkspace.shared.open(try imagePreviewURL(for: item, payloadRef: payloadRef))
            case .url:
                guard let url = item.externalURL else {
                    lastError = "链接格式无效，无法用浏览器打开。"
                    return
                }
                NSWorkspace.shared.open(url)
            case .text:
                let url = try writeTemporaryTextPreview(for: item)
                NSWorkspace.shared.open([url], withApplicationAt: URL(fileURLWithPath: "/System/Applications/TextEdit.app/"), configuration: NSWorkspace.OpenConfiguration())
            case .file:
                guard let url = item.fileURL else {
                    lastError = "文件路径无效，无法打开。"
                    return
                }
                NSWorkspace.shared.open(url)
            case .unknown:
                lastError = "此类型暂不支持外部打开。"
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func revealInFinder(_ item: ClipItem?) {
        guard let item else { return }
        guard let url = item.fileURL else {
            lastError = "文件路径无效，无法在 Finder 中显示。"
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func saveSettings() {
        updateGlobalHotKeyShortcut()
        applyLaunchAtLoginSetting()
        startMonitoring()
        settingsStore.save(settings)
        refresh()
    }

    private func applyLaunchAtLoginSetting() {
        do {
            try LaunchAtLoginController.apply(enabled: settings.launchAtLogin)
        } catch {
            if settings.launchAtLogin {
                lastError = "登录时启动设置失败：\(error.localizedDescription)"
            }
        }
    }

    func refreshPasteboardTypes() {
        debugPasteboardTypes = adapter.snapshot().declaredTypes
    }

    private var effectivePollingInterval: TimeInterval {
        settings.lowPowerPolling ? max(settings.pollingInterval, 2.0) : settings.pollingInterval
    }

    private func startTrackingPasteTargetApplication() {
        rememberPasteTarget(NSWorkspace.shared.frontmostApplication)
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main,
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor in
                self?.rememberPasteTarget(application)
            }
        }
    }

    private func rememberPasteTarget(_ application: NSRunningApplication?) {
        guard let application,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            return
        }
        if let bundleIdentifier = application.bundleIdentifier {
            let ignoredBundleIdentifiers: Set<String?> = [
                Bundle.main.bundleIdentifier,
                "com.apple.systemuiserver",
                "com.apple.dock",
                "com.apple.finder",
            ]
            guard !ignoredBundleIdentifiers.contains(bundleIdentifier) else {
                return
            }
        }
        lastPasteTargetApplication = application
    }

    private func bestPasteTargetApplication() -> NSRunningApplication? {
        if let lastPasteTargetApplication, !lastPasteTargetApplication.isTerminated {
            return lastPasteTargetApplication
        }
        return NSWorkspace.shared.runningApplications.first { application in
            application.activationPolicy == .regular
                && !application.isTerminated
                && application.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }
    }

    private func focusWindow(title: String?) {
        let window = title.flatMap { title in
            NSApp.windows.first { $0.title == title }
        } ?? NSApp.keyWindow ?? NSApp.windows.first(where: \.isVisible)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    private func restoreLastClipboardOnStartupIfNeeded() {
        guard settings.restoreLastClipboardOnStartup else { return }
        do {
            guard let item = try repository.recent(limit: settings.maxHistoryCount).first(where: { !$0.isSensitive }) else {
                return
            }
            try writer.restore(item)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func writeTemporaryTextPreview(for item: ClipItem) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ClipDockTextPreviews", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(item.id.uuidString).txt")
        try item.textValue.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func imagePreviewURL(for item: ClipItem, payloadRef: String) throws -> URL {
        let sourceURL = URL(fileURLWithPath: payloadRef)
        let data = try Data(contentsOf: sourceURL)
        let detectedExtension = ImagePayloadFile.preferredExtension(for: data)
        if detectedExtension != "bin", sourceURL.pathExtension.lowercased() == detectedExtension {
            return sourceURL
        }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ClipDockImagePreviews", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        if detectedExtension != "bin" {
            let url = directory.appendingPathComponent("\(item.id.uuidString).\(detectedExtension)")
            try data.write(to: url, options: [.atomic])
            return url
        }

        guard let image = NSImage(data: data),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw PreviewOpenError.unsupportedImagePayload
        }
        let url = directory.appendingPathComponent("\(item.id.uuidString).png")
        try pngData.write(to: url, options: [.atomic])
        return url
    }
}

private enum PreviewOpenError: LocalizedError {
    case unsupportedImagePayload

    var errorDescription: String? {
        switch self {
        case .unsupportedImagePayload:
            "图片 payload 格式无法预览。"
        }
    }
}

private extension ClipItem {
    var textValue: String {
        if case let .text(value) = payload {
            return value
        }
        return previewText
    }

    var externalURL: URL? {
        let value: String
        if case let .url(payloadURL) = payload {
            value = payloadURL
        } else {
            value = previewText
        }
        return URL(string: value)
    }

    var fileURL: URL? {
        filePresentation?.url
    }
}

final class LauncherPanel: NSPanel {
    var onDismissRequest: (() -> Void)?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func beginOutsideClickMonitoring() {
        guard isVisible else { return }
        guard localMouseMonitor == nil, globalMouseMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self else { return event }
            if self.isVisible, event.window !== self {
                self.requestDismiss()
            }
            return event
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.isVisible else { return }
                self.requestDismiss()
            }
        }
    }

    override func resignKey() {
        super.resignKey()
        guard isVisible else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isVisible, !self.isKeyWindow else { return }
            self.requestDismiss()
        }
    }

    override func orderOut(_ sender: Any?) {
        stopOutsideClickMonitoring()
        super.orderOut(sender)
    }

    override func close() {
        stopOutsideClickMonitoring()
        super.close()
    }

    private func requestDismiss() {
        onDismissRequest?()
    }

    private func stopOutsideClickMonitoring() {
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }
}
