import Foundation

struct SSHKey: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let publicKey: String
}

/// Lista chaves SSH públicas e gera novas (ed25519).
@MainActor
final class SSHService: ObservableObject {
    @Published var keys: [SSHKey] = []
    @Published var message: String?

    private var sshDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
    }

    func load() {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: sshDir, includingPropertiesForKeys: nil) else {
            keys = []
            return
        }
        keys = items
            .filter { $0.pathExtension == "pub" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                return SSHKey(name: url.lastPathComponent, publicKey: content.trimmingCharacters(in: .whitespacesAndNewlines))
            }
    }

    /// Gera uma chave ed25519 em ~/.ssh/<name>. Nome e comentário são validados.
    func generate(name: String, comment: String) async {
        guard InputValidator.isValidFileName(name) else { message = "Nome inválido."; return }
        let safeComment = InputValidator.isSafeArgument(comment) ? comment : "uptend"

        let path = sshDir.appendingPathComponent(name).path
        if FileManager.default.fileExists(atPath: path) {
            message = "Já existe uma chave com esse nome."
            return
        }

        let result = await Shell.capture("/usr/bin/ssh-keygen",
                                         ["-t", "ed25519", "-f", path, "-N", "", "-C", safeComment])
        message = result.ok ? "Chave \(name) criada." : "Falha ao criar a chave."
        load()
    }
}
