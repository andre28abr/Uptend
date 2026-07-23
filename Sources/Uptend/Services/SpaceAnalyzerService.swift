import Foundation
import AppKit

struct SpaceItem: Identifiable, Hashable, Sendable {
    var id: String { url.path }
    let name: String
    let url: URL
    let size: Int64
    let isDirectory: Bool
}

/// Mostra o que ocupa espaço numa pasta (tamanho por item), com navegação para dentro.
@MainActor
final class SpaceAnalyzerService: ObservableObject {
    @Published var current: URL = FileManager.default.homeDirectoryForCurrentUser
    @Published var items: [SpaceItem] = []
    @Published var scanning = false

    var total: Int64 { items.reduce(0) { $0 + $1.size } }
    var canGoUp: Bool { current.path != "/" }

    func goHome() {
        current = FileManager.default.homeDirectoryForCurrentUser
        Task { await analyze() }
    }

    func goUp() {
        current = current.deletingLastPathComponent()
        Task { await analyze() }
    }

    func open(_ item: SpaceItem) {
        guard item.isDirectory else { NSWorkspace.shared.activateFileViewerSelecting([item.url]); return }
        current = item.url
        Task { await analyze() }
    }

    func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Analisar"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        current = url
        Task { await analyze() }
    }

    func analyze() async {
        scanning = true
        defer { scanning = false }
        let dir = current
        items = await Task.detached { SpaceAnalyzerService.children(of: dir) }.value
    }

    nonisolated static func children(of dir: URL) -> [SpaceItem] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else { return [] }

        return entries.map { url in
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            return SpaceItem(name: url.lastPathComponent, url: url, size: FileUtils.size(of: url), isDirectory: isDir)
        }.sorted { $0.size > $1.size }
    }
}
