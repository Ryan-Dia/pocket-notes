import SwiftUI
import Combine

struct NoteCardView: View {
    @EnvironmentObject var store: NotesStore
    let note: NoteNode

    @State private var text = ""
    @State private var saveTimer: AnyCancellable?
    @FocusState private var isFocused: Bool

    private var dateString: String {
        let res = try? note.url.resourceValues(forKeys: [.contentModificationDateKey])
        guard let date = res?.contentModificationDate else { return "" }
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(isFocused ? PNTheme.accent : PNTheme.accent.opacity(0.35))
                .frame(width: 3)
                .animation(.easeInOut(duration: 0.15), value: isFocused)

            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("노트를 작성하세요...")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $text)
                        .font(.system(size: 14))
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .frame(minHeight: 90)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .focused($isFocused)
                }

                Divider().opacity(0.12)

                HStack(spacing: 14) {
                    Image(systemName: "textformat")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(dateString)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)

                    Spacer()

                    Button { store.delete(note) } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
        .background(PNTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(isFocused ? 0.12 : 0.06), radius: isFocused ? 8 : 4, x: 0, y: 2)
        .onAppear { text = store.readContent(of: note) }
        .onChange(of: note.url) { _, _ in text = store.readContent(of: note) }
        .onChange(of: text) { scheduleSave() }
    }

    private func scheduleSave() {
        saveTimer?.cancel()
        saveTimer = Just(text)
            .delay(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak store] content in store?.saveContent(content, to: note) }
    }
}
