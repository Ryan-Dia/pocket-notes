import Carbon

final class GlobalHotkey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let action: () -> Void

    private static var activeHandlers: [UInt32: GlobalHotkey] = [:]
    private static var nextID: UInt32 = 1

    private let hotkeyID: UInt32

    init(action: @escaping () -> Void) {
        self.action = action
        self.hotkeyID = Self.nextID
        Self.nextID += 1

        register()
    }

    deinit {
        unregister()
    }

    private func register() {
        let savedKey = UserDefaults.standard.integer(forKey: "hotkeyKeyCode")
        let savedMod = UserDefaults.standard.integer(forKey: "hotkeyModifiers")

        // 기본값: Option(⌥) + Space
        let keyCode = savedKey == 0 ? kVK_Space : savedKey
        let modifiers = savedMod == 0 ? optionKey : savedMod

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let id = EventHotKeyID(signature: OSType(0x504E_4F54), id: hotkeyID) // 'PNOT'

        Self.activeHandlers[hotkeyID] = self

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                var hotKeyID = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
                GlobalHotkey.activeHandlers[hotKeyID.id]?.action()
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )

        RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    private func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let handler = eventHandler { RemoveEventHandler(handler) }
        Self.activeHandlers.removeValue(forKey: hotkeyID)
    }
}
