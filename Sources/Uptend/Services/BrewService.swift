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

/// Resultado de uma busca. `tap` nil = catálogo oficial (core/cask); com `tap`,
/// vem de uma fonte de terceiros (`owner/repo`), e a UI mostra a procedência.
struct SearchResult: Identifiable, Hashable {
    let name: String
    let isCask: Bool
    var tap: String? = nil

    var id: String { (tap ?? "official") + "/" + (isCask ? "cask:" : "formula:") + name }
    var owner: String? { tap.flatMap { $0.split(separator: "/").first.map(String.init) } }
}

/// Detalhes de um pacote (de `brew info --json=v2`), para explicar o que ele é.
struct BrewInfo: Sendable {
    let token: String
    let name: String
    let description: String
    let homepage: String
    let version: String
    let license: String?
    let dependencies: [String]
    let caveats: String?
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
    /// Verdadeiro quando a tarefa falhou por precisar de senha de administrador
    /// (ex.: cask com instalador .pkg). A UI oferece rodar pelo Terminal.
    @Published var needsTerminal = false
    /// Verdadeiro quando o install falhou por a fonte (tap de terceiros) não ser
    /// confiada. A UI oferece "Confiar e instalar" (roda `brew trust`, depois instala).
    @Published var needsTrust = false
    private var lastCommandArgs: [String] = []

    /// Fontes (taps) adicionadas, de `brew tap`.
    @Published var taps: [String] = []
    /// Guardado para o botão "Confiar e instalar": qual tap+fórmula tentar de novo.
    private var pendingTapInstall: (tap: String, formula: String)?

    var installedCount: Int { installedFormulae.count + installedCasks.count }

    // MARK: Leitura

    func bootstrap() async {
        await detect()
        if detected {
            await refreshAll()
            await refreshTaps()
        }
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
    /// Passe `trustTap` quando o comando vier de um tap de terceiros: se falhar por
    /// falta de confiança, a UI oferece confiar naquela fonte e tentar de novo.
    private func run(title: String, args: [String], trustTap: String? = nil) async {
        runningTitle = title
        runningBusy = true
        needsTerminal = false
        needsTrust = false
        lastCommandArgs = args
        runningLog = "$ brew \(args.joined(separator: " "))\n\n"

        let code = await Shell.stream(brewPath, args, env: Shell.brewEnv) { chunk in
            Task { @MainActor in self.appendLog(chunk) }
        }

        runningBusy = false
        if code != 0 && Self.logSuggestsAdmin(runningLog) {
            needsTerminal = true
            appendLog("\n\n== Precisa de senha de administrador ==\nEste app pede autenticação que o Uptend não consegue fornecer sozinho. Use o botão \"Instalar pelo Terminal\".\n")
        } else if code != 0 && trustTap != nil && Self.logSuggestsTrust(runningLog) {
            needsTrust = true
            appendLog("\n\n== Fonte não confiada ==\nEsta é uma fonte de terceiros. Confirme que confia nela para instalar (botão \"Confiar e instalar\").\n")
        } else {
            appendLog("\n\n== \(code == 0 ? "Concluído" : "Erro (código \(code))") ==\n")
        }
        ActionLog.shared.record("\(title) — \(code == 0 ? "ok" : "erro")")
        await refreshAll()
    }

    /// Detecta, pelo log, que o comando falhou por exigir administrador/sudo.
    nonisolated static func logSuggestsAdmin(_ log: String) -> Bool {
        let l = log.lowercased()
        return l.contains("a terminal is required")
            || l.contains("sudo:")
            || l.contains("password is required")
            || l.contains("requires administrator")
            || l.contains("needs the password")
    }

    /// Detecta, pelo log, que o install falhou por a fonte (tap) não ser confiada.
    /// Palavras-chave conservadoras: só dispara o fluxo de confiança quando o
    /// Homebrew realmente pede confiança (versões que exigem `brew trust`).
    nonisolated static func logSuggestsTrust(_ log: String) -> Bool {
        let l = log.lowercased()
        return l.contains("brew trust")
            || l.contains("not trusted")
            || l.contains("untrusted tap")
            || l.contains("is not trusted")
            || l.contains("trust this tap")
    }

    /// Abre o Terminal e executa o último comando brew (lá o usuário digita a senha).
    /// Os argumentos já foram validados por `isValidBrewToken` antes de instalar.
    func openLastInTerminal() {
        // Defesa em profundidade: só prossegue se todos os argumentos forem seguros
        // (tokens brew ou flags conhecidas — nada de espaços/aspas/metacaracteres).
        let safe = lastCommandArgs.allSatisfy {
            $0.range(of: "^--?[A-Za-z0-9]+$|^[A-Za-z0-9@._+-]+$", options: .regularExpression) != nil
        }
        guard safe else { return }
        openInTerminal(command: "brew " + lastCommandArgs.joined(separator: " "))
    }

    /// Abre o Terminal.app e roda um comando. Privado: só o fluxo do brew (acima),
    /// com argumentos já validados, pode chamar — evita virar um sink genérico de shell.
    private func openInTerminal(command: String) {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"Terminal\"\nactivate\ndo script \"\(escaped)\"\nend tell"
        Task { _ = await Shell.capture("/usr/bin/osascript", ["-e", script]) }
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
        needsTerminal = false
        lastCommandArgs = ["upgrade"]
        runningLog = "$ brew update\n\n"

        _ = await Shell.stream(brewPath, ["update"], env: Shell.brewEnv) { chunk in
            Task { @MainActor in self.appendLog(chunk) }
        }
        appendLog("\n\n$ brew upgrade\n\n")
        let code = await Shell.stream(brewPath, ["upgrade"], env: Shell.brewEnv) { chunk in
            Task { @MainActor in self.appendLog(chunk) }
        }

        runningBusy = false
        if code != 0 && Self.logSuggestsAdmin(runningLog) {
            needsTerminal = true
            appendLog("\n\n== Precisa de senha de administrador ==\nAlgum pacote (ex.: um cask com componente de sistema) pede autenticação que o Uptend não consegue fornecer sozinho. Use o botão \"Atualizar pelo Terminal\".\n")
        } else {
            appendLog("\n\n== \(code == 0 ? "Concluído" : "Erro (código \(code))") ==\n")
        }
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

    // MARK: Detalhes de um pacote

    /// Busca a descrição/metadados de um pacote via `brew info --json=v2`.
    func info(token: String, isCask: Bool) async -> BrewInfo? {
        guard InputValidator.isValidBrewToken(token) else { return nil }
        let args = ["info", "--json=v2", isCask ? "--cask" : "--formula", token]
        let result = await Shell.capture(brewPath, args, env: Shell.brewEnv)
        guard let data = result.stdout.data(using: .utf8) else { return nil }
        return Self.parseInfo(data, token: token, isCask: isCask)
    }

    /// Lê a saída JSON de `brew info` (fórmula ou cask). Puro e testável.
    nonisolated static func parseInfo(_ data: Data, token: String, isCask: Bool) -> BrewInfo? {
        struct Root: Decodable { let formulae: [Formula]?; let casks: [Cask]? }
        struct Formula: Decodable {
            let full_name: String?; let desc: String?; let homepage: String?
            let license: String?; let dependencies: [String]?; let caveats: String?
            struct Versions: Decodable { let stable: String? }
            let versions: Versions?
        }
        struct Cask: Decodable {
            let token: String?; let name: [String]?; let desc: String?
            let homepage: String?; let version: String?; let caveats: String?
        }
        guard let root = try? JSONDecoder().decode(Root.self, from: data) else { return nil }
        if isCask, let c = root.casks?.first {
            return BrewInfo(token: c.token ?? token, name: c.name?.first ?? (c.token ?? token),
                            description: c.desc ?? "Sem descrição.", homepage: c.homepage ?? "",
                            version: c.version ?? "—", license: nil, dependencies: [], caveats: c.caveats)
        }
        if !isCask, let f = root.formulae?.first {
            return BrewInfo(token: f.full_name ?? token, name: f.full_name ?? token,
                            description: f.desc ?? "Sem descrição.", homepage: f.homepage ?? "",
                            version: f.versions?.stable ?? "—", license: f.license,
                            dependencies: f.dependencies ?? [], caveats: f.caveats)
        }
        return nil
    }

    // MARK: Apps de fontes de terceiros (para marcar na lista de Aplicativos)

    /// Nome do app (normalizado) → dono da fonte (owner do tap). Preenchido a partir
    /// dos casks de terceiros instalados, para a aba Aplicativos mostrar a procedência.
    @Published var thirdPartyApps: [String: String] = [:]

    /// Descobre quais apps em /Applications vieram de fontes de terceiros. Considera
    /// todo programa da fonte que esteja instalado (cask OU fórmula): casa pelo nome
    /// direto (Peapod.app ↔ peapod) e, para casks, também lê o nome real do `.app`
    /// (que pode diferir do token, ex.: token "peapod-gui" instala "Peapod.app").
    func indexThirdPartyApps(_ programs: [TapProgram]) async {
        var map: [String: String] = [:]
        for program in programs {
            let asCask = installedCasks.contains(program.name)
            let asFormula = installedFormulae.contains(program.name)
            guard asCask || asFormula else { continue }
            // Fallback pelo nome: o app costuma se chamar como o programa.
            map[Self.normalizeAppName(program.name)] = program.owner
            // Se for cask, lê os nomes reais dos apps que ele instala.
            if asCask, InputValidator.isValidBrewToken(program.name) {
                let r = await Shell.capture(brewPath, ["info", "--json=v2", "--cask", program.name], env: Shell.brewEnv)
                if let data = r.stdout.data(using: .utf8) {
                    for appName in Self.parseCaskAppNames(data) {
                        map[Self.normalizeAppName(appName)] = program.owner
                    }
                }
            }
        }
        thirdPartyApps = map
    }

    /// Nome de app normalizado (sem `.app`, minúsculo) — para casar app ↔ cask.
    nonisolated static func normalizeAppName(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: ".app", with: "").trimmingCharacters(in: .whitespaces)
    }

    /// Extrai os nomes dos `.app` de um `brew info --cask --json=v2` (chave `artifacts`).
    nonisolated static func parseCaskAppNames(_ data: Data) -> [String] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let casks = root["casks"] as? [[String: Any]],
              let first = casks.first,
              let artifacts = first["artifacts"] as? [[String: Any]] else { return [] }
        var names: [String] = []
        for artifact in artifacts {
            // Entradas de app: {"app": ["Foo.app", {"target": "..."}]}. Pegamos só as strings.
            if let appList = artifact["app"] as? [Any] {
                for item in appList where item is String {
                    if let s = item as? String { names.append(s) }
                }
            }
        }
        return names
    }

    // MARK: Faxina (dependências órfãs)

    /// Fórmulas que ninguém mais depende ("principais"), de `brew leaves`.
    func leaves() async -> [String] {
        let r = await Shell.capture(brewPath, ["leaves"], env: Shell.brewEnv)
        return r.stdout.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Dependências órfãs que o `brew autoremove` removeria (pré-visualização).
    func autoremovePreview() async -> [String] {
        let r = await Shell.capture(brewPath, ["autoremove", "--dry-run"], env: Shell.brewEnv)
        return Self.parseAutoremove(r.stdout + r.stderr)
    }

    /// Remove de fato as dependências órfãs (mostra o log).
    func runAutoremove() async {
        await run(title: "Removendo dependências órfãs", args: ["autoremove"])
    }

    /// Lê a saída de `brew autoremove --dry-run` (pula cabeçalhos `==>`).
    nonisolated static func parseAutoremove(_ output: String) -> [String] {
        var result: [String] = []
        for raw in output.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("==>"), !line.hasPrefix("Warning") else { continue }
            if line.range(of: "^[A-Za-z0-9@._/+-]+$", options: .regularExpression) != nil {
                result.append(line)
            }
        }
        return result
    }

    // MARK: Manutenção

    func brewUpdate() async { await run(title: "Atualizando o catálogo do Homebrew", args: ["update"]) }
    func brewCleanup() async { await run(title: "Limpando versões antigas", args: ["cleanup", "--prune=all"]) }
    func brewDoctor() async { await run(title: "Diagnóstico do Homebrew", args: ["doctor"]) }

    func dismissRunning() {
        runningTitle = nil
        runningLog = ""
        needsTerminal = false
        needsTrust = false
    }

    // MARK: Fontes (taps de terceiros)

    /// Lista as fontes adicionadas (`brew tap`), em ordem alfabética.
    func refreshTaps() async {
        let r = await Shell.capture(brewPath, ["tap"], env: Shell.brewEnv)
        taps = r.stdout.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .sorted { $0.lowercased() < $1.lowercased() }
    }

    /// Fórmulas e casks que uma fonte oferece (`brew tap-info --json`).
    func tapFormulae(_ tap: String) async -> [String] {
        guard InputValidator.isValidRepoFullName(tap) else { return [] }
        let r = await Shell.capture(brewPath, ["tap-info", "--json", tap], env: Shell.brewEnv)
        return Self.parseTapFormulae(r.stdout)
    }

    /// Lê os nomes de fórmulas/casks de `brew tap-info --json`. Puro e testável.
    nonisolated static func parseTapFormulae(_ json: String) -> [String] {
        struct Entry: Decodable { let formula_names: [String]?; let cask_tokens: [String]? }
        guard let data = json.data(using: .utf8),
              let arr = try? JSONDecoder().decode([Entry].self, from: data),
              let first = arr.first else { return [] }
        // Guarda só o nome "folha" (sem owner/repo), que é o que instalamos qualificado.
        let names = (first.formula_names ?? []) + (first.cask_tokens ?? [])
        return names
            .map { $0.contains("/") ? String($0.split(separator: "/").last ?? "") : $0 }
            .filter { !$0.isEmpty }
            .sorted { $0.lowercased() < $1.lowercased() }
    }

    /// Adiciona uma fonte (`brew tap owner/repo`) — clona o repositório de receitas.
    func addTap(_ name: String) async {
        guard InputValidator.isValidRepoFullName(name) else { reportBlocked(name); return }
        await run(title: "Adicionando fonte \(name)", args: ["tap", name])
        await refreshTaps()
    }

    /// Remove uma fonte (`brew untap owner/repo`).
    func untap(_ name: String) async {
        guard InputValidator.isValidRepoFullName(name) else { reportBlocked(name); return }
        await run(title: "Removendo fonte \(name)", args: ["untap", name])
        await refreshTaps()
    }

    /// Instala uma fórmula de um tap de terceiros. Adiciona o tap se preciso e
    /// instala com o nome totalmente qualificado (`owner/repo/formula`), evitando
    /// ambiguidade com o core. Se a fonte não for confiada, a UI pede confirmação.
    func installFromTap(tap: String, formula: String) async {
        guard InputValidator.isValidRepoFullName(tap) else { reportBlocked(tap); return }
        guard InputValidator.isValidBrewToken(formula) else { reportBlocked(formula); return }
        if !taps.contains(tap) {
            await run(title: "Adicionando fonte \(tap)", args: ["tap", tap])
            await refreshTaps()
        }
        pendingTapInstall = (tap, formula)
        await run(title: "Instalando \(formula)", args: ["install", "\(tap)/\(formula)"], trustTap: tap)
    }

    /// Confia na fonte pendente (`brew trust`) e tenta a instalação de novo.
    func trustAndRetry() async {
        guard let pending = pendingTapInstall,
              InputValidator.isValidRepoFullName(pending.tap),
              InputValidator.isValidBrewToken(pending.formula) else { return }
        needsTrust = false
        await run(title: "Confiando na fonte \(pending.tap)", args: ["trust", pending.tap], trustTap: pending.tap)
        await run(title: "Instalando \(pending.formula)",
                  args: ["install", "\(pending.tap)/\(pending.formula)"], trustTap: pending.tap)
    }
}
