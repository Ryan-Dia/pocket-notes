import SwiftUI

struct PresetTheme: Identifiable {
    let id: String
    let name: String
    let bgHex: String
    let cardHex: String
    let accentHex: String
    let headingHex: String
}

final class ThemeStore: ObservableObject {
    static let presets: [PresetTheme] = [
        PresetTheme(id: "beige",  name: "베이지",  bgHex: "#F7F1E3", cardHex: "#FBF7EF", accentHex: "#C0634F", headingHex: "#1B5060"),
        PresetTheme(id: "dark",   name: "다크",   bgHex: "#1C1C1E", cardHex: "#3A3A3C", accentHex: "#FF9F0A", headingHex: "#FFFFFF"),
        PresetTheme(id: "mint",   name: "민트",   bgHex: "#E8F5F0", cardHex: "#F0FAF6", accentHex: "#2D9E6B", headingHex: "#1A5C3A"),
        PresetTheme(id: "slate",  name: "슬레이트", bgHex: "#EDF2F7", cardHex: "#F7FAFC", accentHex: "#4A7FA5", headingHex: "#2C4A6E"),
        PresetTheme(id: "rose",   name: "로즈",   bgHex: "#FCF0F3", cardHex: "#FEF7F9", accentHex: "#C0547A", headingHex: "#7A2B4A"),
    ]

    @AppStorage("themePreset")     var selectedPreset: String = "beige"
    @AppStorage("themeBgHex")      var bgHex:      String = "#F7F1E3"
    @AppStorage("themeCardHex")    var cardHex:    String = "#FBF7EF"
    @AppStorage("themeAccentHex")  var accentHex:  String = "#C0634F"
    @AppStorage("themeHeadingHex") var headingHex: String = "#1B5060"

    var isDark: Bool { selectedPreset == "dark" || (selectedPreset == "custom" && isDarkColor(bgHex)) }

    var bg:      Color { Color(hex: bgHex)      ?? Color(red: 0.969, green: 0.945, blue: 0.890) }
    var card:    Color { Color(hex: cardHex)    ?? Color(red: 0.984, green: 0.969, blue: 0.937) }
    var accent:  Color { Color(hex: accentHex)  ?? Color(red: 0.753, green: 0.388, blue: 0.314) }
    var heading: Color { Color(hex: headingHex) ?? Color(red: 0.106, green: 0.313, blue: 0.376) }

    private func isDarkColor(_ hex: String) -> Bool {
        guard let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : Optional(hex),
              h.count == 6,
              let value = UInt64(h, radix: 16) else { return false }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8)  & 0xFF) / 255
        let b = Double(value & 0xFF)          / 255
        // 상대 휘도 기준 0.5 미만이면 어두운 색
        return 0.2126 * r + 0.7152 * g + 0.0722 * b < 0.25
    }

    func applyPreset(_ preset: PresetTheme) {
        selectedPreset = preset.id
        bgHex      = preset.bgHex
        cardHex    = preset.cardHex
        accentHex  = preset.accentHex
        headingHex = preset.headingHex
    }
}

extension Color {
    init?(hex: String) {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard h.count == 6, let value = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8)  & 0xFF) / 255,
            blue:  Double(value & 0xFF)          / 255
        )
    }

    func toHex() -> String? {
        guard let ns = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return String(format: "#%02X%02X%02X",
            Int((ns.redComponent   * 255).rounded()),
            Int((ns.greenComponent * 255).rounded()),
            Int((ns.blueComponent  * 255).rounded()))
    }
}
