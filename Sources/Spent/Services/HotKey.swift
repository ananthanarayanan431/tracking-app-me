import Carbon.HIToolbox
import Foundation

/// A system-wide ⌥⇧F shortcut that starts or pauses the focus timer, via Carbon's
/// RegisterEventHotKey (no Accessibility permission needed).
final class HotKey {
    static let shared = HotKey()
    private static let defaultsKey = "focusShortcutEnabled"

    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var action: (() -> Void)?

    var isEnabledInSettings: Bool { UserDefaults.standard.bool(forKey: Self.defaultsKey) }
    var isRegistered: Bool { ref != nil }

    @discardableResult
    func register() -> Bool {
        if ref != nil { return true }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKey.shared.action?() }
            return noErr
        }, 1, &spec, nil, &handler)
        guard status == noErr else { return false }
        let id = EventHotKeyID(signature: OSType(0x5350_4E54), id: 1) // 'SPNT'
        let r = RegisterEventHotKey(UInt32(kVK_ANSI_F), UInt32(optionKey | shiftKey), id, GetApplicationEventTarget(), 0, &ref)
        let ok = r == noErr
        UserDefaults.standard.set(ok, forKey: Self.defaultsKey)
        return ok
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
        ref = nil
        handler = nil
        UserDefaults.standard.set(false, forKey: Self.defaultsKey)
    }
}
