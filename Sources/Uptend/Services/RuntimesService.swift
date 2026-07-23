import Foundation

struct RuntimeInfo: Identifiable {
    var id: String { name }
    let name: String
    let current: String
    let manager: String?     // pyenv / rbenv / nil
    let versions: [String]   // versões instaladas (se houver gerenciador com binário)
    let switchable: Bool
}

/// Mostra as versões de runtimes (Node, Python, Ruby) e permite trocar a versão global
/// quando há um gerenciador com binário (pyenv, rbenv). O Node via nvm/fnm depende de
/// função de shell, então ali mostramos apenas a versão atual.
@MainActor
final class RuntimesService: ObservableObject {
    @Published var runtimes: [RuntimeInfo] = []
    @Published var message: String?

    func load() async {
        runtimes = [
            await readOnly(name: "Node", command: ["node", "--version"]),
            await withManager(name: "Python", command: ["python3", "--version"], manager: "pyenv"),
            await withManager(name: "Ruby", command: ["ruby", "--version"], manager: "rbenv"),
        ]
    }

    func setGlobal(runtime: RuntimeInfo, version: String) async {
        guard let manager = runtime.manager, runtime.switchable,
              InputValidator.isSafeArgument(version), let bin = Self.binaryPath(manager) else { return }
        _ = await Shell.capture(bin, ["global", version], env: Shell.brewEnv)
        message = "\(runtime.name): versão global agora é \(version)."
        ActionLog.shared.record("Runtime \(runtime.name) → \(version)")
        await load()
    }

    // MARK: Helpers

    private func currentVersion(_ command: [String]) async -> String {
        let out = await Shell.capture("/usr/bin/env", command, env: Shell.brewEnv)
        return out.ok ? out.stdout.trimmingCharacters(in: .whitespacesAndNewlines) : "não instalado"
    }

    private func readOnly(name: String, command: [String]) async -> RuntimeInfo {
        RuntimeInfo(name: name, current: await currentVersion(command), manager: nil, versions: [], switchable: false)
    }

    private func withManager(name: String, command: [String], manager: String) async -> RuntimeInfo {
        let current = await currentVersion(command)
        guard let bin = Self.binaryPath(manager) else {
            return RuntimeInfo(name: name, current: current, manager: nil, versions: [], switchable: false)
        }
        let list = await Shell.capture(bin, ["versions", "--bare"], env: Shell.brewEnv)
        let versions = list.stdout.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return RuntimeInfo(name: name, current: current, manager: manager, versions: versions, switchable: true)
    }

    nonisolated static func binaryPath(_ name: String) -> String? {
        let dirs = ["/opt/homebrew/bin", "/usr/local/bin",
                    NSHomeDirectory() + "/.pyenv/bin", NSHomeDirectory() + "/.rbenv/bin"]
        for dir in dirs {
            let path = dir + "/" + name
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }
}
