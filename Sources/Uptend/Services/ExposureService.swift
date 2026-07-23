import Foundation

/// Uma porta em escuta detectada pelo `netstat` (superfície de ataque).
struct ListeningPort: Hashable {
    let port: Int
    /// `true` = ouvindo em todas as interfaces (acessível pela rede); `false` = só localhost.
    let exposed: Bool
}

/// Verifica a "superfície de ataque" do Mac sem sudo: firewall, stealth mode e
/// quais serviços de acesso remoto estão ouvindo em portas expostas à rede.
///
/// Tudo por leitura (defensivo): `socketfilterfw` (firewall) e `netstat` (portas).
/// Não fazemos varredura ativa de rede — só olhamos o próprio Mac.
@MainActor
final class ExposureService: ObservableObject {
    @Published var checks: [SecurityCheck] = []
    @Published var otherPorts: [ListeningPort] = []
    @Published var loading = false

    private let firewallTool = "/usr/libexec/ApplicationFirewall/socketfilterfw"
    private let runner: CommandRunning
    init(runner: CommandRunning = LiveCommandRunner()) { self.runner = runner }

    /// Serviços de acesso remoto relevantes, por porta bem conhecida.
    nonisolated static let knownServices: [Int: String] = [
        22: "Login remoto (SSH)",
        5900: "Compartilhamento de Tela",
        445: "Compartilhamento de Arquivos (SMB)",
        139: "Compartilhamento de Arquivos (SMB)",
        548: "Compartilhamento de Arquivos (AFP)",
        3283: "Gerenciamento Remoto (ARD)",
        5988: "Gerenciamento Remoto (ARD)",
        631: "Compartilhamento de Impressora",
    ]

    func refresh() async {
        loading = true
        defer { loading = false }
        var result: [SecurityCheck] = []

        // Firewall
        let global = await runner.capture(firewallTool, ["--getglobalstate"])
        let firewallOn = global.stdout.contains("State = 1") || global.stdout.lowercased().contains("enabled")
        result.append(SecurityCheck(
            name: "Firewall do aplicativo",
            detail: firewallOn ? "Ativado" : "Desativado — recomendável ligar",
            status: firewallOn ? .ok : .warning))

        // Stealth mode
        let stealth = await runner.capture(firewallTool, ["--getstealthmode"])
        let stealthOn = stealth.stdout.lowercased().contains("on")
        result.append(SecurityCheck(
            name: "Modo invisível (stealth)",
            detail: stealthOn ? "Ativado — não responde a pings" : "Desativado — o Mac responde a sondagens",
            status: stealthOn ? .ok : .warning))

        // Portas em escuta
        let netstat = await runner.capture("/usr/sbin/netstat", ["-an", "-p", "tcp"])
        let ports = Self.parseListening(netstat.stdout)

        // Um check por serviço de acesso remoto conhecido.
        result.append(contentsOf: Self.serviceChecks(from: ports))

        // Demais portas expostas à rede (fora os serviços conhecidos) — informativo.
        let knownPorts = Set(Self.knownServices.keys)
        otherPorts = ports
            .filter { $0.exposed && !knownPorts.contains($0.port) }
            .sorted { $0.port < $1.port }

        checks = result
    }

    // MARK: Lógica pura (testável)

    /// Interpreta a saída de `netstat -an -p tcp`, extraindo portas em LISTEN.
    nonisolated static func parseListening(_ output: String) -> [ListeningPort] {
        var seen: [Int: Bool] = [:]   // port -> exposed (true vence)
        for line in output.split(whereSeparator: \.isNewline) {
            guard line.uppercased().contains("LISTEN") else { continue }
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            guard fields.count >= 4 else { continue }
            let local = String(fields[3])   // ex.: "*.22", "127.0.0.1.5432", "::1.631"
            guard let dot = local.lastIndex(of: "."),
                  let port = Int(local[local.index(after: dot)...]) else { continue }
            let host = String(local[..<dot])
            let exposed = host == "*" || host == "0.0.0.0" || host == "::"
            seen[port] = (seen[port] ?? false) || exposed
        }
        return seen.map { ListeningPort(port: $0.key, exposed: $0.value) }
    }

    /// Monta um check por serviço remoto conhecido, com base nas portas em escuta.
    nonisolated static func serviceChecks(from ports: [ListeningPort]) -> [SecurityCheck] {
        // Agrupa portas por nome de serviço (SMB/AFP compartilham "Arquivos").
        var byName: [String: [ListeningPort]] = [:]
        for port in ports {
            guard let name = knownServices[port.port] else { continue }
            byName[name, default: []].append(port)
        }
        // Preserva uma ordem estável e amigável.
        let order = ["Login remoto (SSH)", "Compartilhamento de Tela",
                     "Compartilhamento de Arquivos (SMB)", "Compartilhamento de Arquivos (AFP)",
                     "Gerenciamento Remoto (ARD)", "Compartilhamento de Impressora"]
        var checks: [SecurityCheck] = []
        for name in order {
            guard let matches = byName[name] else {
                checks.append(SecurityCheck(name: name, detail: "Desligado", status: .ok))
                continue
            }
            if matches.contains(where: { $0.exposed }) {
                checks.append(SecurityCheck(name: name, detail: "Ligado e exposto à rede", status: .warning))
            } else {
                checks.append(SecurityCheck(name: name, detail: "Ativo, mas só local", status: .ok))
            }
        }
        return checks
    }
}
