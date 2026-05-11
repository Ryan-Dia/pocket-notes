import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: NotesStore
    @State private var isRenaming: NoteNode? = nil
    @State private var renameText = ""

    var body: some View {
        List(store.roots, children: \.optionalChildren, selection: $store.selectedNode) { node in
            nodeRow(node)
                .contextMenu { contextMenu(for: node) }
        }
        .listStyle(.sidebar)
        .navigationTitle("PocketNotes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("새 노트") { store.createNote() }
                    Button("새 폴더") { store.createFolder() }
                } label: {
                    Label("추가", systemImage: "plus")
                }
            }
        }
    }

    @ViewBuilder
    private func nodeRow(_ node: NoteNode) -> some View {
        if isRenaming?.id == node.id {
            TextField("이름", text: $renameText)
                .onSubmit { commitRename(node) }
                .onExitCommand { isRenaming = nil }
        } else {
            Label(node.name, systemImage: node.isFolder ? "folder" : "doc.text")
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func contextMenu(for node: NoteNode) -> some View {
        if node.isFolder {
            Button("새 노트") { store.createNote(in: node) }
            Button("새 하위 폴더") { store.createFolder(in: node) }
            Divider()
        }
        Button("이름 변경") { startRename(node) }
        Divider()
        Button("삭제", role: .destructive) { store.delete(node) }
    }

    private func startRename(_ node: NoteNode) {
        renameText = node.name
        isRenaming = node
    }

    private func commitRename(_ node: NoteNode) {
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { store.rename(node, to: trimmed) }
        isRenaming = nil
    }
}

private extension NoteNode {
    var optionalChildren: [NoteNode]? {
        guard let ch = children, !ch.isEmpty else { return nil }
        return ch
    }
}
