import Foundation

/// Autenticação do git por HTTPS usando o token do GitHub, sem jamais expor o
/// segredo em argumentos de linha de comando nem no `.git/config`.
///
/// Estratégia (padrão do próprio git): um helper `GIT_ASKPASS`. Quando o git
/// precisa de usuário/senha para um remote HTTPS, ele chama o programa apontado
/// por `GIT_ASKPASS` passando o texto do prompt como argumento. Nosso helper é um
/// script FIXO (sem interpolação de dados) que apenas ecoa `x-access-token` para o
/// usuário e o conteúdo da variável de ambiente `UPTEND_GIT_TOKEN` para a senha.
///
/// Por que isto é seguro (Security by Design):
/// - O token vai por **variável de ambiente** do processo filho `git`, não por
///   `argv` (não aparece em `ps`) e não é persistido em disco nem no config.
/// - O helper no disco **não contém segredo** — só a lógica de responder ao prompt.
/// - Não usamos `/bin/sh -c` com interpolação: o script é estático e o `git` é
///   quem o invoca; a expansão de `$UPTEND_GIT_TOKEN` pelo `echo` não reinterpreta
///   o valor como código.
enum GitAuth {
    static let keychainService = "com.andresouza.uptend.github"
    static let keychainAccount = "token"

    /// Token atualmente guardado no Keychain (se o usuário conectou a conta).
    static func currentToken() -> String? {
        Keychain.get(service: keychainService, account: keychainAccount)
    }

    /// Conteúdo fixo do helper de askpass. Sem segredos — lê tudo do ambiente.
    private static let askpassScript = """
    #!/bin/sh
    # Helper de GIT_ASKPASS do Uptend. NÃO contém segredos.
    case "$1" in
      Username*|username*|USERNAME*) printf '%s' "x-access-token" ;;
      *) printf '%s' "$UPTEND_GIT_TOKEN" ;;
    esac
    """

    private static var supportDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Uptend", isDirectory: true)
    }

    /// Garante que o helper existe em disco (executável) e devolve seu caminho.
    private static func askpassPath() -> String? {
        let dir = supportDir
        let url = dir.appendingPathComponent("git-askpass.sh")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let existing = try? String(contentsOf: url, encoding: .utf8)
            if existing != askpassScript {
                try askpassScript.write(to: url, atomically: true, encoding: .utf8)
            }
            // Garante permissão de execução (rwx para o dono, nada para o resto).
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        } catch {
            return nil
        }
        return url.path
    }

    /// Ambiente para rodar `git` autenticado. Se não houver token, devolve só o
    /// ambiente do brew (git usa o que já estiver configurado: SSH, credential helper…).
    static func env(token: String?) -> [String: String] {
        var env = Shell.brewEnv
        guard let token, !token.isEmpty, let helper = askpassPath() else { return env }
        env["GIT_ASKPASS"] = helper
        env["UPTEND_GIT_TOKEN"] = token
        // Evita que o git trave pedindo credencial no terminal se algo falhar.
        env["GIT_TERMINAL_PROMPT"] = "0"
        // Não queremos que um SSH_ASKPASS herdado interfira.
        env.removeValue(forKey: "SSH_ASKPASS")
        return env
    }
}
