import Carbon.HIToolbox

// MARK: - Global hotkey
// Carbon RegisterEventHotKey работает без разрешения «Универсального доступа».

final class HotKey {
    /// ⌃⌥⌘C — пауза / вернуть свои курсоры.
    static let pauseKeyCode = UInt32(kVK_ANSI_C)
    static let pauseModifiers = UInt32(controlKey | optionKey | cmdKey)
    static let pauseDisplay = "⌃⌥⌘C"

    var onPress: (() -> Void)?
    private var ref: EventHotKeyRef?

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return noErr }
            Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue().onPress?()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    func register(keyCode: UInt32, modifiers: UInt32) {
        if let ref { UnregisterEventHotKey(ref) }
        let id = EventHotKeyID(signature: OSType(0x4353_5750), id: 1)  // 'CSWP'
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
    }
}
