import Foundation
import SwiftUI

/// Pacote desatualizado, vindo de `brew outdated --json=v2`.
struct OutdatedItem: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let installed: String
    let latest: String
    let isCask: Bool
}

/// Resultado de uma busca `brew search`.
struct SearchResult: Identifiable, Hashable {
    var id: String { (isCask ? "cask:" : "formula:") + name }
    let name: String
    let isCask: Bool
}

/// Estrutura para decodificar a saída de `brew outdated --json=v2`.
private struct BrewOutdated: Decodable {
    struct Entry: Decodable {
        let name: String
        let installed_versions: [String]
        let current_version: String
    }
    let formulae: [Entry]
    let casks: [Entry]
}

/// Fala com o Homebrew de verdade: detecta, lista o instalado, o desatualizado,
/// e executa install/uninstall/upgrade mostrando a saída ao vivo.
@MainActor
final class BrewService: ObservableObject {
    @Published var detected = false
    @Published var brewPath = "/opt/homebrew/bin/brew"
    @Published var installedFormulae: Set<String> = []
    @Published var installedCasks: Set<String> = []
    @Published var outdated: [OutdatedItem] = []
    @Published var loading = false

    @Published var searchResults: [SearchResult] = []
    @Published var searching = false

    var installedFormulaeSorted: [String] { installedFormulae.sorted { $0.lowercased() < $1.lowercased() } }
    var installedCasksSorted: [String] { installedCasks.sorted { $0.lowercased() < $1.lowercased() } }

    // Estado da tarefa em execução (para a folha de log).
    @Published var runningTitle: String?
    @Published var runningLog = ""
    @Published var runningBusy = false

    var installedCount: Int { installedFormulae.count + installedCasks.count }

    // MARK: Leitura

    func bootstrap() async {
        await detect()
        if detected { await refreshAll() }
    }

    func detect() async {
        for candidate in ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        where FileManager.default.isExecutableFile(atPath: candidate) {
            brewPath = candidate
            detected = true
            return
        }
        detected = false
    }

    func refreshAll() async {
        loading = true
        await refreshInstalled()
        await refreshOutdated()
        loading = false
    }

    func refreshInstalled() async {
        let formulae = await Shell.capture(brewPath, ["list", "--formula", "-1"], env: Shell.brewEnv)
        let casks = await Shell.capture(brewPath, ["list", "--cask", "-1"], env: Shell.brewEnv)
        installedFormulae = Set(formulae.stdout.split(whereSeparator: \.isNewline).map(String.init))
        installedCasks = Set(casks.stdout.split(whereSeparator: \.isNewline).map(String.init))
    }

    func refreshOutdated() async {
        let result = await Shell.capture(brewPath, ["outdated", "--json=v2"], env: Shell.brewEnv)
        guard let data = result.stdout.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(BrewOutdated.self, from: data) else {
            outdated = []
            return
        }
        let formulae = parsed.formulae.map {
            OutdatedItem(name: $0.name, installed: $0.installed_versions.first ?? "?", latest: $0.current_version, isCask: false)
        }
        let casks = parsed.casks.map {
            OutdatedItem(name: $0.name, installed: $0.installed_versions.first ?? "?", latest: $0.current_version, isCask: true)
        }
        outdated = formulae + casks
    }

    func isInstalled(_ item: AppItem) -> Bool {
        if item.token.isEmpty { return detected } // o próprio Homebrew
        return item.isCask ? installedCasks.contains(item.token) : installedFormulae.contains(item.token)
    }

    func isInstalledToken(_ token: String, isCask: Bool) -> Bool {
        isCask ? installedCasks.contains(token) : installedFormulae.contains(token)
    }

    // MARK: Busca

    func search(_ rawQuery: String) async {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard InputValidator.isValidSearchQuery(query) else {
            searchResults = []
            return
        }
        searching = true
        defer { searching = false }

        let formulae = await Shell.capture(brewPath, ["search", "--formula", query], env: Shell.brewEnv)
        let casks = await Shell.capture(brewPath, ["search", "--cask", query], env: Shell.brewEnv)

        func parse(_ output: String, isCask: Bool) -> [SearchResult] {
            output.split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.hasPrefix("==>") && InputValidator.isValidBrewToken($0) }
                .map { SearchResult(name: $0, isCask: isCask) }
        }

        searchResults = Array((parse(formulae.stdout, isCask: false) + parse(casks.stdout, isCask: true)).prefix(60))
    }

    // MARK: Execução

    private func appendLog(_ text: String) {
        runningLog += text
    }

    /// Roda um comando brew mostrando a saída ao vivo na folha de log.
    private func run(title: String, args: [String]) async {
        runningTitle = title
        runningBusy = true
        runningLog = "$ brew \(args.joined(separator: " "))\n\n"

        let code = await Shell.stream(brewPath, args, env: Shell.brewEnv) { chunk in
            Task { @MainActor in self.appendLog(chunk) }
        }

        runningBusy = false
        appendLog("\n\n== \(code == 0 ? "Concluído" : "Erro (código \(code))") ==\n")
        ActionLog.shared.record("\(title) — \(code == 0 ? "ok" : "erro")")
        await refreshAll()
    }

    // MARK: Perfis (Brewfile)

    func dumpBundle(name: String) async {
        guard InputValidator.isValidFileName(name) else { reportBlocked(name); return }
        let path = ProfilesService.url(forName: name).path
        await run(title: "Exportando perfil \(name)", args: ["bundle", "dump", "--file=" + path, "--force", "--describe"])
    }

    func installBundle(at path: String, profileName: String) async {
        await run(title: "Restaurando perfil \(profileName)", args: ["bundle", "install", "--file=" + path])
    }

    /// Bloqueia a operação e informa, sem executar nada, quando um token não passa na validação.
    private func reportBlocked(_ name: String) {
        runningTitle = "Ação bloqueada"
        runningBusy = false
        runningLog = "Token inválido para \"\(name)\". Operação bloqueada por segurança.\n"
    }

    func install(_ item: AppItem) async {
        guard InputValidator.isValidBrewToken(item.token) else { reportBlocked(item.name); return }
        var args = ["install"]
        if item.isCask { args.append("--cask") }
        args.append(item.token)
        await run(title: "Instalando \(item.name)", args: args)
    }

    func uninstall(_ item: AppItem) async {
        guard InputValidator.isValidBrewToken(item.token) else { reportBlocked(item.name); return }
        var args = ["uninstall"]
        if item.isCask { args.append("--cask") }
        args.append(item.token)
        await run(title: "Removendo \(item.name)", args: args)
    }

    func installMany(_ items: [AppItem]) async {
        let valid = items.filter { !$0.token.isEmpty && InputValidator.isValidBrewToken($0.token) }
        let formulae = valid.filter { !$0.isCask }.map(\.token)
        let casks = valid.filter { $0.isCask }.map(\.token)
        guard !formulae.isEmpty || !casks.isEmpty else { return }

        runningTitle = "Instalando \(items.count) itens"
        runningBusy = true
        runningLog = ""

        if !formulae.isEmpty {
            appendLog("$ brew install \(formulae.joined(separator: " "))\n\n")
            _ = await Shell.stream(brewPath, ["install"] + formulae, env: Shell.brewEnv) { chunk in
                Task { @MainActor in self.appendLog(chunk) }
            }
        }
        if !casks.isEmpty {
            appendLog("\n\n$ brew install --cask \(casks.joined(separator: " "))\n\n")
            _ = await Shell.stream(brewPath, ["install", "--cask"] + casks, env: Shell.brewEnv) { chunk in
                Task { @MainActor in self.appendLog(chunk) }
            }
        }

        runningBusy = false
        appendLog("\n\n== Concluído ==\n")
        ActionLog.shared.record("Instalados \(valid.count) itens essenciais")
        await refreshAll()
    }

    func upgrade(_ item: OutdatedItem) async {
        guard InputValidator.isValidBrewToken(item.name) else { reportBlocked(item.name); return }
        var args = ["upgrade"]
        if item.isCask { args.append("--cask") }
        args.append(item.name)
        await run(title: "Atualizando \(item.name)", args: args)
    }

    func updateAndUpgradeAll() async {
        runningTitle = "Atualizando tudo"
        runningBusy = true
        runningLog = "$ brew update\n\n"

        _ = await Shell.stream(brewPath, ["update"], env: Shell.brewEnv) { chunk in
            Task { @MainActor in self.appendLog(chunk) }
        }
        appendLog("\n\n$ brew upgrade\n\n")
        let code = await Shell.stream(brewPath, ["upgrade"], env: Shell.brewEnv) { chunk in
            Task { @MainActor in self.appendLog(chunk) }
        }

        runningBusy = false
        appendLog("\n\n== \(code == 0 ? "Concluído" : "Erro (código \(code))") ==\n")
        ActionLog.shared.record("Atualização geral do Homebrew — \(code == 0 ? "ok" : "erro")")
        await refreshAll()
    }

    /// Instala um pacote a partir de um token (usado pela busca).
    func installToken(_ token: String, isCask: Bool) async {
        guard InputValidator.isValidBrewToken(token) else { reportBlocked(token); return }
        var args = ["install"]
        if isCask { args.append("--cask") }
        args.append(token)
        await run(title: "Instalando \(token)", args: args)
    }

    /// Desinstala um pacote a partir de um token (usado na aba Instalados).
    func uninstallToken(_ token: String, isCask: Bool) async {
        guard InputValidator.isValidBrewToken(token) else { reportBlocked(token); return }
        var args = ["uninstall"]
        if isCask { args.append("--cask") }
        args.append(token)
        await run(title: "Removendo \(token)", args: args)
    }

    // MARK: Manutenção

    func brewUpdate() async { await run(title: "Atualizando o catálogo do Homebrew", args: ["update"]) }
    func brewCleanup() async { await run(title: "Limpando versões antigas", args: ["cleanup", "--prune=all"]) }
    func brewDoctor() async { await run(title: "Diagnóstico do Homebrew", args: ["doctor"]) }

    func dismissRunning() {
        runningTitle = nil
        runningLog = ""
    }
}
