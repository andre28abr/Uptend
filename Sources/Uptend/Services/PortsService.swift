import Foundation

struct PortInfo: Identifiable, Hashable {
    var id: String { "\(pid):\(port)" }
    let command: String
    let pid: String
    let port: String
}

/// Lista portas TCP em escuta e permite encerrar o processo dono (sem sudo — processos do usuário).
@MainActor
final class PortsService: ObservableObject {
    @Published var ports: [PortInfo] = []
    @Published var loading = false

    func refresh() async {
        loading = true
        defer { loading = false }
        let out = await Shell.capture("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN"])
        ports = Self.parse(out.stdout)
    }

    func kill(_ pid: String) async {
        guard pid.allSatisfy(\.isNumber), !pid.isEmpty else { return }
        _ = await Shell.capture("/bin/kill", [pid])
        await refresh()
    }

    /// Parser da saída do `lsof`. Puro e testável.
    nonisolated static func parse(_ output: String) -> [PortInfo] {
        var seen = Set<String>()
        var result: [PortInfo] = []

        for line in output.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard fields.count >= 9, fields[0] != "COMMAND" else { continue }

            let command = fields[0]
            let pid = fields[1]
            guard pid.allSatisfy(\.isNumber) else { continue }

            // O endereço (ex.: *:3000, 127.0.0.1:8080, [::1]:5000) é o campo com ":".
            guard let addr = fields.first(where: { $0.contains(":") }),
                  let port = addr.split(separator: ":").last.map(String.init),
                  port.allSatisfy(\.isNumber) else { continue }

            let key = "\(pid):\(port)"
            if seen.insert(key).inserted {
                result.append(PortInfo(command: command, pid: pid, port: port))
            }
        }
        return result.sorted { (Int($0.port) ?? 0) < (Int($1.port) ?? 0) }
    }
}
