import Foundation

struct Connection: Identifiable, Hashable {
    var id: String { "\(pid)-\(remote)" }
    let command: String
    let pid: String
    let remote: String
}

/// Lista as conexões TCP estabelecidas da máquina (leitura via lsof — só o próprio Mac).
@MainActor
final class ConnectionsService: ObservableObject {
    @Published var connections: [Connection] = []
    @Published var loading = false

    func refresh() async {
        loading = true
        defer { loading = false }
        let out = await Shell.capture("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:ESTABLISHED"])
        connections = Self.parse(out.stdout)
    }

    nonisolated static func parse(_ output: String) -> [Connection] {
        var seen = Set<String>()
        var result: [Connection] = []
        for line in output.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard fields.count >= 9, fields[0] != "COMMAND" else { continue }
            let command = fields[0]
            let pid = fields[1]
            guard pid.allSatisfy(\.isNumber) else { continue }
            guard let name = fields.first(where: { $0.contains("->") }),
                  let remote = name.components(separatedBy: "->").last, !remote.isEmpty else { continue }
            let key = "\(pid)-\(remote)"
            if seen.insert(key).inserted {
                result.append(Connection(command: command, pid: pid, remote: remote))
            }
        }
        return result.sorted { $0.command.lowercased() < $1.command.lowercased() }
    }
}
