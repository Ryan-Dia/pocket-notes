import Foundation
import Combine

final class NotesStore: ObservableObject {
    @Published var roots: [NoteNode] = []
    @Published var selectedNode: NoteNode?

    private var watcher: FolderWatcher?

    var rootURL: URL {
        get {
            if let path = UserDefaults.standard.string(forKey: "rootFolderPath") {
                return URL(fileURLWithPath: path)
            }
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            return docs.appendingPathComponent("PocketNotes")
        }
        set {
            UserDefaults.standard.set(newValue.path, forKey: "rootFolderPath")
            reload()
        }
    }

    init() {
        ensureRootExists()
        reload()
        startWatching()
    }

    func reload() {
        roots = loadChildren(at: rootURL)
        startWatching()
    }

    private func ensureRootExists() {
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    private func loadChildren(at url: URL) -> [NoteNode] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { fileURL -> NoteNode? in
                let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                let name = fileURL.deletingPathExtension().lastPathComponent
                if isDir {
                    let children = loadChildren(at: fileURL)
                    return NoteNode(url: fileURL, name: fileURL.lastPathComponent, children: children)
                } else if fileURL.pathExtension == "md" {
                    return NoteNode(url: fileURL, name: name)
                }
                return nil
            }
    }

    // MARK: - CRUD

    func createNote(in folder: NoteNode? = nil, name: String = "새 노트") {
        let parent = folder?.url ?? rootURL
        var target = parent.appendingPathComponent(name + ".md")
        var counter = 1
        while FileManager.default.fileExists(atPath: target.path) {
            target = parent.appendingPathComponent("\(name)-\(counter).md")
            counter += 1
        }
        try? "".write(to: target, atomically: true, encoding: .utf8)
        reload()
        selectNode(withURL: target)
    }

    func createFolder(in parent: NoteNode? = nil, name: String = "새 폴더") {
        let parentURL = parent?.url ?? rootURL
        var target = parentURL.appendingPathComponent(name)
        var counter = 1
        while FileManager.default.fileExists(atPath: target.path) {
            target = parentURL.appendingPathComponent("\(name) \(counter)")
            counter += 1
        }
        try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        reload()
    }

    func delete(_ node: NoteNode) {
        try? FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
        if selectedNode?.id == node.id { selectedNode = nil }
        reload()
    }

    func rename(_ node: NoteNode, to newName: String) {
        let ext = node.isFolder ? "" : ".md"
        let newURL = node.url.deletingLastPathComponent().appendingPathComponent(newName + ext)
        try? FileManager.default.moveItem(at: node.url, to: newURL)
        reload()
    }

    func readContent(of node: NoteNode) -> String {
        (try? String(contentsOf: node.url, encoding: .utf8)) ?? ""
    }

    func saveContent(_ content: String, to node: NoteNode) {
        try? content.write(to: node.url, atomically: true, encoding: .utf8)
    }

    private func selectNode(withURL url: URL) {
        selectedNode = findNode(url: url, in: roots)
    }

    private func findNode(url: URL, in nodes: [NoteNode]) -> NoteNode? {
        for node in nodes {
            if node.url == url { return node }
            if let children = node.children, let found = findNode(url: url, in: children) { return found }
        }
        return nil
    }

    private func startWatching() {
        watcher = FolderWatcher(url: rootURL) { [weak self] in
            DispatchQueue.main.async { self?.reload() }
        }
    }
}
