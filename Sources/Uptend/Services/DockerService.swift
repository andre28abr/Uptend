import Foundation

struct DockerContainerInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let image: String
    let status: String
    let running: Bool
}

struct DockerImageInfo: Identifiable, Hashable {
    var id: String { imageID.isEmpty ? repository + ":" + tag : imageID }
    let imageID: String
    let repository: String
    let tag: String
    let size: String
}

struct DockerVolumeInfo: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let driver: String
}

struct DockerNetworkInfo: Identifiable, Hashable {
    var id: String { netID.isEmpty ? name : netID }
    let netID: String
    let name: String
    let driver: String
}

/// Pilota o Docker instalado (OrbStack, Docker Desktop, etc.) por linha de comando,
/// mostrando tudo em interface gráfica. Não substitui o Docker.
@MainActor
final class DockerService: ObservableObject {
    @Published var installed = false
    @Published var daemonRunning = false
    @Published var provider = "Docker"
    @Published var loading = false

    @Published var containers: [DockerContainerInfo] = []
    @Published var images: [DockerImageInfo] = []
    @Published var volumes: [DockerVolumeInfo] = []
    @Published var networks: [DockerNetworkInfo] = []

    private var dockerPath = "/usr/local/bin/docker"
    private var didBootstrap = false

    func bootstrapIfNeeded() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        await reload()
    }

    func reload() async {
        await detect()
        if daemonRunning { await refreshAll() }
    }

    private func detect() async {
        let candidates = [
            "/opt/homebrew/bin/docker",
            "/usr/local/bin/docker",
            "/Applications/Docker.app/Contents/Resources/bin/docker",
        ]
        installed = false
        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            dockerPath = candidate
            installed = true
            break
        }

        provider = FileManager.default.fileExists(atPath: "/Applications/OrbStack.app") ? "OrbStack" : "Docker"

        guard installed else { daemonRunning = false; return }
        let info = await Shell.capture(dockerPath, ["info", "--format", "{{.ServerVersion}}"], env: Shell.brewEnv)
        daemonRunning = info.ok && !info.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func refreshAll() async {
        loading = true
        defer { loading = false }
        containers = Self.parseContainers(await run(["ps", "-a", "--format", "{{json .}}"]))
        images = Self.parseImages(await run(["images", "--format", "{{json .}}"]))
        volumes = Self.parseVolumes(await run(["volume", "ls", "--format", "{{json .}}"]))
        networks = Self.parseNetworks(await run(["network", "ls", "--format", "{{json .}}"]))
    }

    private func run(_ args: [String]) async -> String {
        await Shell.capture(dockerPath, args, env: Shell.brewEnv).stdout
    }

    // MARK: Ações

    func start(_ id: String) async { await action(["start", id]) }
    func stop(_ id: String) async { await action(["stop", id]) }
    func removeContainer(_ id: String) async { await action(["rm", "-f", id]) }
    func removeImage(_ id: String) async { await action(["rmi", id]) }
    func removeVolume(_ name: String) async { await action(["volume", "rm", name]) }

    func logs(_ id: String) async -> String {
        guard InputValidator.isSafeArgument(id) else { return "" }
        let out = await Shell.capture(dockerPath, ["logs", "--tail", "200", id], env: Shell.brewEnv)
        return out.stdout + out.stderr
    }

    private func action(_ args: [String]) async {
        guard args.allSatisfy({ InputValidator.isSafeArgument($0) }) else { return }
        _ = await Shell.capture(dockerPath, args, env: Shell.brewEnv)
        await refreshAll()
    }

    func openApp() {
        Task { _ = await Shell.capture("/usr/bin/open", ["-a", provider]) }
    }

    // MARK: Parsing (puro, testável)

    nonisolated static func decodeLines(_ output: String) -> [[String: String]] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            var dict: [String: String] = [:]
            for (key, value) in obj { dict[key] = value as? String ?? String(describing: value) }
            return dict
        }
    }

    nonisolated static func parseContainers(_ output: String) -> [DockerContainerInfo] {
        decodeLines(output).compactMap { row in
            guard let id = row["ID"], let image = row["Image"] else { return nil }
            let status = row["Status"] ?? ""
            let state = row["State"] ?? ""
            let running = state == "running" || status.hasPrefix("Up")
            return DockerContainerInfo(id: id, name: row["Names"] ?? id, image: image, status: status, running: running)
        }
    }

    nonisolated static func parseImages(_ output: String) -> [DockerImageInfo] {
        decodeLines(output).compactMap { row in
            guard let repo = row["Repository"] else { return nil }
            return DockerImageInfo(imageID: row["ID"] ?? "", repository: repo,
                                   tag: row["Tag"] ?? "latest", size: row["Size"] ?? "—")
        }
    }

    nonisolated static func parseVolumes(_ output: String) -> [DockerVolumeInfo] {
        decodeLines(output).compactMap { row in
            guard let name = row["Name"] else { return nil }
            return DockerVolumeInfo(name: name, driver: row["Driver"] ?? "local")
        }
    }

    nonisolated static func parseNetworks(_ output: String) -> [DockerNetworkInfo] {
        decodeLines(output).compactMap { row in
            guard let name = row["Name"] else { return nil }
            return DockerNetworkInfo(netID: row["ID"] ?? "", name: name, driver: row["Driver"] ?? "—")
        }
    }
}
