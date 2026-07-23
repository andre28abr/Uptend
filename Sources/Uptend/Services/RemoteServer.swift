import Foundation

// =============================================================================
// SERVIÇOS (systemd) + ATUALIZAÇÕES (apt) — Passo 3 do módulo Servidor
// Leitura sem sudo; ações privilegiadas via `sudo -n` (se falhar por senha, o erro
// é mostrado — nunca guardamos senha). Verbos constantes; nomes validados.
// =============================================================================

// MARK: - systemd

struct ServiceUnit: Identifiable, Hashable {
    let name: String        // "docker.service"
    let active: String      // active / inactive / failed
    let sub: String         // running / exited / dead
    let description: String
    var enabled: Bool
    var id: String { name }
    var isRunning: Bool { sub == "running" }
    var shortName: String { name.hasSuffix(".service") ? String(name.dropLast(8)) : name }
}

enum RemoteSystemd {

    enum Action {
        case start, stop, restart, enable, disable
        var verb: String {
            switch self {
            case .start: "start"; case .stop: "stop"; case .restart: "restart"
            case .enable: "enable"; case .disable: "disable"
            }
        }
    }

    static func services(_ host: RemoteHost) async -> (items: [ServiceUnit], error: String?) {
        async let unitsC = SSHRunner.run(host, ["systemctl", "list-units", "--type=service", "--plain", "--no-legend", "--no-pager"])
        async let filesC = SSHRunner.run(host, ["systemctl", "list-unit-files", "--type=service", "--no-legend", "--no-pager"])
        let units = await unitsC
        guard units.ok else {
            let e = (units.stderr.isEmpty ? units.stdout : units.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
            return ([], e.isEmpty ? "Não foi possível listar os serviços." : e)
        }
        let enabled = parseEnabled((await filesC).stdout)
        return (parseUnits(units.stdout, enabled: enabled), nil)
    }

    static func perform(_ host: RemoteHost, _ action: Action, _ name: String) async -> CommandResult {
        guard InputValidator.isValidServiceName(name) else {
            return CommandResult(exitCode: -1, stdout: "", stderr: "Nome de serviço inválido.")
        }
        return await SSHRunner.run(host, ["sudo", "-n", "systemctl", action.verb, name])
    }

    // Parsers puros

    static func parseUnits(_ output: String, enabled: Set<String>) -> [ServiceUnit] {
        output.split(whereSeparator: \.isNewline).compactMap { raw in
            let parts = raw.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard parts.count >= 4, parts[0].hasSuffix(".service") else { return nil }
            let desc = parts.count > 4 ? parts[4...].joined(separator: " ") : ""
            return ServiceUnit(name: parts[0], active: parts[2], sub: parts[3],
                               description: desc, enabled: enabled.contains(parts[0]))
        }
    }

    static func parseEnabled(_ output: String) -> Set<String> {
        var result: Set<String> = []
        for raw in output.split(whereSeparator: \.isNewline) {
            let parts = raw.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            if parts.count >= 2, parts[1] == "enabled" { result.insert(parts[0]) }
        }
        return result
    }
}

// MARK: - apt (Debian/Ubuntu)

struct AptPackage: Identifiable, Hashable {
    let name: String
    let newVersion: String
    let oldVersion: String
    var id: String { name }
}

enum RemoteApt {

    static func upgradable(_ host: RemoteHost) async -> [AptPackage] {
        let r = await SSHRunner.run(host, ["apt", "list", "--upgradable"])
        return parseUpgradable(r.stdout)
    }

    /// Comandos (streamados) — precisam de sudo. `env DEBIAN_FRONTEND=noninteractive`
    /// evita prompts durante o upgrade.
    static let updateArgs = ["sudo", "-n", "apt-get", "update"]
    static let upgradeArgs = ["sudo", "-n", "env", "DEBIAN_FRONTEND=noninteractive", "apt-get", "-y", "upgrade"]

    static func parseUpgradable(_ output: String) -> [AptPackage] {
        output.split(whereSeparator: \.isNewline).compactMap { raw in
            let line = String(raw)
            guard line.contains("/"), !line.hasPrefix("Listing"),
                  let slash = line.firstIndex(of: "/") else { return nil }
            let name = String(line[..<slash])
            let fields = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard fields.count >= 2 else { return nil }
            let newVersion = fields[1]
            var oldVersion = ""
            if let r = line.range(of: "[upgradable from: "), let end = line.range(of: "]", range: r.upperBound..<line.endIndex) {
                oldVersion = String(line[r.upperBound..<end.lowerBound])
            }
            return AptPackage(name: name, newVersion: newVersion, oldVersion: oldVersion)
        }
    }
}
