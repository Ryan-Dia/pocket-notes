import SwiftUI
import Carbon

struct SettingsView: View {
    var onCheckForUpdates: () -> Void = {}

    @EnvironmentObject var store: NotesStore
    @EnvironmentObject var theme: ThemeStore

    @AppStorage("panelEdge") private var panelEdge = "right"
    @AppStorage("hideOnLostFocus") private var hideOnLostFocus = false
    @AppStorage("hotkeyKeyCode") private var hotkeyKeyCode = 0
    @AppStorage("hotkeyModifiers") private var hotkeyModifiers = 0
    @AppStorage("createNoteKeyCode")     private var createNoteKeyCode     = 0
    @AppStorage("createNoteModifiers")   private var createNoteModifiers   = 0
    @AppStorage("createFolderKeyCode")   private var createFolderKeyCode   = 0
    @AppStorage("createFolderModifiers") private var createFolderModifiers = 0

    var body: some View {
        Form {
            Section("패널") {
                Picker("슬라이드 방향", selection: $panelEdge) {
                    Text("오른쪽").tag("right")
                    Text("왼쪽").tag("left")
                }
                .pickerStyle(.segmented)

                Toggle("다른 앱 클릭 시 자동 닫기", isOn: $hideOnLostFocus)
            }

            Section("단축키") {
                LabeledContent("패널 토글") {
                    HotkeyRecorderView(
                        keyCode: UserDefaults.standard.object(forKey: "hotkeyKeyCode") == nil ? kVK_Space : hotkeyKeyCode,
                        modifiers: UserDefaults.standard.object(forKey: "hotkeyModifiers") == nil ? optionKey : hotkeyModifiers,
                        onChange: { code, mods in
                            UserDefaults.standard.set(code, forKey: "hotkeyKeyCode")
                            UserDefaults.standard.set(mods, forKey: "hotkeyModifiers")
                            NotificationCenter.default.post(name: .pnHotkeyDidChange, object: nil)
                        }
                    )
                    .frame(width: 160, height: 28)
                }
                LabeledContent("노트 생성") {
                    HotkeyRecorderView(
                        keyCode: UserDefaults.standard.object(forKey: "createNoteKeyCode") == nil ? kVK_ANSI_N : createNoteKeyCode,
                        modifiers: UserDefaults.standard.object(forKey: "createNoteModifiers") == nil ? cmdKey : createNoteModifiers,
                        onChange: { code, mods in
                            UserDefaults.standard.set(code, forKey: "createNoteKeyCode")
                            UserDefaults.standard.set(mods, forKey: "createNoteModifiers")
                            NotificationCenter.default.post(name: .pnLocalHotkeyDidChange, object: nil)
                        }
                    )
                    .frame(width: 160, height: 28)
                }
                LabeledContent("폴더 생성") {
                    HotkeyRecorderView(
                        keyCode: UserDefaults.standard.object(forKey: "createFolderKeyCode") == nil ? kVK_ANSI_F : createFolderKeyCode,
                        modifiers: UserDefaults.standard.object(forKey: "createFolderModifiers") == nil ? cmdKey : createFolderModifiers,
                        onChange: { code, mods in
                            UserDefaults.standard.set(code, forKey: "createFolderKeyCode")
                            UserDefaults.standard.set(mods, forKey: "createFolderModifiers")
                            NotificationCenter.default.post(name: .pnLocalHotkeyDidChange, object: nil)
                        }
                    )
                    .frame(width: 160, height: 28)
                }
                Text("패널이 열린 상태에서만 동작합니다. 클릭 후 키 조합 입력, Delete로 기본값 복원.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Section("저장 위치") {
                LabeledContent("노트 폴더") {
                    Text(store.rootURL.path)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .foregroundStyle(.secondary)
                }
                Button("폴더 변경...") { choosFolder() }
                Button("Finder에서 열기") {
                    NSWorkspace.shared.open(store.rootURL)
                }
            }

            Section("테마") {
                HStack(spacing: 10) {
                    ForEach(ThemeStore.presets) { preset in
                        ThemePresetSwatch(
                            preset: preset,
                            isSelected: theme.selectedPreset == preset.id,
                            onSelect: { theme.applyPreset(preset) }
                        )
                    }
                    ThemeCustomSwatch(isSelected: theme.selectedPreset == "custom") {
                        theme.selectedPreset = "custom"
                    }
                }
                .padding(.vertical, 4)

                if theme.selectedPreset == "custom" {
                    ThemeColorRow(label: "배경", hex: $theme.bgHex)
                    ThemeColorRow(label: "카드", hex: $theme.cardHex)
                    ThemeColorRow(label: "강조", hex: $theme.accentHex)
                    ThemeColorRow(label: "제목", hex: $theme.headingHex)
                }
            }

            Section("업데이트") {
                LabeledContent("현재 버전") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                        .foregroundStyle(.secondary)
                }
                Button("업데이트 확인") { onCheckForUpdates() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 560)
        .navigationTitle("설정")
    }

    private func choosFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "선택"
        if panel.runModal() == .OK, let url = panel.url {
            store.rootURL = url
        }
    }
}

// MARK: - Theme Helper Views

private struct ThemePresetSwatch: View {
    let preset: PresetTheme
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        stops: [
                            .init(color: Color(hex: preset.bgHex)     ?? .white, location: 0.5),
                            .init(color: Color(hex: preset.accentHex) ?? .gray,  location: 0.5),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 38, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isSelected ? (Color(hex: preset.accentHex) ?? .blue) : Color.gray.opacity(0.3),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                Text(preset.name)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ThemeCustomSwatch: View {
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .frame(width: 38, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isSelected ? Color.blue : Color.gray.opacity(0.5),
                                style: StrokeStyle(lineWidth: isSelected ? 2 : 1.5, dash: [4])
                            )
                    )
                    .overlay(
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundStyle(isSelected ? .blue : .secondary)
                    )
                Text("커스텀")
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ThemeColorRow: View {
    let label: String
    @Binding var hex: String
    @State private var fieldText: String = ""

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: hex) ?? .white },
            set: { if let h = $0.toHex() { hex = h } }
        )
    }

    var body: some View {
        LabeledContent(label) {
            HStack(spacing: 8) {
                ColorPicker("", selection: colorBinding, supportsOpacity: false)
                    .labelsHidden()
                TextField("", text: $fieldText)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 80)
                    .onSubmit { applyFieldText() }
            }
        }
        .onAppear { fieldText = hex }
        .onChange(of: hex) { _, new in fieldText = new }
    }

    private func applyFieldText() {
        let cleaned = fieldText.hasPrefix("#") ? fieldText : "#\(fieldText)"
        if Color(hex: cleaned) != nil {
            hex = cleaned.uppercased()
        } else {
            fieldText = hex
        }
    }
}
