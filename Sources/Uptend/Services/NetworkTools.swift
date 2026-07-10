import Foundation
import Darwin

/// Ferramentas de rede. IP local é lido localmente; IP público exige contatar um
/// serviço externo (por isso é uma ação explícita do usuário — transparência).
enum NetworkTools {

    /// Endereços IPv4 das interfaces ativas (exceto loopback). Sem rede.
    static func localIPv4() -> [(interface: String, ip: String)] {
        var results: [(String, String)] = []
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0 else { return [] }
        defer { freeifaddrs(ifaddrPtr) }

        var pointer = ifaddrPtr
        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            guard let addr = current.pointee.ifa_addr else { continue }

            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING)
            guard isUp, addr.pointee.sa_family == UInt8(AF_INET) else { continue }

            let name = String(cString: current.pointee.ifa_name)
            guard name != "lo0" else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                                     &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            if result == 0 {
                results.append((name, String(cString: host)))
            }
        }
        return results
    }

    /// Descobre o IP público consultando um serviço externo (rede).
    static func publicIP() async -> String? {
        guard let url = URL(string: "https://api.ipify.org") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Ping. O host é validado (letras/números/ponto/hífen).
    static func ping(_ host: String) async -> String {
        guard InputValidator.isValidHost(host) else { return "Host inválido." }
        let out = await Shell.capture("/sbin/ping", ["-c", "3", "-t", "5", host])
        let text = out.stdout.isEmpty ? out.stderr : out.stdout
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Consulta DNS (resolve um host). Host validado.
    static func dnsLookup(_ host: String) async -> String {
        guard InputValidator.isValidHost(host) else { return "Host inválido." }
        let out = await Shell.capture("/usr/bin/dig", ["+short", host])
        let text = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "Sem resposta." : text
    }

    /// Endereço do gateway (roteador) padrão.
    static func gateway() async -> String? {
        let out = await Shell.capture("/sbin/route", ["-n", "get", "default"])
        return parseGateway(out.stdout)
    }

    /// Servidores DNS configurados.
    static func dnsServers() async -> [String] {
        let out = await Shell.capture("/usr/sbin/scutil", ["--dns"])
        return parseDNS(out.stdout)
    }

    /// Endereços MAC por interface (via ifconfig).
    static func macAddresses() async -> [(interface: String, mac: String)] {
        let out = await Shell.capture("/sbin/ifconfig", [])
        return parseMac(out.stdout)
    }

    struct IPInfo: Sendable {
        let ip: String
        let city: String
        let region: String
        let country: String
        let org: String
    }

    /// Info do IP público (provedor/cidade) — consulta serviço externo (rede).
    static func ipInfo() async -> IPInfo? {
        guard let url = URL(string: "https://ipinfo.io/json") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        func value(_ key: String) -> String { (obj[key] as? String) ?? "—" }
        return IPInfo(ip: value("ip"), city: value("city"), region: value("region"),
                      country: value("country"), org: value("org"))
    }

    // MARK: - Parsers (puros, testáveis)

    nonisolated static func parseGateway(_ output: String) -> String? {
        for line in output.split(whereSeparator: \.isNewline) where line.contains("gateway:") {
            return line.components(separatedBy: "gateway:").last?.trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    nonisolated static func parseDNS(_ output: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for line in output.split(whereSeparator: \.isNewline) where line.contains("nameserver[") {
            if let ip = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces),
               !ip.isEmpty, seen.insert(ip).inserted {
                result.append(ip)
            }
        }
        return result
    }

    nonisolated static func parseMac(_ output: String) -> [(interface: String, mac: String)] {
        var result: [(String, String)] = []
        var current = ""
        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if let first = line.first, first != " ", first != "\t", line.contains(":") {
                current = String(line.prefix { $0 != ":" })
            } else if let range = line.range(of: "ether ") {
                let mac = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                if !current.isEmpty && !mac.isEmpty { result.append((current, mac)) }
            }
        }
        return result
    }
}
