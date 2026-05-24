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
            restartWatching()
        }
    }

    init() {
        ensureRootExists()
        reload()
        restartWatching()
    }

    func reload() {
        let previousURL = selectedNode?.url
        roots = loadChildren(at: rootURL)
        if let url = previousURL {
            selectedNode = findNode(url: url, in: roots)
        }
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
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return a > b
            }
            .compactMap { fileURL -> NoteNode? in
                let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if isDir {
                    let children = loadChildren(at: fileURL)
                    return NoteNode(url: fileURL, name: fileURL.lastPathComponent, children: children)
                } else if fileURL.pathExtension == "md" {
                    let name = fileURL.deletingPathExtension().lastPathComponent
                    return NoteNode(url: fileURL, name: name)
                }
                return nil
            }
    }

    // MARK: - Order

    func orderedFolders(_ nodes: [NoteNode], in parentURL: URL) -> [NoteNode] {
        let order = OrderStore.load(for: parentURL)
        return applyOrder(savedNames: order.folders, to: nodes, key: { $0.name })
    }

    func orderedNotes(_ nodes: [NoteNode], in parentURL: URL) -> [NoteNode] {
        let order = OrderStore.load(for: parentURL)
        return applyOrder(savedNames: order.notes, to: nodes, key: { $0.url.lastPathComponent })
    }

    func reorderFolders(in parentURL: URL, from: IndexSet, to: Int, current: [NoteNode]) {
        var names = current.map { $0.name }
        names.move(fromOffsets: from, toOffset: to)
        var order = OrderStore.load(for: parentURL)
        order.folders = names
        OrderStore.save(order, for: parentURL)
        reload()
    }

    func reorderNotes(in parentURL: URL, from: IndexSet, to: Int, current: [NoteNode]) {
        var names = current.map { $0.url.lastPathComponent }
        names.move(fromOffsets: from, toOffset: to)
        var order = OrderStore.load(for: parentURL)
        order.notes = names
        OrderStore.save(order, for: parentURL)
        reload()
    }

    private func applyOrder(savedNames: [String], to nodes: [NoteNode], key: (NoteNode) -> String) -> [NoteNode] {
        let byName = Dictionary(uniqueKeysWithValues: nodes.map { (key($0), $0) })
        let tracked = savedNames.compactMap { byName[$0] }
        let trackedSet = Set(savedNames)
        // 순서 파일에 없는 항목(외부에서 추가된 경우)은 맨 위에 배치
        let untracked = nodes.filter { !trackedSet.contains(key($0)) }
        return untracked + tracked
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
        var order = OrderStore.load(for: parent)
        order.notes.insert(target.lastPathComponent, at: 0)
        OrderStore.save(order, for: parent)
        reload()
        selectedNode = findNode(url: target, in: roots)
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
        var order = OrderStore.load(for: parentURL)
        order.folders.insert(target.lastPathComponent, at: 0)
        OrderStore.save(order, for: parentURL)
        reload()
    }

    func delete(_ node: NoteNode) {
        let parentURL = node.url.deletingLastPathComponent()
        var order = OrderStore.load(for: parentURL)
        if node.isFolder {
            order.folders.removeAll { $0 == node.name }
        } else {
            order.notes.removeAll { $0 == node.url.lastPathComponent }
        }
        OrderStore.save(order, for: parentURL)
        if selectedNode?.url == node.url { selectedNode = nil }
        try? FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
        reload()
    }

    func rename(_ node: NoteNode, to newName: String) {
        let parentURL = node.url.deletingLastPathComponent()
        let ext = node.isFolder ? "" : ".md"
        let newURL = parentURL.appendingPathComponent(newName + ext)
        let oldKey = node.isFolder ? node.name : node.url.lastPathComponent
        let newKey = newName + ext
        var order = OrderStore.load(for: parentURL)
        if node.isFolder {
            if let idx = order.folders.firstIndex(of: oldKey) { order.folders[idx] = newKey }
        } else {
            if let idx = order.notes.firstIndex(of: oldKey) { order.notes[idx] = newKey }
        }
        OrderStore.save(order, for: parentURL)
        try? FileManager.default.moveItem(at: node.url, to: newURL)
        reload()
        if selectedNode?.url == node.url {
            selectedNode = findNode(url: newURL, in: roots)
        }
    }

    func readContent(of node: NoteNode) -> String {
        (try? String(contentsOf: node.url, encoding: .utf8)) ?? ""
    }

    func saveContent(_ content: String, to node: NoteNode) {
        let existing = (try? String(contentsOf: node.url, encoding: .utf8)) ?? ""
        guard existing != content else { return }
        try? content.write(to: node.url, atomically: true, encoding: .utf8)
    }

    func depth(of node: NoteNode) -> Int {
        node.url.pathComponents.count - rootURL.pathComponents.count - 1
    }

    func findFolder(url: URL) -> NoteNode? {
        findNode(url: url, in: roots)
    }

    // MARK: - Private

    private func findNode(url: URL, in nodes: [NoteNode]) -> NoteNode? {
        for node in nodes {
            if node.url == url { return node }
            if let children = node.children, let found = findNode(url: url, in: children) { return found }
        }
        return nil
    }

    private func restartWatching() {
        watcher = FolderWatcher(url: rootURL) { [weak self] in
            DispatchQueue.main.async { self?.reload() }
        }
    }
}
