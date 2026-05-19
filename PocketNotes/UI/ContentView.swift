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
