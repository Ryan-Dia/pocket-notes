import SwiftUI

struct FolderContentsView: View {
    @EnvironmentObject var store: NotesStore
    @EnvironmentObject var theme: ThemeStore
    let folder: NoteNode
    let onBack: () -> Void
    let onSelectSubfolder: (NoteNode) -> Void

    @State private var renaming: NoteNode? = nil
    @State private var renameText = ""
    @State private var hoveredFolderID: String?

    // Note drag state
    @State private var dragNote: NoteNode? = nil
    @State private var dragNoteStartIdx: Int = 0
    @State private var dragNoteTranslation: CGFloat = 0
    @State private var dragNoteTargetIdx: Int = 0

    // Subfolder drag state
    @State private var dragFolder: NoteNode? = nil
    @State private var dragFolderStartIdx: Int = 0
    @State private var dragFolderTranslation: CGFloat = 0
    @State private var dragFolderTargetIdx: Int = 0

    private let noteItemHeight: CGFloat = 148
    private let folderItemHeight: CGFloat = 50

    private var depth: Int { store.depth(of: folder) }
    private var currentNode: NoteNode? { store.findFolder(url: folder.url) }
    private var subfolders: [NoteNode] {
        store.orderedFolders(currentNode?.children?.filter { $0.isFolder } ?? [], in: folder.url)
    }
    private var notes: [NoteNode] {
        store.orderedNotes(currentNode?.children?.filter { !$0.isFolder } ?? [], in: folder.url)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.25)
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !subfolders.isEmpty {
                        subfolderSection
                        HStack(spacing: 8) {
                            Text("노트")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .kerning(0.5)
                            Rectangle()
                                .fill(Color.primary.opacity(0.07))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                    }
                    noteSection
                }
            }
        }
        .background(theme.bg)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Button { onBack() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)

            Text(folder.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(theme.heading)
                .lineLimit(1)

            Spacer()

            Button { store.createNote(in: folder) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)

            if depth < 2 {
                Button { store.createFolder(in: folder) } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.accent)
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
        ForEach(Array(subfolders.enumerated()), id: \.element.id) { idx, node in
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
                    FolderRenameRow(text: $renameText) {
                        let t = renameText.trimmingCharacters(in: .whitespaces)
                        if !t.isEmpty { store.rename(node, to: t) }
                        renaming = nil
                    } onCancel: { renaming = nil }
                } else {
                    subfolderRow(for: node, idx: idx)
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
    }

    private func subfolderRow(for node: NoteNode, idx: Int) -> some View {
        let noteCount = node.totalNoteCount
        return HStack(spacing: 14) {
            Image(systemName: "folder")
                .font(.system(size: 20))
                .foregroundStyle(theme.accent)
                .frame(width: 28)
            Text(node.name)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
            DragHandle()
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
        .onTapGesture { onSelectSubfolder(node) }
        .contextMenu {
            Button("새 노트") { store.createNote(in: node) }
            Button("이름 변경") { renameText = node.name; renaming = node }
            Divider()
            Button("삭제", role: .destructive) { store.delete(node) }
        }
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
                dragFolderTargetIdx = max(0, min(subfolders.count - 1, dragFolderStartIdx + delta))
            }
            .onEnded { _ in
                let from = dragFolderStartIdx
                let to = dragFolderTargetIdx
                if from != to {
                    store.reorderFolders(in: folder.url, from: IndexSet([from]), to: to > from ? to + 1 : to, current: subfolders)
                }
                dragFolder = nil
                dragFolderTranslation = 0
                dragFolderTargetIdx = 0
            }
    }

    // MARK: - Note Section

    private var noteSection: some View {
        Group {
            ForEach(Array(notes.enumerated()), id: \.element.id) { idx, note in
                let isDraggingThis = dragNote?.id == note.id
                let draggingDown = dragNoteTargetIdx > dragNoteStartIdx
                let insertAbove = dragNote != nil && !isDraggingThis
                    && dragNoteTargetIdx == idx
                    && !draggingDown
                    && dragNoteTargetIdx != dragNoteStartIdx
                let insertBelow = dragNote != nil && !isDraggingThis
                    && dragNoteTargetIdx == idx
                    && draggingDown

                NoteCardView(note: note)
                    .overlay(alignment: .leading) {
                        Color.clear
                            .frame(width: 18)
                            .contentShape(Rectangle())
                            .gesture(noteDragGesture(note: note, idx: idx))
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .opacity(isDraggingThis ? 0.3 : 1.0)
                .offset(y: isDraggingThis ? dragNoteTranslation : 0)
                .scaleEffect(isDraggingThis ? 1.02 : 1.0)
                .shadow(color: isDraggingThis ? .black.opacity(0.15) : .clear, radius: 10, x: 0, y: 4)
                .zIndex(isDraggingThis ? 1 : 0)
                .overlay(alignment: .top) {
                    if insertAbove {
                        Rectangle()
                            .fill(theme.accent)
                            .frame(height: 2)
                            .padding(.horizontal, 12)
                            .padding(.top, 12)
                    }
                }
                .overlay(alignment: .bottom) {
                    if insertBelow {
                        Rectangle()
                            .fill(theme.accent)
                            .frame(height: 2)
                            .padding(.horizontal, 12)
                    }
                }
            }
            if notes.isEmpty && subfolders.isEmpty {
                emptyHint
            }
        }
        .padding(.bottom, 12)
    }

    private func noteDragGesture(note: NoteNode, idx: Int) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .onChanged { val in
                if dragNote == nil {
                    dragNote = note
                    dragNoteStartIdx = idx
                    dragNoteTargetIdx = idx
                }
                dragNoteTranslation = val.translation.height
                let delta = Int((dragNoteTranslation / noteItemHeight).rounded())
                dragNoteTargetIdx = max(0, min(notes.count - 1, dragNoteStartIdx + delta))
            }
            .onEnded { _ in
                let from = dragNoteStartIdx
                let to = dragNoteTargetIdx
                if from != to {
                    store.reorderNotes(in: folder.url, from: IndexSet([from]), to: to > from ? to + 1 : to, current: notes)
                }
                dragNote = nil
                dragNoteTranslation = 0
                dragNoteTargetIdx = 0
            }
    }

    private var emptyHint: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(theme.accent.opacity(0.4))
            Text("노트를 추가하세요")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

