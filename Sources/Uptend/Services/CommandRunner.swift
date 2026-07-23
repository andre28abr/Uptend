import Foundation

/// Abstração sobre a execução de processos, para que os serviços recebam um
/// "runner" injetável em vez de chamar `Shell` direto. Assim dá para **mockar** a
/// saída dos comandos nos testes — rápido e determinístico, sem tocar no sistema.
protocol CommandRunning: Sendable {
    func capture(_ launchPath: String, _ args: [String], env: [String: String]?) async -> CommandResult
}

extension CommandRunning {
    func capture(_ launchPath: String, _ args: [String]) async -> CommandResult {
        await capture(launchPath, args, env: nil)
    }
}

/// Implementação real: delega para o `Shell` (Process com args, sem shell).
struct LiveCommandRunner: CommandRunning {
    func capture(_ launchPath: String, _ args: [String], env: [String: String]?) async -> CommandResult {
        await Shell.capture(launchPath, args, env: env)
    }
}

/// Ferramenta de linha de comando opcional (instalada via Homebrew) que o app
/// detecta (gitleaks, lynis, osv-scanner…). Compartilha a lógica de localização.
@MainActor
protocol InstallableTool: AnyObject {
    var toolName: String { get }
}
extension InstallableTool {
    func locate() -> String? { Shell.binaryPath(toolName) }
}
