import SwiftUI
import Combine

// MARK: - NoteCardsView

struct NoteCardsView: View {
    @EnvironmentObject var store: NotesStore
    let folderURL: URL
    let onBack: () -> Void

    private var folder: NoteNode? {
        findNode(url: folderURL, in: store.roots)
    }

    private var notes: [NoteNode] {
        folder?.children?.filter { !$0.isFolder } ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.25)
            if notes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(notes) { note in
                            NoteCardView(note: note)
                                .padding(.horizontal, 12)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .background(PNTheme.bg)
        .onAppear { if folder == nil { onBack() } }
        .onChange(of: folder == nil) { isNil in
            if isNil { onBack() }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PNTheme.accent)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)

            Text(folder?.name ?? "")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(PNTheme.heading)
                .lineLimit(1)

            Spacer()

            Button {
                if let f = folder { store.createNote(in: f) }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PNTheme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(PNTheme.accent.opacity(0.4))
            Text("+ 버튼으로 노트를 추가하세요")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func findNode(url: URL, in nodes: [NoteNode]) -> NoteNode? {
        for node in nodes {
            if node.url == url { return node }
            if let ch = node.children, let found = findNode(url: url, in: ch) { return found }
        }
        return nil
    }
}

// MARK: - NoteCardView

struct NoteCardView: View {
    @EnvironmentObject var store: NotesStore
    let note: NoteNode

    @State private var text = ""
    @State private var saveTimer: AnyCancellable?

    private var dateString: String {
        let res = try? note.url.resourceValues(forKeys: [.contentModificationDateKey])
        guard let date = res?.contentModificationDate else { return "" }
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }

    var body: some View {
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
                    .frame(minHeight: 80)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }

            Divider().opacity(0.15)

            HStack(spacing: 14) {
                Image(systemName: "textformat")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(dateString)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                Spacer()

                Button {
                    store.delete(note)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .background(PNTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
        .onAppear { text = store.readContent(of: note) }
        .onChange(of: note.url) { _ in text = store.readContent(of: note) }
        .onChange(of: text) { _ in scheduleSave() }
    }

    private func scheduleSave() {
        saveTimer?.cancel()
        saveTimer = Just(())
            .delay(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .sink { _ in store.saveContent(text, to: note) }
    }
}
