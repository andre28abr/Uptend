import Foundation

// =============================================================================
// ARQUIVOS DO SERVIDOR (SFTP) — Passo 6 do módulo Servidor
// Navega, cria pasta, apaga e transfere (scp) arquivos entre o Mac e o servidor.
// Caminhos remotos validados por isSafeRemotePath (defesa também no scp, que não
// passa pelo aspeamento do SSHRunner). Apagar é destrutivo → confirmação na UI.
// =============================================================================

struct RemoteFile: Identifiable, Hashable {
    let name: String
    let type: String        // "d" dir, "f" arquivo, "l" link
    let sizeBytes: Int64
    let modified: String
    var id: String { name }
    var isDir: Bool { type == "d" }
    var isLink: Bool { type == "l" }
    var sizeLabel: String { isDir ? "—" : ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file) }
}

enum RemoteFiles {

    static func list(_ host: RemoteHost, _ path: String) async -> (items: [RemoteFile], error: String?) {
        guard InputValidator.isSafeRemotePath(path) else { return ([], "Caminho inválido.") }
        let r = await SSHRunner.run(host, ["find", path, "-maxdepth", "1", "-mindepth", "1",
                                           "-printf", "%y\t%s\t%TY-%Tm-%Td %TH:%TM\t%f\n"])
        if !r.ok && r.stdout.isEmpty {
            let e = (r.stderr.isEmpty ? r.stdout : r.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
            return ([], e.isEmpty ? "Não foi possível abrir a pasta." : e)
        }
        return (parseListing(r.stdout), nil)
    }

    static func makeDir(_ host: RemoteHost, in parent: String, name: String) async -> CommandResult {
        guard InputValidator.isSafeRemotePath(parent), InputValidator.isValidFileName(name) else {
            return CommandResult(exitCode: -1, stdout: "", stderr: "Nome ou caminho inválido.")
        }
        let path = (parent.hasSuffix("/") ? parent : parent + "/") + name
        return await SSHRunner.run(host, ["mkdir", "-p", path])
    }

    static func delete(_ host: RemoteHost, _ path: String) async -> CommandResult {
        guard InputValidator.isSafeRemotePath(path), path != "/" else {
            return CommandResult(exitCode: -1, stdout: "", stderr: "Caminho inválido.")
        }
        return await SSHRunner.run(host, ["rm", "-rf", path])
    }

    // MARK: Transferências (scp)

    private static func scpOptions(_ host: RemoteHost) -> [String] {
        ["-i", host.expandedKeyPath, "-P", String(host.port),
         "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", "-o", "StrictHostKeyChecking=accept-new"]
    }

    static func download(_ host: RemoteHost, _ remotePath: String, to localPath: String) async -> CommandResult {
        guard host.isValid, InputValidator.isSafeRemotePath(remotePath) else {
            return CommandResult(exitCode: -1, stdout: "", stderr: "Caminho remoto inválido.")
        }
        // Aspar o caminho remoto (o scp o expande no shell do servidor): sem isso,
        // um caminho COM ESPAÇO seria quebrado em dois pelo word-splitting. (B8)
        let spec = "\(host.user)@\(host.address):\(SSHRunner.shellQuote(remotePath))"
        return await Shell.capture("/usr/bin/scp", scpOptions(host) + [spec, localPath])
    }

    static func upload(_ host: RemoteHost, _ localPath: String, toDir remoteDir: String) async -> CommandResult {
        guard host.isValid, InputValidator.isSafeRemotePath(remoteDir) else {
            return CommandResult(exitCode: -1, stdout: "", stderr: "Caminho remoto inválido.")
        }
        let dir = remoteDir.hasSuffix("/") ? remoteDir : remoteDir + "/"
        let spec = "\(host.user)@\(host.address):\(SSHRunner.shellQuote(dir))"   // idem B8
        return await Shell.capture("/usr/bin/scp", scpOptions(host) + [localPath, spec])
    }

    // MARK: Parser (puro)

    static func parseListing(_ output: String) -> [RemoteFile] {
        let items = output.split(whereSeparator: \.isNewline).compactMap { raw -> RemoteFile? in
            let f = raw.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false).map(String.init)
            guard f.count == 4, !f[3].isEmpty else { return nil }
            return RemoteFile(name: f[3], type: f[0], sizeBytes: Int64(f[1]) ?? 0, modified: f[2])
        }
        // Pastas primeiro, depois por nome (sem diferenciar caixa).
        return items.sorted { a, b in
            if a.isDir != b.isDir { return a.isDir }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    /// Caminho pai de um caminho absoluto (para o botão "acima").
    static func parent(of path: String) -> String {
        if path == "/" { return "/" }
        let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
        guard let slash = trimmed.lastIndex(of: "/") else { return "/" }
        let p = String(trimmed[..<slash])
        return p.isEmpty ? "/" : p
    }
}
