import SwiftUI

struct FolderContentsView: View {
    @EnvironmentObject var store: NotesStore
    let folder: NoteNode
    let onBack: () -> Void
    let onSelectSubfolder: (NoteNode) -> Void

    @State private var renaming: NoteNode? = nil
    @State private var renameText = ""

    private var depth: Int { store.depth(of: folder) }
    private var subfolders: [NoteNode] { folder.children?.filter { $0.isFolder } ?? [] }
    private var notes: [NoteNode] { folder.children?.filter { !$0.isFolder } ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.25)
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !subfolders.isEmpty {
                        subfolderSection
                        Divider().opacity(0.25).padding(.vertical, 4)
                    }
                    noteSection
                }
            }
        }
        .background(PNTheme.bg)
        .onReceive(store.$roots) { _ in
            if store.findFolder(url: folder.url) == nil { onBack() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Button { onBack() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PNTheme.accent)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)

            Text(folder.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(PNTheme.heading)
                .lineLimit(1)

            Spacer()

            // 노트 생성: depth ≥ 1이면 항상 표시
            Button { store.createNote(in: folder) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PNTheme.accent)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)

            // 폴더 생성: depth < 2일 때만 (depth 2 = 하위 폴더, 더 이상 불가)
            if depth < 2 {
                Button { store.createFolder(in: folder) } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(PNTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    // MARK: - Subfolder Section

    private var subfolderSection: some View {
        ForEach(subfolders) { node in
            if renaming?.id == node.id {
                renameRow(for: node)
            } else {
                subfolderRow(for: node)
            }
            Divider()
                .opacity(0.2)
                .padding(.leading, 56)
        }
    }

    private func subfolderRow(for node: NoteNode) -> some View {
        let noteCount = node.children?.filter { !$0.isFolder }.count ?? 0
        return HStack(spacing: 14) {
            Image(systemName: "folder")
                .font(.system(size: 20))
                .foregroundStyle(PNTheme.accent)
                .frame(width: 28)
            Text(node.name)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
            Text("\(noteCount)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(PNTheme.accent.opacity(0.7))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .background(PNTheme.bg)
        .onTapGesture { onSelectSubfolder(node) }
        .contextMenu {
            Button("새 노트") { store.createNote(in: node) }
            Button("이름 변경") {
                renameText = node.name
                renaming = node
            }
            Divider()
            Button("삭제", role: .destructive) { store.delete(node) }
        }
    }

    private func renameRow(for node: NoteNode) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "folder")
                .font(.system(size: 20))
                .foregroundStyle(PNTheme.accent)
                .frame(width: 28)
            TextField("폴더 이름", text: $renameText)
                .onSubmit {
                    let t = renameText.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty { store.rename(node, to: t) }
                    renaming = nil
                }
                .onExitCommand { renaming = nil }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Note Section

    private var noteSection: some View {
        Group {
            ForEach(notes) { note in
                NoteCardView(note: note)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
            }
            if notes.isEmpty && subfolders.isEmpty {
                emptyHint
            }
        }
        .padding(.bottom, 12)
    }

    private var emptyHint: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(PNTheme.accent.opacity(0.4))
            Text("노트를 추가하세요")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
