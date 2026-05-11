import SwiftUI
import Combine

struct EditorView: View {
    @EnvironmentObject var store: NotesStore
    let node: NoteNode

    @State private var text = ""
    @State private var isPreview = false
    @State private var saveTimer: AnyCancellable?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if isPreview {
                MarkdownPreview(text: text)
            } else {
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
            }
        }
        .onAppear { text = store.readContent(of: node) }
        .onChange(of: node.id) { _ in text = store.readContent(of: node) }
        .onChange(of: text) { _ in scheduleSave() }
    }

    private var toolbar: some View {
        HStack {
            Text(node.name)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            Button {
                isPreview.toggle()
            } label: {
                Label(isPreview ? "편집" : "미리보기", systemImage: isPreview ? "pencil" : "eye")
                    .labelStyle(.iconOnly)
            }
            .help(isPreview ? "편집 모드로 전환" : "마크다운 미리보기")
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func scheduleSave() {
        saveTimer?.cancel()
        saveTimer = Just(())
            .delay(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { _ in store.saveContent(text, to: node) }
    }
}
