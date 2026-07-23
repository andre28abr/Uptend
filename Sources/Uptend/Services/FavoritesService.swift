import Foundation
import AppKit

/// Lista de repositórios favoritos (URLs) para clonar todos de uma vez numa pasta escolhida.
@MainActor
final class FavoritesService: ObservableObject {
    @Published var urls: [String] = []
    @Published var running = false
    @Published var log = ""

    private let key = "uptend.favoriteRepos"

    init() {
        urls = UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    func add(_ url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidRepoURL(trimmed), !urls.contains(trimmed) else { return }
        urls.append(trimmed)
        save()
    }

    func remove(_ url: String) {
        urls.removeAll { $0 == url }
        save()
    }

    func cloneAll() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Clonar aqui"
        panel.message = "Escolha a pasta de destino"
        guard panel.runModal() == .OK, let dest = panel.url else { return }

        running = true
        log = ""
        Task {
            for url in urls where Self.isValidRepoURL(url) {
                log += "$ git clone \(url)\n"
                let out = await Shell.capture("/usr/bin/git", ["-C", dest.path, "clone", url], env: Shell.brewEnv)
                log += (out.stderr.isEmpty ? out.stdout : out.stderr) + "\n"
            }
            log += "\n== Concluído ==\n"
            ActionLog.shared.record("Clonados \(urls.count) repositórios favoritos")
            running = false
        }
    }

    private func save() {
        UserDefaults.standard.set(urls, forKey: key)
    }

    /// URL de repositório: sem espaços, sem começar com `-`, formato https:// ou git@.
    nonisolated static func isValidRepoURL(_ url: String) -> Bool {
        guard !url.isEmpty, url.count <= 512, !url.hasPrefix("-"),
              url.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return false }
        return url.hasPrefix("https://") || url.hasPrefix("git@") || url.hasPrefix("ssh://")
    }
}
