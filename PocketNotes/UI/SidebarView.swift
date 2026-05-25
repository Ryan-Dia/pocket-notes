import SwiftUI

struct FolderListView: View {
    @EnvironmentObject var store: NotesStore
    @EnvironmentObject var theme: ThemeStore
    let onSelectFolder: (NoteNode) -> Void

    @State private var renaming: NoteNode? = nil
    @State private var renameText = ""
    @State private var searchQuery = ""
    @State private var isSearching = false
    @State private var hoveredFolderID: String?

    // Drag state
    @State private var dragFolder: NoteNode? = nil
    @State private var dragFolderStartIdx: Int = 0
    @State private var dragFolderTranslation: CGFloat = 0
    @State private var dragFolderTargetIdx: Int = 0

    private let folderItemHeight: CGFloat = 66

    private var allFolders: [NoteNode] {
        store.orderedFolders(store.roots.filter { $0.isFolder }, in: store.rootURL)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if isSearching { searchBar }
            Divider().opacity(0.25)
            folderList
            Divider().opacity(0.25)
            bottomBar
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
        if searchQuery.isEmpty { return allFolders }
        return allFolders.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    private var folderList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(filteredFolders.enumerated()), id: \.element.id) { idx, node in
                    let isDraggingThis = dragFolder?.id == node.id
                    let draggingDown = dragFolderTargetIdx > dragFolderStartIdx
                    let insertAbove = dragFolder != nil && !isDraggingThis
                        && dragFolderTargetIdx == idx
                        && !draggingDown
                        && dragFolderTargetIdx != dragFolderStartIdx
                    let insertBelow = dragFolder != nil && !isDraggingThis
                        && dragFolderTargetIdx == idx
                        && draggingDown

                    Group {
                        if renaming?.id == node.id {
                            renameRow(for: node)
                        } else {
                            folderRow(for: node, idx: idx)
                                .offset(y: isDraggingThis ? dragFolderTranslation : 0)
                                .scaleEffect(isDraggingThis ? 1.02 : 1.0)
                                .shadow(color: isDraggingThis ? .black.opacity(0.12) : .clear, radius: 6, x: 0, y: 3)
                                .zIndex(isDraggingThis ? 1 : 0)
                                .overlay(alignment: .top) {
                                    if insertAbove {
                                        Rectangle().fill(theme.accent).frame(height: 2).padding(.leading, 58)
                                    }
                                }
                                .overlay(alignment: .bottom) {
                                    if insertBelow {
                                        Rectangle().fill(theme.accent).frame(height: 2).padding(.leading, 58)
                                    }
                                }
                        }
                    }
                    Divider().opacity(isDraggingThis ? 0 : 0.2).padding(.leading, 56)
                }
                if filteredFolders.isEmpty { emptyHint }
            }
        }
    }

    private func folderRow(for node: NoteNode, idx: Int) -> some View {
        let noteCount = node.totalNoteCount
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
            dotGrid
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
                .gesture(folderDragGesture(node: node, idx: idx))
                .onHover { isHovered in
                    if dragFolder == nil { hoveredFolderID = isHovered ? node.id : nil }
                }
                .opacity(hoveredFolderID == node.id && dragFolder == nil ? 1 : 0.18)
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
        .opacity(dragFolder?.id == node.id ? 0.35 : 1.0)
        .contentShape(Rectangle())
        .background(theme.bg)
        .onTapGesture { onSelectFolder(node) }
        .contextMenu {
            Button("새 노트") { store.createNote(in: node) }
            Button("새 하위 폴더") { store.createFolder(in: node) }
            Divider()
            Button("이름 변경") { renameText = node.name; renaming = node }
            Divider()
            Button("삭제", role: .destructive) { store.delete(node) }
        }
    }

    private var dotGrid: some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 3) {
                    Circle().frame(width: 3, height: 3)
                    Circle().frame(width: 3, height: 3)
                }
            }
        }
        .foregroundStyle(Color.secondary.opacity(0.5))
    }

    private func folderDragGesture(node: NoteNode, idx: Int) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .onChanged { val in
                if dragFolder == nil {
                    dragFolder = node
                    dragFolderStartIdx = idx
                    dragFolderTargetIdx = idx
                }
                dragFolderTranslation = val.translation.height
                let delta = Int((dragFolderTranslation / folderItemHeight).rounded())
                dragFolderTargetIdx = max(0, min(filteredFolders.count - 1, dragFolderStartIdx + delta))
            }
            .onEnded { _ in
                let from = dragFolderStartIdx
                let to = dragFolderTargetIdx
                if from != to {
                    // filteredFolders 기준 인덱스를 allFolders 기준 인덱스로 변환
                    let folders = filteredFolders
                    let all = allFolders
                    if from < folders.count && to < folders.count {
                        let fromID = folders[from].id
                        let toID = folders[to].id
                        let allFrom = all.firstIndex(where: { $0.id == fromID }) ?? from
                        let allTo = all.firstIndex(where: { $0.id == toID }) ?? to
                        store.reorderFolders(in: store.rootURL, from: IndexSet([allFrom]), to: allTo > allFrom ? allTo + 1 : allTo, current: all)
                    }
                }
                dragFolder = nil
                dragFolderTranslation = 0
                dragFolderTargetIdx = 0
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

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Button {
                NotificationCenter.default.post(name: .pnOpenSettings, object: nil)
            } label: {
                Text("⚙️")
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.bg)
    }
}

