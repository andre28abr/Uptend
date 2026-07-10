import Foundation

struct CommandResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    var ok: Bool { exitCode == 0 }
}

/// Executa processos externos (Homebrew, git, etc.). Duas formas:
/// - `capture`: roda até o fim e devolve toda a saída (para comandos rápidos que precisamos parsear).
/// - `stream`: envia a saída em pedaços conforme ela chega (para comandos longos, com log ao vivo).
enum Shell {

    /// Ambiente com PATH apontando para o Homebrew, para que o brew ache git/curl/etc.
    static var brewEnv: [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        env["HOMEBREW_NO_ENV_HINTS"] = "1"
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        return env
    }

    static func capture(_ launchPath: String, _ args: [String], env: [String: String]? = nil) async -> CommandResult {
        await withCheckedContinuation { (cont: CheckedContinuation<CommandResult, Never>) in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: launchPath)
                process.arguments = args
                if let env { process.environment = env }

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                } catch {
                    cont.resume(returning: CommandResult(exitCode: -1, stdout: "", stderr: error.localizedDescription))
                    return
                }

                // Lê as duas saídas concorrentemente para não travar o buffer.
                var outData = Data()
                var errData = Data()
                let group = DispatchGroup()
                group.enter()
                DispatchQueue.global().async {
                    outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }
                group.enter()
                DispatchQueue.global().async {
                    errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }
                process.waitUntilExit()
                group.wait()

                cont.resume(returning: CommandResult(
                    exitCode: process.terminationStatus,
                    stdout: String(data: outData, encoding: .utf8) ?? "",
                    stderr: String(data: errData, encoding: .utf8) ?? ""
                ))
            }
        }
    }

    static func stream(_ launchPath: String, _ args: [String], env: [String: String]? = nil,
                       onOutput: @escaping @Sendable (String) -> Void) async -> Int32 {
        await withCheckedContinuation { (cont: CheckedContinuation<Int32, Never>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: launchPath)
            process.arguments = args
            if let env { process.environment = env }

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            let handle = pipe.fileHandleForReading
            handle.readabilityHandler = { fh in
                let data = fh.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                onOutput(text)
            }

            process.terminationHandler = { proc in
                handle.readabilityHandler = nil
                cont.resume(returning: proc.terminationStatus)
            }

            do {
                try process.run()
            } catch {
                handle.readabilityHandler = nil
                cont.resume(returning: -1)
            }
        }
    }
}
