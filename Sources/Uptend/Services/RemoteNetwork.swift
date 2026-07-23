import Foundation

// =============================================================================
// REDE DO SERVIDOR — Passo 5 do módulo Servidor
// Endereços, portas escutando (ss), e testes de ping/DNS. Alvos de ping/DNS são
// entrada do usuário → validados por InputValidator.isValidHost.
// =============================================================================

struct NetworkInfo: Sendable {
    var ipLocal = "—"
    var gateway = "—"
    var dns: [String] = []
    var hostname = "—"
}

struct RemoteListeningPort: Identifiable, Hashable {
    let address: String
    let port: String
    let process: String
    var id: String { "\(address):\(port)|\(process)" }
    /// Escuta em todas as interfaces (exposto na rede) vs só local.
    var isPublic: Bool { address == "0.0.0.0" || address == "*" || address == "[::]" }
}

enum RemoteNetwork {

    static func info(_ host: RemoteHost) async -> NetworkInfo {
        async let ipC = SSHRunner.run(host, ["hostname", "-I"])
        async let routeC = SSHRunner.run(host, ["bash", "-lc", "ip route | grep default"])
        async let dnsC = SSHRunner.run(host, ["bash", "-lc", "grep \"^nameserver\" /etc/resolv.conf"])
        async let hostC = SSHRunner.run(host, ["hostname"])

        var info = NetworkInfo()
        if let first = (await ipC).stdout.split(separator: " ").first { info.ipLocal = String(first) }
        info.gateway = parseGateway((await routeC).stdout) ?? "—"
        info.dns = (await dnsC).stdout.split(whereSeparator: \.isNewline).compactMap {
            $0.split(separator: " ", omittingEmptySubsequences: true).dropFirst().first.map(String.init)
        }
        let hn = (await hostC).stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !hn.isEmpty { info.hostname = hn }
        return info
    }

    static func ports(_ host: RemoteHost) async -> [RemoteListeningPort] {
        // Com sudo mostra o processo dono; se o sudo falhar (sem senha), cai para
        // `ss -tln` (sem sudo) — mostra as portas mesmo sem o nome do processo.
        let r = await SSHRunner.run(host, ["sudo", "-n", "ss", "-tlnp"])
        let withSudo = r.ok ? parseListening(r.stdout) : []
        if !withSudo.isEmpty { return withSudo }
        let r2 = await SSHRunner.run(host, ["ss", "-tln"])
        return parseListening(r2.stdout)
    }

    static func ping(_ host: RemoteHost, _ target: String) async -> String {
        guard InputValidator.isValidHost(target) else { return "Alvo inválido." }
        let r = await SSHRunner.run(host, ["ping", "-c", "4", "-W", "2", target])
        let out = r.stdout + (r.stderr.isEmpty ? "" : "\n" + r.stderr)
        return out.isEmpty ? "Sem resposta." : out
    }

    static func dnsLookup(_ host: RemoteHost, _ name: String) async -> String {
        guard InputValidator.isValidHost(name) else { return "Nome inválido." }
        let r = await SSHRunner.run(host, ["getent", "hosts", name])
        return r.stdout.isEmpty ? "Não resolveu (sem resposta)." : r.stdout
    }

    // MARK: Parsers puros

    static func parseGateway(_ out: String) -> String? {
        let parts = out.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard let vi = parts.firstIndex(of: "via"), vi + 1 < parts.count else { return nil }
        let ip = parts[vi + 1]
        if let di = parts.firstIndex(of: "dev"), di + 1 < parts.count {
            return "\(ip) (\(parts[di + 1]))"
        }
        return ip
    }

    static func parseListening(_ out: String) -> [RemoteListeningPort] {
        var result: [RemoteListeningPort] = []
        var seen: Set<String> = []
        for raw in out.split(whereSeparator: \.isNewline) {
            let line = String(raw)
            guard line.hasPrefix("LISTEN") else { continue }
            let fields = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard fields.count >= 4 else { continue }
            let local = fields[3]                          // "0.0.0.0:8080" / "[::]:8080" / "127.0.0.1:38891"
            guard let colon = local.lastIndex(of: ":") else { continue }
            let address = String(local[..<colon])
            let port = String(local[local.index(after: colon)...])
            var process = ""
            if let r = line.range(of: "users:((\"") {
                process = String(line[r.upperBound...].prefix { $0 != "\"" })
            }
            let key = "\(port)|\(process)"                 // colapsa duplicatas IPv4/IPv6
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(RemoteListeningPort(address: address, port: port, process: process))
        }
        return result.sorted { (Int($0.port) ?? 0) < (Int($1.port) ?? 0) }
    }
}
