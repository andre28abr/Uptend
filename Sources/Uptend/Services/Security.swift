import Foundation

/// Validação de entradas antes de virarem argumentos de comandos externos.
///
/// Mesmo executando via `Process` com array de argumentos (sem shell, portanto
/// sem interpolação e sem risco de injeção pelo shell), validamos os valores como
/// defesa em profundidade — Security by Design. Se amanhã a origem do valor mudar
/// (busca, entrada do usuário, arquivo importado), a barreira já está no lugar.
///
/// Nota: os padrões proíbem o primeiro caractere `-` para evitar "option injection"
/// (um valor como `--force` seria interpretado como opção, não como operando) e o
/// `..` para evitar path traversal — em todos os validadores de nome/token/caminho.
enum InputValidator {

    /// Um token de Homebrew válido: letras, números e os separadores usados por
    /// fórmulas e casks (`@`, `.`, `_`, `+`, `-`). Sem espaços, sem metacaracteres,
    /// sem começar com `-`.
    static let brewTokenPattern = "^[A-Za-z0-9@._+][A-Za-z0-9@._+-]*$"

    static func isValidBrewToken(_ token: String) -> Bool {
        guard !token.isEmpty, token.count <= 128, !token.contains("..") else { return false }
        return token.range(of: brewTokenPattern, options: .regularExpression) != nil
    }

    /// Nome de container Docker (para `--name`): começa com alfanumérico, depois
    /// `_ . -`. Mais estrito que `isValidDockerName` (que aceita `/ : @` de refs de
    /// imagem) — o Docker recusa `/ : @` em nomes de container.
    static let containerNamePattern = "^[A-Za-z0-9][A-Za-z0-9_.-]*$"

    static func isValidContainerName(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 128, !name.contains("..") else { return false }
        return name.range(of: containerNamePattern, options: .regularExpression) != nil
    }

    /// Consulta de busca: letras, números, espaço e separadores comuns. Até 64 chars,
    /// sem começar com `-`.
    static let searchQueryPattern = "^[A-Za-z0-9][A-Za-z0-9 ._+-]*$"

    static func isValidSearchQuery(_ query: String) -> Bool {
        guard !query.isEmpty, query.count <= 64 else { return false }
        return query.range(of: searchQueryPattern, options: .regularExpression) != nil
    }

    /// Nome usado dentro de um script AppleScript. Bloqueia aspas, barras e quebras
    /// de linha, que poderiam escapar do literal de string e virar código.
    static func isSafeAppleScriptText(_ text: String) -> Bool {
        guard !text.isEmpty, text.count <= 256 else { return false }
        let forbidden = CharacterSet(charactersIn: "\"\\\n\r")
        return text.rangeOfCharacter(from: forbidden) == nil
    }

    /// Argumento genérico (ex.: ID/nome do Docker): sem espaços, controles, nem começar com `-`.
    /// Como passamos via `Process` (sem shell), isto é defesa em profundidade.
    static func isSafeArgument(_ text: String) -> Bool {
        guard !text.isEmpty, text.count <= 256, !text.hasPrefix("-") else { return false }
        return text.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
    }

    /// Host para ping/dig: letras, números, ponto e hífen, começando por alfanumérico.
    static let hostPattern = "^[A-Za-z0-9][A-Za-z0-9.-]*$"

    static func isValidHost(_ host: String) -> Bool {
        guard !host.isEmpty, host.count <= 253 else { return false }
        return host.range(of: hostPattern, options: .regularExpression) != nil
    }

    /// Nome de arquivo simples (sem separadores de caminho, sem começar com `-`), ex.: chave SSH.
    static let fileNamePattern = "^[A-Za-z0-9._][A-Za-z0-9._-]*$"

    static func isValidFileName(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 64, !name.contains(".."), name != "." else { return false }
        return name.range(of: fileNamePattern, options: .regularExpression) != nil
    }

    /// Bundle identifier (reverse-DNS). Sem `/` nem `..`, para não permitir path traversal
    /// ao montar caminhos de arquivos residuais a partir dele.
    static let bundleIDPattern = "^[A-Za-z0-9][A-Za-z0-9.-]*$"

    static func isValidBundleID(_ id: String) -> Bool {
        guard !id.isEmpty, id.count <= 256, !id.contains("..") else { return false }
        return id.range(of: bundleIDPattern, options: .regularExpression) != nil
    }

    /// Caminho absoluto no servidor (para navegar/transferir arquivos). Deve começar
    /// com `/` e não conter metacaracteres de shell nem globs — bloqueia injeção mesmo
    /// no `scp` (que não passa pelo aspeamento do SSHRunner). Espaços são permitidos.
    static func isSafeRemotePath(_ path: String) -> Bool {
        guard !path.isEmpty, path.count <= 4096, path.hasPrefix("/"), !path.contains("\0") else { return false }
        let forbidden = CharacterSet(charactersIn: ";|&$`\"'\\\n\r<>*?")
        return path.rangeOfCharacter(from: forbidden) == nil
    }

    /// Nome de unidade systemd (ex.: `docker.service`, `getty@tty1.service`): letras,
    /// dígitos e `@ . _ : -`. Sem espaços nem metacaracteres.
    static let serviceNamePattern = "^[A-Za-z0-9@._:][A-Za-z0-9@._:-]*$"

    static func isValidServiceName(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 128, !name.contains("..") else { return false }
        return name.range(of: serviceNamePattern, options: .regularExpression) != nil
    }

    /// Nome/ref de Docker (container, imagem `repo:tag`, id, volume): alfanumérico e
    /// os separadores usados por refs (`_ . : / @ -`), sem espaços nem metacaracteres de
    /// shell, começando por alfanumérico. Defesa em profundidade (o ssh usa shell remoto).
    static let dockerNamePattern = "^[A-Za-z0-9][A-Za-z0-9_.:/@-]*$"

    static func isValidDockerName(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 200, !name.contains("..") else { return false }
        return name.range(of: dockerNamePattern, options: .regularExpression) != nil
    }

    /// Nome de usuário Unix/Linux (para o `ssh -l`): minúsculas, dígitos, `_` e `-`,
    /// começando por letra ou `_`, até 32 caracteres. Padrão POSIX conservador.
    static let unixUserPattern = "^[a-z_][a-z0-9_-]{0,31}$"

    static func isValidUnixUser(_ user: String) -> Bool {
        user.range(of: unixUserPattern, options: .regularExpression) != nil
    }

    /// Nome de banco de dados (Postgres/MySQL): alfanumérico com `_ . -`, começando
    /// por alfanumérico/underscore. Bloqueia aspas/`;`/espaço/`$`/backtick — defesa
    /// em profundidade (o coletor já passa o nome como argumento de conexão, não no SQL).
    static let databaseNamePattern = "^[A-Za-z0-9_][A-Za-z0-9_.-]{0,62}$"

    static func isValidDatabaseName(_ name: String) -> Bool {
        name.range(of: databaseNamePattern, options: .regularExpression) != nil
    }

    /// Bastion/ProxyJump ("[user@]host[:porta]"): só caracteres seguros de um destino
    /// SSH — bloqueia espaço/aspas/`;`/`$`/backtick. Vai como token único do `ssh -J`.
    static let jumpHostPattern = "^[A-Za-z0-9][A-Za-z0-9._@:-]{0,127}$"

    static func isValidJumpHost(_ value: String) -> Bool {
        value.range(of: jumpHostPattern, options: .regularExpression) != nil
    }

    /// Nome de usuário/organização do GitHub: alfanumérico com hífens, começando
    /// por alfanumérico, até 39 caracteres (limite do GitHub). Usado para montar
    /// o caminho da API `/users/<login>/repos`.
    static let gitHubUserPattern = "^[A-Za-z0-9][A-Za-z0-9-]{0,38}$"

    static func isValidGitHubUser(_ login: String) -> Bool {
        login.range(of: gitHubUserPattern, options: .regularExpression) != nil
    }

    /// Token de acesso do GitHub (classic `ghp_…`/`gho_…`/`ghs_…` ou fine-grained
    /// `github_pat_…`). Aceitamos apenas o alfabeto desses tokens — sem espaços,
    /// controles ou aspas — para não colar nada estranho no Keychain nem no ambiente.
    static let gitHubTokenPattern = "^[A-Za-z0-9_]+$"

    static func isValidGitHubToken(_ token: String) -> Bool {
        guard token.count >= 20, token.count <= 255 else { return false }
        return token.range(of: gitHubTokenPattern, options: .regularExpression) != nil
    }

    /// `owner/repo` (usado para montar/validar caminhos e URLs de clone). Sem `..`
    /// nem barras extras, para não permitir path traversal ao escolher a pasta destino.
    static let repoFullNamePattern = "^[A-Za-z0-9._][A-Za-z0-9._-]*/[A-Za-z0-9._][A-Za-z0-9._-]*$"

    static func isValidRepoFullName(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 140, !name.contains("..") else { return false }
        return name.range(of: repoFullNamePattern, options: .regularExpression) != nil
    }

    /// Mensagem de commit. Passa como argumento de `git commit -m` (sem shell), então
    /// aqui a checagem é de sanidade: não-vazia, tamanho razoável e sem caractere NUL.
    static func isSafeCommitMessage(_ message: String) -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, message.count <= 2000 else { return false }
        return !message.contains("\0")
    }
}
