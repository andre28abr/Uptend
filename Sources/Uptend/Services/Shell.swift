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

    /// Procura um binário nos diretórios comuns do Homebrew/sistema (bin e sbin).
    nonisolated static func binaryPath(_ name: String) -> String? {
        let dirs = [
            "/opt/homebrew/bin", "/opt/homebrew/sbin",
            "/usr/local/bin", "/usr/local/sbin",
            "/usr/bin", "/bin", "/usr/sbin", "/sbin",
        ]
        for dir in dirs {
            let path = dir + "/" + name
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }

    static func capture(_ launchPath: String, _ args: [String], env: [String: String]? = nil,
                        stdin: String? = nil) async -> CommandResult {
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
                // stdin usado para passar segredos SEM que apareçam no argv/cmdline
                // (world-readable em /proc). Escrevemos e fechamos logo após o run.
                let inPipe: Pipe? = stdin != nil ? Pipe() : nil
                if let inPipe { process.standardInput = inPipe }

                do {
                    try process.run()
                } catch {
                    cont.resume(returning: CommandResult(exitCode: -1, stdout: "", stderr: error.localizedDescription))
                    return
                }

                // Lê as duas saídas concorrentemente para não travar o buffer.
                // Os leitores começam ANTES da escrita do stdin: se o filho encher
                // o stdout enquanto o stdin ainda está sendo escrito, escrever
                // primeiro bloquearia os dois lados (deadlock de pipe).
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
                if let inPipe, let stdin {
                    group.enter()
                    DispatchQueue.global().async {
                        let h = inPipe.fileHandleForWriting
                        h.write(Data(stdin.utf8))
                        try? h.close()
                        group.leave()
                    }
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
                       onStart: ((Process) -> Void)? = nil,
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
                guard !data.isEmpty else { return }
                // Decode tolerante: se um caractere multibyte for cortado entre chunks,
                // não descarta o pedaço (usa caractere de substituição, raro e cosmético).
                onOutput(String(decoding: data, as: UTF8.self))
            }

            process.terminationHandler = { proc in
                handle.readabilityHandler = nil
                // Drena o que sobrou no pipe (antes isto era perdido — as últimas linhas
                // da saída sumiam do log).
                let remaining = handle.availableData
                if !remaining.isEmpty { onOutput(String(decoding: remaining, as: UTF8.self)) }
                cont.resume(returning: proc.terminationStatus)
            }

            do {
                try process.run()
                onStart?(process)
            } catch {
                handle.readabilityHandler = nil
                cont.resume(returning: -1)
            }
        }
    }
}
