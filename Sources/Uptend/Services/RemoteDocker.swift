import Foundation

// =============================================================================
// DOCKER REMOTO — Passo 1 do módulo Servidor
// Lista e gerencia containers/imagens/volumes num host Linux via SSH.
// Verbos são constantes (código); só o NOME é dinâmico e passa por InputValidator.
// =============================================================================

struct RemoteContainer: Identifiable, Hashable {
    let name: String
    let state: String      // running / exited / created / paused
    let status: String     // "Up 2 hours", "Exited (0) 3 min ago"…
    let image: String
    let ports: String
    var id: String { name }
    var isRunning: Bool { state == "running" }
}

struct RemoteImage: Identifiable, Hashable {
    let repoTag: String
    let size: String
    let imageID: String
    var id: String { imageID }
}

struct RemoteVolume: Identifiable, Hashable {
    let name: String
    let driver: String
    var id: String { name }
}

enum RemoteDocker {

    enum ContainerAction {
        case start, stop, restart, remove
        var args: [String] {
            switch self {
            case .start: ["start"]
            case .stop: ["stop"]
            case .restart: ["restart"]
            case .remove: ["rm", "-f"]
            }
        }
    }

    // MARK: Listagem

    static func containers(_ host: RemoteHost) async -> (items: [RemoteContainer], error: String?) {
        let fmt = "{{.Names}}\t{{.State}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}"
        let r = await SSHRunner.run(host, ["docker", "ps", "-a", "--format", fmt])
        guard r.ok else {
            let e = (r.stderr.isEmpty ? r.stdout : r.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
            return ([], e.isEmpty ? "Não foi possível listar os containers." : e)
        }
        return (parseContainers(r.stdout), nil)
    }

    static func images(_ host: RemoteHost) async -> [RemoteImage] {
        let r = await SSHRunner.run(host, ["docker", "images", "--format", "{{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.ID}}"])
        return parseImages(r.stdout)
    }

    static func volumes(_ host: RemoteHost) async -> [RemoteVolume] {
        let r = await SSHRunner.run(host, ["docker", "volume", "ls", "--format", "{{.Name}}\t{{.Driver}}"])
        return parseVolumes(r.stdout)
    }

    // MARK: Ações

    static func container(_ host: RemoteHost, _ action: ContainerAction, _ name: String) async -> CommandResult {
        guard InputValidator.isValidDockerName(name) else {
            return CommandResult(exitCode: -1, stdout: "", stderr: "Nome de container inválido.")
        }
        return await SSHRunner.run(host, ["docker"] + action.args + [name])
    }

    static func logs(_ host: RemoteHost, _ name: String, tail: Int = 200) async -> String {
        guard InputValidator.isValidDockerName(name) else { return "Nome de container inválido." }
        let r = await SSHRunner.run(host, ["docker", "logs", "--tail", String(tail), name])
        let out = r.stdout + (r.stderr.isEmpty ? "" : "\n" + r.stderr)
        return out.isEmpty ? "(sem logs)" : out
    }

    static func removeImage(_ host: RemoteHost, _ id: String) async -> CommandResult {
        guard InputValidator.isValidDockerName(id) else {
            return CommandResult(exitCode: -1, stdout: "", stderr: "Id de imagem inválido.")
        }
        return await SSHRunner.run(host, ["docker", "rmi", id])
    }

    static func removeVolume(_ host: RemoteHost, _ name: String) async -> CommandResult {
        guard InputValidator.isValidDockerName(name) else {
            return CommandResult(exitCode: -1, stdout: "", stderr: "Nome de volume inválido.")
        }
        return await SSHRunner.run(host, ["docker", "volume", "rm", name])
    }

    // MARK: Parsers (puros, testáveis)

    static func parseContainers(_ output: String) -> [RemoteContainer] {
        output.split(whereSeparator: \.isNewline).compactMap { raw in
            let f = raw.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 4, !f[0].isEmpty else { return nil }
            return RemoteContainer(name: f[0], state: f[1], status: f[2], image: f[3],
                                   ports: f.count > 4 ? f[4] : "")
        }
    }

    static func parseImages(_ output: String) -> [RemoteImage] {
        output.split(whereSeparator: \.isNewline).compactMap { raw in
            let f = raw.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 3, !f[2].isEmpty else { return nil }
            return RemoteImage(repoTag: f[0], size: f[1], imageID: f[2])
        }
    }

    static func parseVolumes(_ output: String) -> [RemoteVolume] {
        output.split(whereSeparator: \.isNewline).compactMap { raw in
            let f = raw.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 2, !f[0].isEmpty else { return nil }
            return RemoteVolume(name: f[0], driver: f[1])
        }
    }
}
