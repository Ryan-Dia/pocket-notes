import Foundation

final class NoteNode: Identifiable, ObservableObject {
    let id: UUID
    let url: URL
    @Published var name: String
    @Published var children: [NoteNode]?

    var isFolder: Bool { children != nil }

    init(url: URL, name: String, children: [NoteNode]? = nil) {
        self.id = UUID()
        self.url = url
        self.name = name
        self.children = children
    }
}

extension NoteNode: Hashable {
    static func == (lhs: NoteNode, rhs: NoteNode) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
