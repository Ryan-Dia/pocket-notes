import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: NotesStore

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 160, ideal: 220)
        } detail: {
            if let node = store.selectedNode, !node.isFolder {
                EditorView(node: node)
            } else {
                emptyState
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 320, minHeight: 400)
        .background(.regularMaterial)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("노트를 선택하거나 새로 만드세요")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
