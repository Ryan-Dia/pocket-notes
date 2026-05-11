import Foundation

final class FolderWatcher {
    private var sources: [DispatchSourceFileSystemObject] = []
    private var debounceTimer: DispatchWorkItem?
    private let callback: () -> Void

    init(url: URL, callback: @escaping () -> Void) {
        self.callback = callback
        watch(url: url)
    }

    deinit {
        sources.forEach { $0.cancel() }
    }

    private func watch(url: URL) {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: DispatchQueue.global(qos: .utility)
        )
        source.setEventHandler { [weak self] in self?.scheduleReload() }
        source.setCancelHandler { close(fd) }
        source.resume()
        sources.append(source)

        // 하위 디렉토리도 재귀 감시
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for item in contents {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir { watch(url: item) }
        }
    }

    private func scheduleReload() {
        debounceTimer?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.callback() }
        debounceTimer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }
}
