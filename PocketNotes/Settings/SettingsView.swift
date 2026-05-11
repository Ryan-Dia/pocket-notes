import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: NotesStore

    @AppStorage("panelEdge") private var panelEdge = "right"
    @AppStorage("hideOnLostFocus") private var hideOnLostFocus = false

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
                    Text("⌥Space")
                        .foregroundStyle(.secondary)
                }
                Text("v2에서 커스텀 단축키 지원 예정")
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
        .frame(width: 400, height: 340)
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
