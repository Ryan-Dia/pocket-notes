import SwiftUI
import Carbon
import AppKit

// MARK: - Key Display Helper

enum HotkeyDisplay {
    static func string(keyCode: Int, modifiers: Int) -> String {
        var result = ""
        if modifiers & controlKey != 0 { result += "⌃" }
        if modifiers & optionKey  != 0 { result += "⌥" }
        if modifiers & shiftKey   != 0 { result += "⇧" }
        if modifiers & cmdKey     != 0 { result += "⌘" }
        result += keyName(for: keyCode)
        return result
    }

    private static func keyName(for keyCode: Int) -> String {
        switch keyCode {
        // 특수 키
        case kVK_Space:         return "Space"
        case kVK_Return:        return "↩"
        case kVK_Tab:           return "⇥"
        case kVK_Delete:        return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Escape:        return "⎋"
        case kVK_UpArrow:       return "↑"
        case kVK_DownArrow:     return "↓"
        case kVK_LeftArrow:     return "←"
        case kVK_RightArrow:    return "→"
        // 펑션 키
        case kVK_F1:  return "F1";  case kVK_F2:  return "F2"
        case kVK_F3:  return "F3";  case kVK_F4:  return "F4"
        case kVK_F5:  return "F5";  case kVK_F6:  return "F6"
        case kVK_F7:  return "F7";  case kVK_F8:  return "F8"
        case kVK_F9:  return "F9";  case kVK_F10: return "F10"
        case kVK_F11: return "F11"; case kVK_F12: return "F12"
        // 알파벳 (ANSI keyCode → 문자, 레이아웃 독립적)
        case kVK_ANSI_A: return "A"; case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"; case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"; case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"; case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"; case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"; case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"; case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"; case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"; case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"; case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"; case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"; case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"; case kVK_ANSI_Z: return "Z"
        // 숫자
        case kVK_ANSI_0: return "0"; case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"; case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"; case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"; case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"; case kVK_ANSI_9: return "9"
        default:
            return charForKeyCode(keyCode)?.uppercased() ?? "?"
        }
    }

    private static func charForKeyCode(_ keyCode: Int) -> String? {
        let src = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let dataRef = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let layout = unsafeBitCast(dataRef, to: CFData.self)
        let ptr = unsafeBitCast(CFDataGetBytePtr(layout), to: UnsafePointer<UCKeyboardLayout>.self)
        var dead: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var count = 0
        UCKeyTranslate(ptr, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                       UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                       &dead, 4, &count, &chars)
        guard count > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: count)
    }
}

// MARK: - RecorderNSView

final class RecorderNSView: NSView {
    var isRecording = false { didSet { needsDisplay = true } }
    var keyCode: Int = kVK_Space
    var modifiers: Int = optionKey
    var onChange: ((Int, Int) -> Void)?

    private static let functionKeyCodes: Set<Int> = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6,
        kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12
    ]

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard !isRecording else { return }
        window?.makeFirstResponder(self)
        isRecording = true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        needsDisplay = true
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }
        let code = Int(event.keyCode)
        let mods = carbonMods(from: event.modifierFlags)

        if code == kVK_Escape {
            isRecording = false
            window?.makeFirstResponder(nil)
            return
        }

        if code == kVK_Delete || code == kVK_ForwardDelete {
            keyCode = kVK_Space
            modifiers = optionKey
            onChange?(kVK_Space, optionKey)
            isRecording = false
            window?.makeFirstResponder(nil)
            return
        }

        let isFn = Self.functionKeyCodes.contains(code)
        if !isFn && mods == 0 { return }

        keyCode = code
        modifiers = mods
        onChange?(code, mods)
        isRecording = false
        window?.makeFirstResponder(nil)
    }

    private func carbonMods(from flags: NSEvent.ModifierFlags) -> Int {
        var m = 0
        if flags.contains(.command) { m |= cmdKey }
        if flags.contains(.option)  { m |= optionKey }
        if flags.contains(.control) { m |= controlKey }
        if flags.contains(.shift)   { m |= shiftKey }
        return m
    }

    override func draw(_ dirtyRect: NSRect) {
        let label = isRecording
            ? "키를 누르세요..."
            : HotkeyDisplay.string(keyCode: keyCode, modifiers: modifiers)

        let bg: NSColor = isRecording ? .selectedControlColor : .controlBackgroundColor
        bg.setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        path.fill()

        let border: NSColor = isRecording ? .controlAccentColor : .separatorColor
        border.setStroke()
        path.lineWidth = 1
        path.stroke()

        let color: NSColor = isRecording ? .secondaryLabelColor : .labelColor
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: color
        ]
        let str = NSAttributedString(string: label, attributes: attrs)
        let sz = str.size()
        str.draw(at: NSPoint(x: (bounds.width - sz.width) / 2, y: (bounds.height - sz.height) / 2))
    }
}

// MARK: - HotkeyRecorderView

struct HotkeyRecorderView: NSViewRepresentable {
    let keyCode: Int
    let modifiers: Int
    let onChange: (Int, Int) -> Void

    func makeNSView(context: Context) -> RecorderNSView {
        let v = RecorderNSView()
        v.keyCode = keyCode
        v.modifiers = modifiers
        v.onChange = onChange
        return v
    }

    func updateNSView(_ v: RecorderNSView, context: Context) {
        if !v.isRecording {
            v.keyCode = keyCode
            v.modifiers = modifiers
        }
        v.onChange = onChange
        v.needsDisplay = true
    }
}
