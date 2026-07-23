import Foundation
import UptendCore

// MARK: - gitleaks (segredos em repositórios)

/// Uma ocorrência de segredo encontrada pelo gitleaks (secret já redigido).
struct SecretFinding: Identifiable, Codable, Hashable {
    let description: String
    let file: String
    let startLine: Int
    let ruleID: String

    var id: String { "\(file):\(startLine):\(ruleID)" }

    enum CodingKeys: String, CodingKey {
        case description = "Description"
        case file = "File"
        case startLine = "StartLine"
        case ruleID = "RuleID"
    }
}

/// Varre pastas de projeto atrás de segredos commitados (chaves de API, tokens,
/// chaves privadas) usando o gitleaks (OSS). Local, sem rede. Os segredos são
/// **redigidos** (`--redact`) — nunca exibimos nem guardamos o valor real.
@MainActor
final class SecretScanService: ObservableObject, InstallableTool {
    var toolName: String { "gitleaks" }
    @Published var installed = false
    @Published var running = false
    @Published var findings: [SecretFinding] = []
    @Published var scannedPath: String?
    @Published var didScan = false
    @Published var lastError: String?

    private var binaryPath: String?

    func detect() {
        binaryPath = locate()
        installed = binaryPath != nil
    }

    /// `includeHistory`: quando `true`, varre também o histórico de commits;
    /// quando `false` (`--no-git`), olha só os arquivos atuais (mais rápido).
    func scan(path: String, includeHistory: Bool = true) async {
        guard let bin = binaryPath else { lastError = "gitleaks não encontrado."; return }
        guard path.hasPrefix("/"), FileManager.default.fileExists(atPath: path) else {
            lastError = "Caminho inválido."; return
        }
        running = true
        lastError = nil
        findings = []
        scannedPath = path
        defer { running = false; didScan = true }

        let report = NSTemporaryDirectory() + "uptend-gitleaks.json"
        try? FileManager.default.removeItem(atPath: report)
        var args = ["detect", "--source", path, "--no-banner", "--redact",
                    "--report-format", "json", "--report-path", report]
        if !includeHistory { args.append("--no-git") }
        let result = await Shell.capture(bin, args, env: Shell.brewEnv)

        if let data = FileManager.default.contents(atPath: report) {
            findings = Self.parseFindings(data)
        } else if result.exitCode != 0 && result.exitCode != 1 {
            // 0 = limpo, 1 = achou segredos; outros = erro real.
            let msg = result.stderr.isEmpty ? result.stdout : result.stderr
            lastError = "Falha ao escanear: " + msg.trimmed
        }
        ActionLog.shared.record("gitleaks: \(URL(fileURLWithPath: path).lastPathComponent) — \(findings.count) achado(s)")
    }

    /// Lê o relatório JSON do gitleaks (array de ocorrências).
    nonisolated static func parseFindings(_ data: Data) -> [SecretFinding] {
        (try? JSONDecoder().decode([SecretFinding].self, from: data)) ?? []
    }
}

// MARK: - Lynis (auditoria de endurecimento)

/// Varre o sistema com o Lynis (OSS) e resume o índice de endurecimento e as
/// recomendações. Local, sem rede. Sem sudo (roda com menos verificações, porém útil).
@MainActor
final class AuditService: ObservableObject, InstallableTool {
    var toolName: String { "lynis" }
    @Published var installed = false
    @Published var running = false
    @Published var hardeningIndex: Int?
    @Published var warnings: [LynisFinding] = []
    @Published var suggestions: [LynisFinding] = []
    @Published var didRun = false
    @Published var lastError: String?

    private var binaryPath: String?

    func detect() {
        binaryPath = locate()
        installed = binaryPath != nil
    }

    func run() async {
        guard let bin = binaryPath else { lastError = "Lynis não encontrado."; return }
        running = true
        lastError = nil
        warnings = []; suggestions = []; hardeningIndex = nil
        defer { running = false; didRun = true }

        let report = NSTemporaryDirectory() + "uptend-lynis.dat"
        let log = NSTemporaryDirectory() + "uptend-lynis.log"
        try? FileManager.default.removeItem(atPath: report)
        let result = await Shell.capture(bin, [
            "audit", "system", "--quick", "--no-colors",
            "--report-file", report, "--logfile", log,
        ], env: Shell.brewEnv)

        if let text = try? String(contentsOfFile: report, encoding: .utf8) {
            let parsed = Self.parseReport(text)
            hardeningIndex = parsed.index
            warnings = parsed.warnings
            suggestions = parsed.suggestions
        } else {
            let msg = result.stderr.isEmpty ? result.stdout : result.stderr
            lastError = "Não foi possível ler o relatório do Lynis. " + msg.trimmed
        }
        ActionLog.shared.record("Lynis: índice \(hardeningIndex.map(String.init) ?? "—")")
    }

    /// Extrai índice de endurecimento, warnings e sugestões do relatório do Lynis.
    nonisolated static func parseReport(_ text: String) -> (index: Int?, warnings: [LynisFinding], suggestions: [LynisFinding]) {
        var index: Int?
        var warnings: [LynisFinding] = []
        var suggestions: [LynisFinding] = []
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = String(raw)
            if line.hasPrefix("hardening_index=") {
                index = Int(line.dropFirst("hardening_index=".count).trimmingCharacters(in: .whitespaces))
            } else if line.hasPrefix("warning[]=") {
                warnings.append(Self.finding(line.dropFirst("warning[]=".count)))
            } else if line.hasPrefix("suggestion[]=") {
                suggestions.append(Self.finding(line.dropFirst("suggestion[]=".count)))
            }
        }
        return (index, warnings, suggestions)
    }

    /// O texto de warning/suggestion vem como `TEST-ID|texto|detalhe|solução`.
    nonisolated private static func finding(_ field: Substring) -> LynisFinding {
        let parts = field.split(separator: "|", omittingEmptySubsequences: false)
        let testID = String(parts.first ?? "").trimmingCharacters(in: .whitespaces)
        let text = parts.count >= 2 && !parts[1].isEmpty ? String(parts[1]) : testID
        return LynisFinding(testID: testID, text: text)
    }
}

// MARK: - osv-scanner (vulnerabilidades de dependências)

/// Uma vulnerabilidade conhecida numa dependência de um projeto.
struct DepVuln: Identifiable, Hashable {
    let vulnID: String
    let package: String
    let version: String
    let ecosystem: String
    let summary: String

    var id: String { "\(ecosystem):\(package):\(version):\(vulnID)" }
}

/// Escaneia as dependências de um projeto contra a base OSV (Google) usando o
/// osv-scanner (OSS). **Faz chamada de rede** à base OSV — ação explícita do usuário.
@MainActor
final class DepsScanService: ObservableObject, InstallableTool {
    var toolName: String { "osv-scanner" }
    @Published var installed = false
    @Published var running = false
    @Published var vulns: [DepVuln] = []
    @Published var scannedPath: String?
    @Published var didScan = false
    @Published var lastError: String?

    private var binaryPath: String?

    func detect() {
        binaryPath = locate()
        installed = binaryPath != nil
    }

    func scan(path: String) async {
        guard let bin = binaryPath else { lastError = "osv-scanner não encontrado."; return }
        guard path.hasPrefix("/"), FileManager.default.fileExists(atPath: path) else {
            lastError = "Caminho inválido."; return
        }
        running = true
        lastError = nil
        vulns = []
        scannedPath = path
        defer { running = false; didScan = true }

        let result = await Shell.capture(bin, ["--format", "json", "--recursive", path], env: Shell.brewEnv)
        let out = result.stdout.trimmed
        if out.hasPrefix("{"), let data = out.data(using: .utf8) {
            vulns = Self.parseVulns(data)
        } else if result.exitCode != 0 && result.exitCode != 1 {
            let msg = result.stderr.isEmpty ? result.stdout : result.stderr
            // osv-scanner reclama quando não acha manifestos de dependência.
            if msg.lowercased().contains("no files") || msg.lowercased().contains("scanned 0") {
                lastError = "Nenhum arquivo de dependências (package-lock, requirements, go.mod…) encontrado nessa pasta."
            } else {
                lastError = "Falha ao escanear: " + msg.trimmed
            }
        }
        ActionLog.shared.record("osv-scanner: \(URL(fileURLWithPath: path).lastPathComponent) — \(vulns.count) vuln(s)")
    }

    /// Interpreta a saída JSON do osv-scanner.
    nonisolated static func parseVulns(_ data: Data) -> [DepVuln] {
        struct Report: Decodable { let results: [Result]? }
        struct Result: Decodable { let packages: [Package]? }
        struct Package: Decodable { let package: Pkg; let vulnerabilities: [Vuln]? }
        struct Pkg: Decodable { let name: String; let version: String; let ecosystem: String }
        struct Vuln: Decodable { let id: String; let summary: String? }

        guard let report = try? JSONDecoder().decode(Report.self, from: data) else { return [] }
        var out: [DepVuln] = []
        for result in report.results ?? [] {
            for pkg in result.packages ?? [] {
                for vuln in pkg.vulnerabilities ?? [] {
                    out.append(DepVuln(vulnID: vuln.id, package: pkg.package.name,
                                       version: pkg.package.version, ecosystem: pkg.package.ecosystem,
                                       summary: vuln.summary ?? ""))
                }
            }
        }
        return out
    }
}
