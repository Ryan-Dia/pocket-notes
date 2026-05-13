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

extension NoteNode: Hashable {
    static func == (lhs: NoteNode, rhs: NoteNode) -> Bool { lhs.url == rhs.url }
    func hash(into hasher: inout Hasher) { hasher.combine(url) }
}
