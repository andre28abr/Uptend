import Foundation

// =============================================================================
// BACKUPS (restic) — Passo 8 do módulo Servidor
// Backups com restic (dedup, criptografia, incremental) para um repositório LOCAL
// no servidor. A senha do repositório é gerada NO SERVIDOR e fica num arquivo
// só-root (--password-file) — nunca passa pelo Mac nem pela linha de comando/argv.
// Nuvem (B2/S3) é o próximo incremento (adiciona backend + credenciais no Keychain).
// =============================================================================

struct BackupSnapshot: Identifiable, Hashable {
    let id: String          // short id (ex.: "ec0f35ca")
    let time: String        // "2026-07-16 20:30"
    let paths: [String]
    let sizeLabel: String
}

private struct ResticSnapshotJSON: Decodable {
    let id: String?
    let short_id: String?
    let time: String?
    let paths: [String]?
    struct Summary: Decodable { let total_bytes_processed: Int64? }
    let summary: Summary?
}

enum RemoteBackup {

    static let repo = "/var/backups/uptend-restic"
    static let passFile = "/root/.config/uptend/restic-pass"

    /// (restic instalado?, repositório inicializado?)
    static func status(_ host: RemoteHost) async -> (installed: Bool, initialized: Bool) {
        let r = await SSHRunner.run(host, ["bash", "-lc",
            "command -v restic >/dev/null && echo I=yes || echo I=no; " +
            "sudo -n restic -r \(repo) --password-file \(passFile) cat config >/dev/null 2>&1 && echo R=yes || echo R=no"])
        return (r.stdout.contains("I=yes"), r.stdout.contains("R=yes"))
    }

    static func snapshots(_ host: RemoteHost) async -> [BackupSnapshot] {
        let r = await SSHRunner.run(host, ["sudo", "-n", "restic", "-r", repo, "--password-file", passFile, "snapshots", "--json"])
        return parseSnapshots(r.stdout)
    }

    // Comandos streamados (via RemoteTaskSheet) — scripts fixos, sudo -n.

    static let prepareArgs: [String] = ["bash", "-lc",
        "sudo -n apt-get install -y restic >/dev/null 2>&1 || true; " +
        "sudo -n mkdir -p /root/.config/uptend; " +
        "if ! sudo -n test -f \(passFile); then head -c 24 /dev/urandom | base64 | sudo -n tee \(passFile) >/dev/null; sudo -n chmod 600 \(passFile); fi; " +
        "sudo -n restic -r \(repo) --password-file \(passFile) cat config >/dev/null 2>&1 || sudo -n restic -r \(repo) --password-file \(passFile) init; " +
        "echo \"Repositório de backup pronto.\""]

    /// Argumentos do backup de uma pasta. Revalida `folder` dentro da função (defesa em profundidade).
    static func backupArgs(folder: String) -> [String] {
        guard InputValidator.isSafeRemotePath(folder) else {
            return ["bash", "-lc", "echo \"Caminho inválido.\" >&2; exit 1"]
        }
        return ["bash", "-lc", "sudo -n restic -r \(repo) --password-file \(passFile) backup \"\(folder)\" --tag uptend"]
    }

    /// Restaura um snapshot para `target`. Revalida id (hex) e caminho dentro da função.
    static func restoreArgs(id: String, target: String) -> [String] {
        let idOK = id.range(of: "^[0-9a-fA-F]{6,64}$", options: .regularExpression) != nil
        guard idOK, InputValidator.isSafeRemotePath(target) else {
            return ["bash", "-lc", "echo \"Snapshot ou destino inválido.\" >&2; exit 1"]
        }
        return ["bash", "-lc", "sudo -n mkdir -p \"\(target)\"; sudo -n restic -r \(repo) --password-file \(passFile) restore \(id) --target \"\(target)\""]
    }

    // MARK: Parser puro

    static func parseSnapshots(_ json: String) -> [BackupSnapshot] {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONDecoder().decode([ResticSnapshotJSON].self, from: data) else { return [] }
        let snaps = arr.map { s -> BackupSnapshot in
            let id = s.short_id ?? String((s.id ?? "").prefix(8))
            let time = String((s.time ?? "").replacingOccurrences(of: "T", with: " ").prefix(16))
            let size = s.summary?.total_bytes_processed
                .map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "—"
            return BackupSnapshot(id: id, time: time, paths: s.paths ?? [], sizeLabel: size)
        }
        return snaps.reversed()   // mais recentes primeiro
    }
}
