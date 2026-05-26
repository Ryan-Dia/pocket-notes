import AppKit
import Carbon

extension Notification.Name {
    static let pnCreateNote          = Notification.Name("pn.local.createNote")
    static let pnCreateFolder        = Notification.Name("pn.local.createFolder")
    static let pnOpenSettings        = Notification.Name("pn.openSettings")
    static let pnHotkeyDidChange     = Notification.Name("pn.hotkeyDidChange")
    static let pnLocalHotkeyDidChange = Notification.Name("pn.localHotkeyDidChange")
}

final class LocalHotkeyMonitor {
    private var monitor: Any?
    private var noteKeyCode: Int   = kVK_ANSI_N
    private var noteMods: Int      = cmdKey
    private var folderKeyCode: Int = kVK_ANSI_F
    private var folderMods: Int    = cmdKey

    deinit { stop() }

    func update(createNote: (keyCode: Int, modifiers: Int),
                createFolder: (keyCode: Int, modifiers: Int)) {
        noteKeyCode   = createNote.keyCode
        noteMods      = createNote.modifiers
        folderKeyCode = createFolder.keyCode
        folderMods    = createFolder.modifiers
        restart()
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    private func restart() {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let code = Int(event.keyCode)
            let mods = self.carbonMods(from: event.modifierFlags)
            if code == self.noteKeyCode && mods == self.noteMods {
                NotificationCenter.default.post(name: .pnCreateNote, object: nil)
                return nil
            }
            if code == self.folderKeyCode && mods == self.folderMods {
                NotificationCenter.default.post(name: .pnCreateFolder, object: nil)
                return nil
            }
            return event
        }
    }

    private func carbonMods(from flags: NSEvent.ModifierFlags) -> Int {
        var m = 0
        if flags.contains(.command) { m |= cmdKey }
        if flags.contains(.option)  { m |= optionKey }
        if flags.contains(.control) { m |= controlKey }
        if flags.contains(.shift)   { m |= shiftKey }
        return m
    }
}
