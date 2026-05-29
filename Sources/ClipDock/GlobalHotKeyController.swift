import AppKit
import ApplicationServices
import Carbon
import ClipDockCore
import Foundation

enum GlobalHotKeyStatus: Equatable {
    case active
    case unavailable

    var label: String {
        switch self {
        case .active: "已启用"
        case .unavailable: "未启用"
        }
    }

    var systemImageName: String {
        switch self {
        case .active: "checkmark.circle.fill"
        case .unavailable: "xmark.circle.fill"
        }
    }
}

final class GlobalHotKeyController {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var shortcut: KeyboardShortcutSpec
    private let action: () -> Void
    private let hotKeyIdentifier = UInt32.random(in: 1 ... UInt32.max)
    private var registrationStatus: OSStatus?

    private static let hotKeySignature = OSType(
        UInt32(Character("C").asciiValue!) << 24
            | UInt32(Character("D").asciiValue!) << 16
            | UInt32(Character("K").asciiValue!) << 8
            | UInt32(Character("H").asciiValue!)
    )

    init(shortcut: KeyboardShortcutSpec, action: @escaping () -> Void) {
        self.shortcut = shortcut
        self.action = action
    }

    deinit {
        stop()
    }

    func start() {
        stop()
        guard let keyCode = shortcut.carbonKeyCode else {
            registrationStatus = OSStatus(eventNotHandledErr)
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed),
        )
        var newEventHandlerRef: EventHandlerRef?
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.handleHotKeyEvent,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &newEventHandlerRef,
        )
        guard installStatus == noErr else {
            registrationStatus = installStatus
            return
        }

        let hotKeyID = EventHotKeyID(
            signature: Self.hotKeySignature,
            id: hotKeyIdentifier,
        )
        var newHotKeyRef: EventHotKeyRef?
        let hotKeyStatus = RegisterEventHotKey(
            keyCode,
            shortcut.carbonModifierFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &newHotKeyRef,
        )
        guard hotKeyStatus == noErr else {
            if let newEventHandlerRef {
                RemoveEventHandler(newEventHandlerRef)
            }
            registrationStatus = hotKeyStatus
            return
        }

        eventHandlerRef = newEventHandlerRef
        hotKeyRef = newHotKeyRef
        registrationStatus = noErr
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        hotKeyRef = nil
        eventHandlerRef = nil
    }

    var status: GlobalHotKeyStatus {
        hotKeyRef == nil ? .unavailable : .active
    }

    func updateShortcut(_ shortcut: KeyboardShortcutSpec) {
        self.shortcut = shortcut
        start()
    }

    static func requestAccessibilityPermissionPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func handle(_ event: NSEvent) {
        guard event.matches(shortcut) else {
            return
        }
        DispatchQueue.main.async { [action] in action() }
    }

    private func handleHotKeyPressed() {
        DispatchQueue.main.async { [action] in action() }
    }

    private static let handleHotKeyEvent: EventHandlerUPP = { _, _, userData in
        guard let userData else { return OSStatus(eventNotHandledErr) }
        let controller = Unmanaged<GlobalHotKeyController>.fromOpaque(userData).takeUnretainedValue()
        controller.handleHotKeyPressed()
        return noErr
    }
}

private extension NSEvent {
    func matches(_ shortcut: KeyboardShortcutSpec) -> Bool {
        let flags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.matches(shortcut.modifiers) else { return false }
        return normalizedKey == shortcut.key
    }

    var normalizedKey: String? {
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

private extension NSEvent.ModifierFlags {
    func matches(_ modifiers: Set<KeyboardModifier>) -> Bool {
        contains(.command) == modifiers.contains(.command)
            && contains(.shift) == modifiers.contains(.shift)
            && contains(.option) == modifiers.contains(.option)
            && contains(.control) == modifiers.contains(.control)
    }
}
