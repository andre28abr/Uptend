import Foundation

/// Validação de entradas antes de virarem argumentos de comandos externos.
///
/// Mesmo executando via `Process` com array de argumentos (sem shell, portanto
/// sem interpolação e sem risco de injeção pelo shell), validamos os valores como
/// defesa em profundidade — Security by Design. Se amanhã a origem do valor mudar
/// (busca, entrada do usuário, arquivo importado), a barreira já está no lugar.
///
/// Nota: os padrões proíbem o primeiro caractere `-` para evitar "option injection"
/// (um valor como `--force` seria interpretado como opção, não como operando).
enum InputValidator {

    /// Um token de Homebrew válido: letras, números e os separadores usados por
    /// fórmulas e casks (`@`, `.`, `_`, `+`, `-`). Sem espaços, sem metacaracteres,
    /// sem começar com `-`.
    static let brewTokenPattern = "^[A-Za-z0-9@._+][A-Za-z0-9@._+-]*$"

    static func isValidBrewToken(_ token: String) -> Bool {
        guard !token.isEmpty, token.count <= 128 else { return false }
        return token.range(of: brewTokenPattern, options: .regularExpression) != nil
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
        guard !name.isEmpty, name.count <= 64 else { return false }
        return name.range(of: fileNamePattern, options: .regularExpression) != nil
    }

    /// Bundle identifier (reverse-DNS). Sem `/` nem `..`, para não permitir path traversal
    /// ao montar caminhos de arquivos residuais a partir dele.
    static let bundleIDPattern = "^[A-Za-z0-9][A-Za-z0-9.-]*$"

    static func isValidBundleID(_ id: String) -> Bool {
        guard !id.isEmpty, id.count <= 256, !id.contains("..") else { return false }
        return id.range(of: bundleIDPattern, options: .regularExpression) != nil
    }
}
