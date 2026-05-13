import SwiftUI

enum PNTheme {
    static let bg      = Color(red: 0.969, green: 0.945, blue: 0.890)
    static let card    = Color(red: 0.984, green: 0.969, blue: 0.937)
    static let accent  = Color(red: 0.753, green: 0.388, blue: 0.314)
    static let heading = Color(red: 0.106, green: 0.313, blue: 0.376)
}

struct ContentView: View {
    @EnvironmentObject var store: NotesStore
    @State private var selectedFolderURL: URL? = nil

    var body: some View {
        ZStack {
            PNTheme.bg.ignoresSafeArea()
            if let url = selectedFolderURL {
                NoteCardsView(folderURL: url) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedFolderURL = nil
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))
            } else {
                FolderListView { folder in
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedFolderURL = folder.url
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .leading),
                    removal: .move(edge: .leading)
                ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.18), value: selectedFolderURL != nil)
    }
}
