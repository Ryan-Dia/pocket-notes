import SwiftUI
import Combine

struct NoteCardView: View {
    @EnvironmentObject var store: NotesStore
    @EnvironmentObject var theme: ThemeStore
    let note: NoteNode

    @State private var text = ""
    @State private var saveTimer: AnyCancellable?
    @State private var isActive = false
    @State private var isHandleHovered = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    private var dateString: String {
        let res = try? note.url.resourceValues(forKeys: [.contentModificationDateKey])
        guard let date = res?.contentModificationDate else { return "" }
        return Self.dateFormatter.string(from: date)
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Rectangle()
                    .fill(isActive ? theme.accent : theme.accent.opacity(0.35))
                    .animation(.easeInOut(duration: 0.15), value: isActive)
                VStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(spacing: 4) {
                            Circle().frame(width: 4, height: 4)
                            Circle().frame(width: 4, height: 4)
                        }
                    }
                }
                .foregroundStyle(Color.white.opacity(isHandleHovered ? 1.0 : 0.6))
                .animation(.easeInOut(duration: 0.12), value: isHandleHovered)
            }
            .frame(width: 18)
            .onHover { isHandleHovered = $0 }

            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("노트를 작성하세요...")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .allowsHitTesting(false)
                    }
                    MarkdownEditor(text: $text, accentColor: theme.accent) { focused in
                        isActive = focused
                    }
                    .frame(minHeight: 110)
                }

                Divider().opacity(0.12)

                HStack(spacing: 14) {
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
        .background(theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(isActive ? 0.12 : 0.06), radius: isActive ? 8 : 4, x: 0, y: 2)
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
