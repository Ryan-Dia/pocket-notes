import SwiftUI
import Carbon

struct SettingsView: View {
    @EnvironmentObject var store: NotesStore

    @AppStorage("panelEdge") private var panelEdge = "right"
    @AppStorage("hideOnLostFocus") private var hideOnLostFocus = false
    @AppStorage("hotkeyKeyCode") private var hotkeyKeyCode = 0
    @AppStorage("hotkeyModifiers") private var hotkeyModifiers = 0

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
                            NotificationCenter.default.post(name: .init("pn.hotkeyDidChange"), object: nil)
                        }
                    )
                    .frame(width: 160, height: 28)
                }
                Text("클릭 후 원하는 키 조합을 누르세요. Delete로 기본값(⌥Space) 복원.")
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
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 380)
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
