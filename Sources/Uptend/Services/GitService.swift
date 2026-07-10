import Foundation
import SwiftUI
import AppKit

/// Estado real de um repositório Git monitorado.
struct GitRepoInfo: Identifiable, Hashable {
    var id: String { path }
    let path: String
    let name: String
    var isRepo: Bool
    var branch: String
    var ahead: Int
    var behind: Int
    var dirty: Bool
    var error: String?

    /// Status principal, para o ícone/rótulo (prioridade: alterações > atrás > à frente > ok).
    var status: GitStatus {
        if dirty { return .dirty }
        if behind > 0 { return .behind(behind) }
        if ahead > 0 { return .ahead(ahead) }
        return .synced
    }
}

/// Monitora pastas Git escolhidas pelo usuário e executa status/pull/push/fetch reais.
@MainActor
final class GitService: ObservableObject {
    @Published var repos: [GitRepoInfo] = []
    @Published var scanning = false
    @Published var busyPath: String?
    @Published var lastError: String?

    private let gitPath = "/usr/bin/git"
    private let defaultsKey = "monitoredGitPaths"

    private var storedPaths: [String] {
        get { UserDefaults.standard.stringArray(forKey: defaultsKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    // MARK: Carregar / gerenciar pastas

    func load() async {
        await refreshAll()
    }

    func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Adicionar"
        panel.message = "Escolha pastas de repositórios Git para monitorar"

        guard panel.runModal() == .OK else { return }
        var paths = storedPaths
        for url in panel.urls where !paths.contains(url.path) {
            paths.append(url.path)
        }
        storedPaths = paths
        Task { await refreshAll() }
    }

    func remove(_ path: String) {
        storedPaths = storedPaths.filter { $0 != path }
        repos.removeAll { $0.path == path }
    }

    // MARK: Status

    func refreshAll() async {
        scanning = true
        defer { scanning = false }
        var result: [GitRepoInfo] = []
        for path in storedPaths {
            result.append(await status(for: path))
        }
        repos = result
    }

    private func refresh(_ path: String) async {
        let info = await status(for: path)
        if let index = repos.firstIndex(where: { $0.path == path }) {
            repos[index] = info
        }
    }

    private func status(for path: String) async -> GitRepoInfo {
        let name = URL(fileURLWithPath: path).lastPathComponent
        let result = await Shell.capture(gitPath, ["-C", path, "status", "--porcelain=v2", "--branch"], env: Shell.brewEnv)

        guard result.ok else {
            return GitRepoInfo(path: path, name: name, isRepo: false, branch: "—",
                               ahead: 0, behind: 0, dirty: false,
                               error: "Não é um repositório Git (ou não foi possível ler).")
        }
        let parsed = Self.parseStatus(result.stdout)
        return GitRepoInfo(path: path, name: name, isRepo: true, branch: parsed.branch,
                           ahead: parsed.ahead, behind: parsed.behind, dirty: parsed.dirty, error: nil)
    }

    // MARK: Ações

    func pull(_ path: String) async {
        await runGit(path, ["-C", path, "pull"])
        ActionLog.shared.record("Git pull: \(URL(fileURLWithPath: path).lastPathComponent)")
    }
    func push(_ path: String) async {
        await runGit(path, ["-C", path, "push"])
        ActionLog.shared.record("Git push: \(URL(fileURLWithPath: path).lastPathComponent)")
    }
    func fetch(_ path: String) async { await runGit(path, ["-C", path, "fetch"]) }

    func fetchAll() async {
        for path in storedPaths { await runGit(path, ["-C", path, "fetch"]) }
    }

    private func runGit(_ path: String, _ args: [String]) async {
        busyPath = path
        lastError = nil
        let result = await Shell.capture(gitPath, args, env: Shell.brewEnv)
        if !result.ok {
            let message = result.stderr.isEmpty ? result.stdout : result.stderr
            let name = URL(fileURLWithPath: path).lastPathComponent
            lastError = "\(name): " + message.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        await refresh(path)
        busyPath = nil
    }

    // MARK: Parsing (puro, testável)

    /// Lê a saída de `git status --porcelain=v2 --branch`.
    nonisolated static func parseStatus(_ output: String) -> (branch: String, ahead: Int, behind: Int, dirty: Bool) {
        var branch = "—"
        var ahead = 0
        var behind = 0
        var dirty = false

        for raw in output.split(whereSeparator: \.isNewline) {
            let line = String(raw)
            if line.hasPrefix("# branch.head ") {
                branch = String(line.dropFirst("# branch.head ".count))
            } else if line.hasPrefix("# branch.ab ") {
                for part in line.dropFirst("# branch.ab ".count).split(separator: " ") {
                    if part.hasPrefix("+") { ahead = Int(part.dropFirst()) ?? 0 }
                    else if part.hasPrefix("-") { behind = Int(part.dropFirst()) ?? 0 }
                }
            } else if !line.hasPrefix("#") && !line.isEmpty {
                dirty = true
            }
        }
        return (branch, ahead, behind, dirty)
    }
}
