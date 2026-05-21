import SwiftUI

struct FolderListView: View {
    @EnvironmentObject var store: NotesStore
    @EnvironmentObject var theme: ThemeStore
    let onSelectFolder: (NoteNode) -> Void

    @State private var renaming: NoteNode? = nil
    @State private var renameText = ""
    @State private var searchQuery = ""
    @State private var isSearching = false

    private var folders: [NoteNode] { store.roots.filter { $0.isFolder } }

    var body: some View {
        VStack(spacing: 0) {
            header
            if isSearching {
                searchBar
            }
            Divider().opacity(0.25)
            folderList
        }
        .background(theme.bg)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("PocketNotes")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(theme.heading)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isSearching.toggle() }
            } label: {
                Image(systemName: isSearching ? "xmark.circle.fill" : "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 10)

            Button { store.createFolder() } label: {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
            TextField("폴더 검색...", text: $searchQuery)
                .font(.system(size: 14))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private var filteredFolders: [NoteNode] {
        if searchQuery.isEmpty { return folders }
        return folders.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    private var folderList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredFolders) { node in
                    if renaming?.id == node.id {
                        renameRow(for: node)
                    } else {
                        folderRow(for: node)
                    }
                    Divider()
                        .opacity(0.2)
                        .padding(.leading, 56)
                }
                if filteredFolders.isEmpty { emptyHint }
            }
        }
    }

    private func folderRow(for node: NoteNode) -> some View {
        let noteCount = node.children?.filter { !$0.isFolder }.count ?? 0
        let preview = recentNotePreview(in: node)
        return HStack(spacing: 14) {
            Image(systemName: "folder")
                .font(.system(size: 20))
                .foregroundStyle(theme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let preview {
                    Text(preview)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text("\(noteCount)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(theme.accent.opacity(0.7))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .background(theme.bg)
        .onTapGesture { onSelectFolder(node) }
        .contextMenu {
            Button("새 노트") { store.createNote(in: node) }
            Button("새 하위 폴더") { store.createFolder(in: node) }
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
                .foregroundStyle(theme.accent)
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

    private func recentNotePreview(in folder: NoteNode) -> String? {
        guard let notes = folder.children?.filter({ !$0.isFolder }), !notes.isEmpty else { return nil }
        let sorted = notes.sorted {
            let a = (try? $0.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a > b
        }
        guard let url = sorted.first?.url,
              let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let firstLine = content.components(separatedBy: "\n")
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        guard let line = firstLine?.trimmingCharacters(in: .whitespaces), !line.isEmpty else { return nil }
        return line
    }

    private var emptyHint: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(theme.accent.opacity(0.4))
            Text("+ 버튼으로 폴더를 만드세요")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
