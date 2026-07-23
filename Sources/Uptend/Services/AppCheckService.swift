import Foundation

enum TrustLevel: Sendable { case trusted, caution, danger }

/// Veredito de segurança de um app: assinatura, notarização, Gatekeeper e quarentena.
struct AppVerdict: Sendable {
    let name: String
    let signed: Bool
    let valid: Bool
    let adhoc: Bool
    let authority: String
    let teamID: String
    let notarized: Bool
    let appleSigned: Bool
    let gatekeeperAccepted: Bool
    let gatekeeperSource: String
    let quarantined: Bool

    /// App sem identidade de desenvolvedor (sem assinatura ou só ad-hoc) — típico de
    /// apps próprios ou open-source compilados localmente.
    var selfMadeLike: Bool { !appleSigned && !notarized && (adhoc || !signed || teamID.isEmpty) }

    var level: TrustLevel {
        if !signed || !valid || !gatekeeperAccepted { return .danger }
        if quarantined || (!notarized && !appleSigned) { return .caution }
        return .trusted
    }

    var headline: String {
        switch level {
        case .trusted: return appleSigned ? "App da Apple — confiável" : "Assinado e notarizado — confiável"
        case .caution: return quarantined ? "Baixado da internet — ainda em quarentena" : "Assinado, mas não notarizado"
        case .danger: return signed ? "Assinatura inválida — cuidado" : "Sem assinatura de desenvolvedor"
        }
    }

    /// Explicação amigável para apps próprios/open-source (não é "perigoso" por si só).
    var note: String? {
        guard selfMadeLike else { return nil }
        let base = adhoc || !signed
            ? "Este app não tem assinatura de um desenvolvedor identificado nem notarização da Apple."
            : "Este app é assinado, mas não foi notarizado pela Apple."
        return base + " Isso é normal em apps próprios ou open-source compilados localmente — não significa que seja perigoso. Confie se você conhece a origem (ex.: foi você quem fez)."
    }
}

/// Verifica se um app é seguro de abrir: usa `spctl` (Gatekeeper), `codesign`
/// (assinatura/notarização) e o atributo de quarentena. Tudo leitura, sem sudo.
@MainActor
final class AppCheckService: ObservableObject {
    @Published var checking = false
    @Published var verdict: AppVerdict?
    @Published var lastError: String?
    @Published private(set) var lastPath: String?

    private let runner: CommandRunning
    init(runner: CommandRunning = LiveCommandRunner()) { self.runner = runner }

    func check(path: String) async {
        checking = true
        lastError = nil
        verdict = nil
        lastPath = path
        defer { checking = false }
        guard path.hasPrefix("/"), FileManager.default.fileExists(atPath: path) else {
            lastError = "Caminho inválido."
            return
        }
        let name = URL(fileURLWithPath: path).lastPathComponent

        // Gatekeeper
        let spctl = await runner.capture("/usr/sbin/spctl", ["--assess", "--type", "execute", "-vv", path])
        let gk = Self.parseSpctl(spctl.stdout + spctl.stderr)

        // Assinatura (identidade)
        let info = await runner.capture("/usr/bin/codesign", ["-dv", "--verbose=4", path])
        let signed = info.exitCode == 0
        let sign = Self.parseCodesign(info.stdout + info.stderr)
        let adhoc = (info.stdout + info.stderr).contains("Signature=adhoc")

        // Assinatura válida (íntegra)
        let verify = await runner.capture("/usr/bin/codesign", ["--verify", "--deep", "--strict", path])
        let valid = verify.exitCode == 0

        // Quarentena (baixado e ainda não aprovado)
        let quar = await runner.capture("/usr/bin/xattr", ["-p", "com.apple.quarantine", path])
        let quarantined = quar.exitCode == 0 && !quar.stdout.trimmed.isEmpty

        let source = gk.source.lowercased()
        verdict = AppVerdict(
            name: name, signed: signed, valid: valid, adhoc: adhoc,
            authority: sign.authority, teamID: sign.teamID,
            notarized: source.contains("notarized"),
            appleSigned: source.contains("apple"),
            gatekeeperAccepted: gk.accepted, gatekeeperSource: gk.source,
            quarantined: quarantined)
        ActionLog.shared.record("Verificação de app: \(name)")
    }

    /// Confia num app localmente removendo o selo de quarentena (`com.apple.quarantine`).
    /// Legítimo para apps próprios/open-source que você conhece. Reverifica ao final.
    func trustLocally(path: String) async {
        let r = await runner.capture("/usr/bin/xattr", ["-dr", "com.apple.quarantine", path])
        if !r.ok && !r.stderr.isEmpty {
            lastError = "Não foi possível remover a quarentena: " + r.stderr.trimmed
        } else {
            ActionLog.shared.record("App confiado localmente: \(URL(fileURLWithPath: path).lastPathComponent)")
        }
        await check(path: path)
    }

    // MARK: Parsers puros (testáveis)

    /// Lê a saída de `spctl --assess -vv`: aceito? e a fonte (source=…).
    nonisolated static func parseSpctl(_ output: String) -> (accepted: Bool, source: String) {
        var accepted = false
        var source = ""
        for raw in output.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasSuffix(": accepted") || line == "accepted" { accepted = true }
            if line.hasPrefix("source=") { source = String(line.dropFirst("source=".count)) }
        }
        return (accepted, source)
    }

    /// Lê a saída de `codesign -dv --verbose=4`: primeira autoridade e Team ID.
    nonisolated static func parseCodesign(_ output: String) -> (authority: String, teamID: String) {
        var authority = ""
        var teamID = ""
        for raw in output.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if authority.isEmpty, line.hasPrefix("Authority=") {
                authority = String(line.dropFirst("Authority=".count))
            }
            if line.hasPrefix("TeamIdentifier=") {
                let t = String(line.dropFirst("TeamIdentifier=".count))
                teamID = t == "not set" ? "" : t
            }
        }
        return (authority, teamID)
    }
}
