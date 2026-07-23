import Foundation

/// Um serviço de fundo gerenciado pelo `brew services` (Postgres, Redis, etc.).
struct BrewServiceItem: Identifiable, Codable, Sendable, Hashable {
    let name: String
    let status: String            // started / stopped / none / error / scheduled
    let file: String?

    var id: String { name }
    var isRunning: Bool { status == "started" || status == "scheduled" }
}

/// Lista e controla os serviços de fundo do Homebrew (`brew services`).
/// Serviços de usuário — não exigem sudo.
@MainActor
final class ServicesService: ObservableObject {
    @Published var services: [BrewServiceItem] = []
    @Published var loading = false
    @Published var busy: String?
    @Published var lastError: String?

    private let brewPath = Shell.binaryPath("brew") ?? "/opt/homebrew/bin/brew"

    func refresh() async {
        loading = true
        defer { loading = false }
        let r = await Shell.capture(brewPath, ["services", "list", "--json"], env: Shell.brewEnv)
        guard let data = r.stdout.data(using: .utf8) else { services = []; return }
        services = Self.parse(data)
    }

    func start(_ name: String) async { await run("start", name) }
    func stop(_ name: String) async { await run("stop", name) }
    func restart(_ name: String) async { await run("restart", name) }

    private func run(_ action: String, _ name: String) async {
        guard InputValidator.isValidBrewToken(name) else { lastError = "Nome de serviço inválido."; return }
        busy = name
        lastError = nil
        defer { busy = nil }
        let r = await Shell.capture(brewPath, ["services", action, name], env: Shell.brewEnv)
        if !r.ok {
            let msg = r.stderr.isEmpty ? r.stdout : r.stderr
            lastError = "\(name): " + msg.trimmed
        }
        await refresh()
    }

    /// Lê a saída JSON de `brew services list --json` (puro, testável).
    nonisolated static func parse(_ data: Data) -> [BrewServiceItem] {
        let items = (try? JSONDecoder().decode([BrewServiceItem].self, from: data)) ?? []
        return items.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
}
