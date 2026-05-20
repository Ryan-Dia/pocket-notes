import SwiftUI

enum PNTheme {
    static let bg      = Color(red: 0.969, green: 0.945, blue: 0.890)
    static let card    = Color(red: 0.984, green: 0.969, blue: 0.937)
    static let accent  = Color(red: 0.753, green: 0.388, blue: 0.314)
    static let heading = Color(red: 0.106, green: 0.313, blue: 0.376)
}

struct ContentView: View {
    @EnvironmentObject var store: NotesStore
    @State private var navigationStack: [NoteNode] = []

    var body: some View {
        ZStack {
            PNTheme.bg.ignoresSafeArea()
            currentView
                .id(navigationStack.count)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.18), value: navigationStack.count)
        .onReceive(store.$roots) { _ in
            // store.reload()은 매번 새 NoteNode 인스턴스를 생성하므로
            // 스택의 구 인스턴스를 fresh 인스턴스로 교체해야 children이 갱신됨
            navigationStack = navigationStack.compactMap { store.findFolder(url: $0.url) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pnCreateNote)) { _ in
            guard let folder = navigationStack.last else { return }
            store.createNote(in: folder)
        }
        .onReceive(NotificationCenter.default.publisher(for: .pnCreateFolder)) { _ in
            if navigationStack.isEmpty {
                store.createFolder(in: nil)
            } else if let folder = navigationStack.last, store.depth(of: folder) < 2 {
                store.createFolder(in: folder)
            }
        }
    }

    @ViewBuilder
    private var currentView: some View {
        if navigationStack.isEmpty {
            FolderListView(onSelectFolder: handleSelectFolder)
            .transition(.asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .leading)
            ))
        } else {
            FolderContentsView(
                folder: navigationStack.last!,
                onBack: handleBack,
                onSelectSubfolder: handleSelectSubfolder
            )
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .trailing)
            ))
        }
    }

    private func handleSelectFolder(_ folder: NoteNode) {
        withAnimation(.easeInOut(duration: 0.18)) {
            navigationStack.append(folder)
        }
    }

    private func handleBack() {
        guard !navigationStack.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            navigationStack.removeLast()
        }
    }

    private func handleSelectSubfolder(_ subfolder: NoteNode) {
        withAnimation(.easeInOut(duration: 0.18)) {
            navigationStack.append(subfolder)
        }
    }
}
