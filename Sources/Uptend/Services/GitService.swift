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
    var hasUpstream: Bool = true
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

    /// Adiciona uma pasta ao monitoramento (usado depois de clonar um repo).
    func addPath(_ path: String) {
        guard !storedPaths.contains(path) else { return }
        storedPaths.append(path)
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
                           ahead: parsed.ahead, behind: parsed.behind, dirty: parsed.dirty,
                           hasUpstream: parsed.hasUpstream, error: nil)
    }

    /// Lista os arquivos alterados (staged, modificados, novos, removidos) de um repo.
    func changedFiles(_ path: String) async -> [GitFileChange] {
        let result = await Shell.capture(gitPath, ["-C", path, "status", "--porcelain"], env: Shell.brewEnv)
        guard result.ok else { return [] }
        return Self.parseChangedFiles(result.stdout)
    }

    // MARK: Ações

    /// Ambiente do git com autenticação por token (se a conta do GitHub estiver conectada).
    private var authEnv: [String: String] { GitAuth.env(token: GitAuth.currentToken()) }

    func pull(_ path: String) async {
        await runGit(path, ["-C", path, "pull"])
        ActionLog.shared.record("Git pull: \(URL(fileURLWithPath: path).lastPathComponent)")
    }
    func push(_ path: String) async {
        await pushCurrent(path)
        ActionLog.shared.record("Git push: \(URL(fileURLWithPath: path).lastPathComponent)")
    }
    func fetch(_ path: String) async { await runGit(path, ["-C", path, "fetch"]) }

    func fetchAll() async {
        for path in storedPaths { await runGit(path, ["-C", path, "fetch"]) }
    }

    /// Faz `add -A` + `commit` + `push` num passo só — o fluxo amigável de "enviar alterações".
    /// Devolve `true` se enviou com sucesso.
    @discardableResult
    func commitAndPush(_ path: String, message: String) async -> Bool {
        guard InputValidator.isSafeCommitMessage(message) else {
            lastError = "Escreva uma mensagem para descrever as alterações."
            return false
        }
        busyPath = path
        lastError = nil
        defer { busyPath = nil }
        let name = URL(fileURLWithPath: path).lastPathComponent

        // 1) Prepara todas as mudanças.
        let add = await Shell.capture(gitPath, ["-C", path, "add", "-A"], env: Shell.brewEnv)
        guard add.ok else {
            lastError = "\(name): não foi possível preparar as alterações. " + add.stderr.trimmed
            await refresh(path)
            return false
        }
        // 2) Commit.
        let commit = await Shell.capture(gitPath, ["-C", path, "commit", "-m", message], env: Shell.brewEnv)
        if !commit.ok {
            let out = (commit.stdout + commit.stderr)
            if out.contains("nothing to commit") {
                lastError = "\(name): não há alterações para enviar."
            } else {
                lastError = "\(name): falha no commit. " + commit.stderr.trimmed
            }
            await refresh(path)
            return false
        }
        // 3) Push (define upstream automaticamente na primeira vez).
        let ok = await pushCurrent(path)
        if ok {
            ActionLog.shared.record("Git commit+push: \(name) — \(message.prefix(60))")
        }
        return ok
    }

    /// Push do branch atual. Se ainda não há upstream, usa `-u origin HEAD`.
    @discardableResult
    private func pushCurrent(_ path: String) async -> Bool {
        let info = repos.first(where: { $0.path == path })
        let args: [String]
        if let info, info.isRepo, info.hasUpstream == false {
            args = ["-C", path, "push", "-u", "origin", "HEAD"]
        } else {
            args = ["-C", path, "push"]
        }
        return await runGit(path, args, authenticated: true)
    }

    @discardableResult
    private func runGit(_ path: String, _ args: [String], authenticated: Bool = false) async -> Bool {
        busyPath = path
        lastError = nil
        let result = await Shell.capture(gitPath, args, env: authenticated ? authEnv : Shell.brewEnv)
        if !result.ok {
            let message = result.stderr.isEmpty ? result.stdout : result.stderr
            let name = URL(fileURLWithPath: path).lastPathComponent
            lastError = "\(name): " + message.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        await refresh(path)
        busyPath = nil
        return result.ok
    }

    // MARK: Parsing (puro, testável)

    /// Lê a saída de `git status --porcelain=v2 --branch`.
    nonisolated static func parseStatus(_ output: String) -> (branch: String, ahead: Int, behind: Int, dirty: Bool, hasUpstream: Bool) {
        var branch = "—"
        var ahead = 0
        var behind = 0
        var dirty = false
        var hasUpstream = false

        for raw in output.split(whereSeparator: \.isNewline) {
            let line = String(raw)
            if line.hasPrefix("# branch.head ") {
                branch = String(line.dropFirst("# branch.head ".count))
            } else if line.hasPrefix("# branch.upstream ") {
                hasUpstream = true
            } else if line.hasPrefix("# branch.ab ") {
                for part in line.dropFirst("# branch.ab ".count).split(separator: " ") {
                    if part.hasPrefix("+") { ahead = Int(part.dropFirst()) ?? 0 }
                    else if part.hasPrefix("-") { behind = Int(part.dropFirst()) ?? 0 }
                }
            } else if !line.hasPrefix("#") && !line.isEmpty {
                dirty = true
            }
        }
        return (branch, ahead, behind, dirty, hasUpstream)
    }

    /// Lê a saída de `git status --porcelain` (v1) e devolve os arquivos alterados.
    /// Cada linha é `XY <caminho>` (renomeações vêm como `R  antigo -> novo`).
    nonisolated static func parseChangedFiles(_ output: String) -> [GitFileChange] {
        var files: [GitFileChange] = []
        for raw in output.split(whereSeparator: \.isNewline) {
            let line = String(raw)
            guard line.count > 3 else { continue }
            let code = String(line.prefix(2))
            var path = String(line.dropFirst(3))
            if let range = path.range(of: " -> ") {  // renomeação: mostra o destino
                path = String(path[range.upperBound...])
            }
            files.append(GitFileChange(code: code, path: path))
        }
        return files
    }
}

/// Um arquivo alterado num repositório, com um rótulo amigável do tipo de mudança.
struct GitFileChange: Identifiable, Hashable {
    let code: String   // XY do porcelain (ex.: " M", "??", "A ", "D ")
    let path: String
    var id: String { code + path }

    var label: String {
        let c = code.trimmingCharacters(in: .whitespaces)
        if code == "??" { return "novo" }
        if c.contains("D") { return "removido" }
        if c.contains("A") { return "adicionado" }
        if c.contains("R") { return "renomeado" }
        if c.contains("M") { return "modificado" }
        return "alterado"
    }

    var systemImage: String {
        switch label {
        case "novo", "adicionado": "plus.circle"
        case "removido": "minus.circle"
        case "renomeado": "arrow.triangle.branch"
        default: "pencil.circle"
        }
    }
}

extension String {
    /// Versão sem espaços/quebras nas pontas — usada só para montar mensagens de erro.
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
