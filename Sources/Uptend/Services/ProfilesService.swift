import Foundation
import AppKit

struct BrewProfile: Identifiable, Hashable {
    var id: String { url.path }
    let name: String
    let url: URL
}

/// Gerencia "perfis" — Brewfiles salvos com a lista de apps/ferramentas do usuário,
/// para reinstalar tudo de uma vez numa próxima formatação (o day-1 setup).
/// A exportação/instalação em si roda via BrewService (brew bundle).
@MainActor
final class ProfilesService: ObservableObject {
    @Published var profiles: [BrewProfile] = []

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Uptend/Profiles")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func url(forName name: String) -> URL {
        directory.appendingPathComponent(name + ".brewfile")
    }

    func load() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: Self.directory, includingPropertiesForKeys: nil)) ?? []
        profiles = files
            .filter { $0.pathExtension == "brewfile" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { BrewProfile(name: $0.deletingPathExtension().lastPathComponent, url: $0) }
    }

    /// Move o perfil para a Lixeira (reversível), em vez de apagar de vez.
    func delete(_ profile: BrewProfile) {
        try? FileManager.default.trashItem(at: profile.url, resultingItemURL: nil)
        load()
    }

    func revealInFinder(_ profile: BrewProfile) {
        NSWorkspace.shared.activateFileViewerSelecting([profile.url])
    }

    // MARK: - Comparação de Brewfile (puro, testável)

    /// Extrai as fórmulas (`brew "x"`) e casks (`cask "y"`) de um Brewfile.
    nonisolated static func parseBrewfile(_ content: String) -> (brews: Set<String>, casks: Set<String>) {
        var brews = Set<String>()
        var casks = Set<String>()
        for line in content.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: "\"")
            guard parts.count >= 2 else { continue }
            if trimmed.hasPrefix("brew \"") { brews.insert(String(parts[1])) }
            else if trimmed.hasPrefix("cask \"") { casks.insert(String(parts[1])) }
        }
        return (brews, casks)
    }
}
