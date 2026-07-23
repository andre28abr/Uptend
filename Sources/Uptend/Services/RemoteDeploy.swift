import Foundation

// =============================================================================
// DEPLOY Mac → Servidor — Passo 8 do módulo Servidor
// Envia uma pasta de projeto (com Dockerfile) para o servidor, builda lá e sobe o
// container. Buildar no servidor evita problemas de arquitetura (arm64/x86).
// nome/porta validados; caminhos remotos derivados de valores validados.
// =============================================================================

enum RemoteDeploy {

    static func remoteDir(_ host: RemoteHost, name: String) -> String {
        "/home/\(host.user)/uptend-deploys/\(name)"
    }

    /// Porta no formato "host:container", ambas 1–65535.
    static func isValidPortMapping(_ s: String) -> Bool {
        let parts = s.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let c = Int(parts[1]),
              (1...65535).contains(h), (1...65535).contains(c) else { return false }
        return true
    }

    /// Envia a pasta local para o servidor (scp -r), limpando um deploy anterior de mesmo nome.
    static func transfer(_ host: RemoteHost, localPath: String, name: String) async -> CommandResult {
        guard host.isValid, InputValidator.isValidContainerName(name) else {
            return CommandResult(exitCode: -1, stdout: "", stderr: "Nome inválido.")
        }
        let dir = remoteDir(host, name: name)
        _ = await SSHRunner.run(host, ["bash", "-lc", "mkdir -p /home/\(host.user)/uptend-deploys; rm -rf \(dir)"])
        let spec = "\(host.user)@\(host.address):\(dir)"
        let opts = ["-i", host.expandedKeyPath, "-P", String(host.port),
                    "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "-o", "StrictHostKeyChecking=accept-new", "-r"]
        return await Shell.capture("/usr/bin/scp", opts + [localPath, spec])
    }

    /// Build + run no servidor (streamado). Revalida nome/porta (defesa em profundidade —
    /// a barreira fica dentro da função, não só no caller).
    static func buildRunArgs(_ host: RemoteHost, name: String, port: String) -> [String] {
        guard InputValidator.isValidContainerName(name), port.isEmpty || isValidPortMapping(port) else {
            return ["bash", "-lc", "echo \"Nome ou porta inválidos — deploy cancelado.\" >&2; exit 1"]
        }
        let dir = remoteDir(host, name: name)
        var run = "docker run -d --name \(name) --restart unless-stopped"
        if !port.isEmpty { run += " -p \(port)" }
        run += " \(name)"
        let script = "cd \(dir) && docker build -t \(name) . && docker rm -f \(name) >/dev/null 2>&1; \(run) && echo \"Deploy concluído: \(name)\""
        return ["bash", "-lc", script]
    }
}
