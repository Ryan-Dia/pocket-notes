import SwiftUI

struct FolderListView: View {
    @EnvironmentObject var store: NotesStore
    let onSelectFolder: (NoteNode) -> Void

    @State private var renaming: NoteNode? = nil
    @State private var renameText = ""

    private var folders: [NoteNode] { store.roots.filter { $0.isFolder } }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.25)
            folderList
        }
        .background(PNTheme.bg)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("PocketNotes")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(PNTheme.heading)
            Spacer()
            Button { store.createFolder() } label: {
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

    private var folderList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(folders) { node in
                    if renaming?.id == node.id {
                        renameRow(for: node)
                    } else {
                        folderRow(for: node)
                    }
                    Divider()
                        .opacity(0.2)
                        .padding(.leading, 56)
                }
                if folders.isEmpty { emptyHint }
            }
        }
    }

    private func folderRow(for node: NoteNode) -> some View {
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
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .background(PNTheme.bg)
        .onTapGesture { onSelectFolder(node) }
        .contextMenu {
            Button("새 노트") { store.createNote(in: node) }
            Divider()
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

    private var emptyHint: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(PNTheme.accent.opacity(0.4))
            Text("+ 버튼으로 폴더를 만드세요")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
