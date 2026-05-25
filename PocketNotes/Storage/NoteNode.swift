import Foundation

final class NoteNode: Identifiable, ObservableObject {
    var id: String { url.path }
    let url: URL
    @Published var name: String
    @Published var children: [NoteNode]?

    var isFolder: Bool { children != nil }

    init(url: URL, name: String, children: [NoteNode]? = nil) {
        self.url = url
        self.name = name
        self.children = children
    }
}

extension NoteNode {
    var totalNoteCount: Int {
        guard let children else { return 0 }
        return children.reduce(0) { sum, child in
            child.isFolder ? sum + child.totalNoteCount : sum + 1
        }
    }
}

extension NoteNode: Hashable {
    static func == (lhs: NoteNode, rhs: NoteNode) -> Bool { lhs.url == rhs.url }
    func hash(into hasher: inout Hasher) { hasher.combine(url) }
}
