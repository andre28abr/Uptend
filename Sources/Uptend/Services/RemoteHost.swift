import Foundation

// =============================================================================
// FUNDAÇÃO DO HOMELAB — Passo 1
// Modelo de host remoto, armazenamento e execução de comandos via SSH.
// Segurança (PADROES): autenticação só por chave (nunca senha), argumentos via
// Process (sem shell no lado do Mac), entradas validadas por InputValidator.
// =============================================================================

/// Um servidor remoto (HomeLab ou Servidor Linux) que o Uptend gerencia por SSH.
/// Guarda só metadados — a chave privada fica no disco (~/.ssh), referenciada pelo caminho.
struct RemoteHost: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var kind: HostKind
    var address: String        // IP ou hostname
    var user: String           // usuário Linux (ssh -l)
    var port: Int = 22
    var keyPath: String        // caminho da chave privada (ex.: ~/.ssh/uptend_ed25519)
    var db: DBCredential? = nil // credencial de banco (opcional) — senha fica no Keychain
    var jumpHost: String = ""  // bastion/ProxyJump opcional: "user@bastion" ou "user@bastion:porta"

    /// Válido para virar argumento de comando: campos bem-formados, sem metacaracteres.
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && InputValidator.isValidHost(address)
            && InputValidator.isValidUnixUser(user)
            && (1...65535).contains(port)
            && !keyPath.isEmpty && !keyPath.contains("..") && !keyPath.hasPrefix("-")
            && (jumpHost.isEmpty || InputValidator.isValidJumpHost(jumpHost))   // B7
    }

    /// Caminho da chave com `~` expandido para o home do usuário.
    var expandedKeyPath: String { (keyPath as NSString).expandingTildeInPath }
}

/// Credencial de um serviço de banco (v1: PostgreSQL). Só metadados — a SENHA nunca
/// mora aqui; fica no Keychain (ver `DBCredentialStore`).
struct DBCredential: Codable, Hashable {
    var kind: String = "postgres"   // v1: só PostgreSQL
    var user: String
    var host: String = "localhost"  // do ponto de vista do servidor auditado
    var port: Int = 5432
    var database: String = ""        // vazio = tenta todos os bancos não-template

    var isValid: Bool {
        InputValidator.isValidUnixUser(user) && InputValidator.isValidHost(host) && (1...65535).contains(port)
            && (database.isEmpty || InputValidator.isValidDatabaseName(database))
    }
}

/// Guarda/lê a SENHA do banco de um host no Keychain (nunca em UserDefaults/arquivo/log).
enum DBCredentialStore {
    private static let service = "uptend.db.postgres"
    static func setPassword(_ pw: String, for host: RemoteHost) { Keychain.set(pw, service: service, account: host.id.uuidString) }
    static func password(for host: RemoteHost) -> String? { Keychain.get(service: service, account: host.id.uuidString) }
    @discardableResult static func clear(for host: RemoteHost) -> Bool { Keychain.delete(service: service, account: host.id.uuidString) }
}

/// Lista de hosts adicionados, persistida localmente (UserDefaults — só metadados).
@MainActor
final class HostStore: ObservableObject {
    @Published private(set) var hosts: [RemoteHost] = []

    private let key = "uptend.hosts"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hosts = Self.decode(defaults.data(forKey: key))
    }

    func hosts(of kind: HostKind) -> [RemoteHost] { hosts.filter { $0.kind == kind } }

    @discardableResult
    func add(_ host: RemoteHost) -> Bool {
        guard host.isValid else { return false }
        hosts.append(host)
        save()
        return true
    }

    func remove(_ host: RemoteHost) {
        hosts.removeAll { $0.id == host.id }
        // Remove também a senha do banco no Keychain (senão ficaria órfã). (B2)
        DBCredentialStore.clear(for: host)
        save()
    }

    private func save() { defaults.set(Self.encode(hosts), forKey: key) }

    nonisolated static func encode(_ list: [RemoteHost]) -> Data {
        (try? JSONEncoder().encode(list)) ?? Data()
    }
    nonisolated static func decode(_ data: Data?) -> [RemoteHost] {
        guard let data, let list = try? JSONDecoder().decode([RemoteHost].self, from: data) else { return [] }
        return list.filter { $0.isValid }
    }
}

/// Executa comandos num host remoto via `ssh` (Process + args, sem shell no Mac).
///
/// Nota de segurança: o `ssh` monta o comando no shell do LADO REMOTO. Por isso cada
/// argumento é envolvido em aspas simples (`shellQuote`) antes de ser enviado — assim o
/// shell remoto trata cada um como um token literal (tabs/espaços/metacaracteres não
/// quebram nem são interpretados). Somado à validação de entradas (InputValidator), é
/// defesa em profundidade contra injeção no lado remoto.
enum SSHRunner {

    /// Envolve um argumento em aspas simples para o shell remoto (escapa aspas internas).
    static func shellQuote(_ arg: String) -> String {
        "'" + arg.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Opções do `ssh` para um host + o comando remoto já montado.
    private static func options(_ host: RemoteHost, remoteCommand: String) -> [String] {
        var opts: [String] = [
            "-i", host.expandedKeyPath,
            "-l", host.user,
            "-p", String(host.port),
            "-o", "BatchMode=yes",              // nunca pede senha interativa
            "-o", "ConnectTimeout=8",
            "-o", "StrictHostKeyChecking=accept-new",  // TODO Passo 2: confirmar fingerprint
        ]
        // Bastion / ProxyJump (rede privada via servidor-ponte)
        let jump = host.jumpHost.trimmingCharacters(in: .whitespaces)
        if !jump.isEmpty { opts += ["-J", jump] }
        opts += [host.address, remoteCommand]
        return opts
    }

    /// Roda `remoteArgs` no host e devolve a saída. `stdin` (opcional) é transmitido
    /// ao comando remoto — use-o para segredos, que assim não entram no argv/cmdline.
    static func run(_ host: RemoteHost, _ remoteArgs: [String], stdin: String? = nil) async -> CommandResult {
        guard host.isValid else {
            return CommandResult(exitCode: -1, stdout: "", stderr: "Host inválido.")
        }
        let cmd = remoteArgs.map(shellQuote).joined(separator: " ")
        return await Shell.capture("/usr/bin/ssh", options(host, remoteCommand: cmd), stdin: stdin)
    }

    /// Roda `remoteArgs` transmitindo a saída ao vivo (para deploys/instalações longas).
    static func stream(_ host: RemoteHost, _ remoteArgs: [String],
                       onOutput: @escaping @Sendable (String) -> Void) async -> Int32 {
        guard host.isValid else { onOutput("Host inválido.\n"); return -1 }
        let cmd = remoteArgs.map(shellQuote).joined(separator: " ")
        return await Shell.stream("/usr/bin/ssh", options(host, remoteCommand: cmd), onOutput: onOutput)
    }

    /// Testa a conexão: roda `uname -a` e devolve (ok, mensagem).
    static func test(_ host: RemoteHost) async -> (ok: Bool, message: String) {
        let r = await run(host, ["uname", "-sr"])
        if r.ok { return (true, r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)) }
        let err = (r.stderr.isEmpty ? r.stdout : r.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
        return (false, err.isEmpty ? "Falha na conexão." : err)
    }
}
