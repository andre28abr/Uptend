import Foundation

/// Um item de recomendação do Lynis, com o ID do teste preservado para explicar
/// em português a que categoria ele se refere.
public struct LynisFinding: Identifiable, Hashable {
    public let testID: String
    public let text: String
    public init(testID: String, text: String) { self.testID = testID; self.text = text }
    public var id: String { testID + "|" + text }
    /// Categoria em português, derivada do prefixo do ID (ex.: "SSH-7408" → "SSH").
    public var category: String { ScannerHelp.lynisCategory(testID) }
}

/// Traduz/explica em português as saídas das ferramentas OSS de segurança.
/// As ferramentas emitem texto técnico em inglês; aqui damos contexto amigável do
/// que cada achado significa e o que fazer — sem depender de tradução online.
public enum ScannerHelp {

    // MARK: gitleaks — tipo de segredo por RuleID

    /// Nome amigável do tipo de segredo a partir do RuleID do gitleaks.
    public static func gitleaksRule(_ ruleID: String) -> String {
        let id = ruleID.lowercased()
        let map: [(String, String)] = [
            ("aws", "Chave de acesso da AWS"),
            ("github", "Token do GitHub"),
            ("gitlab", "Token do GitLab"),
            ("private-key", "Chave privada (SSH/PGP/TLS)"),
            ("private_key", "Chave privada (SSH/PGP/TLS)"),
            ("rsa", "Chave privada"),
            ("ssh", "Chave privada SSH"),
            ("slack", "Token do Slack"),
            ("google", "Chave do Google/GCP"),
            ("gcp", "Chave do Google Cloud"),
            ("stripe", "Chave da Stripe"),
            ("openai", "Chave da OpenAI"),
            ("anthropic", "Chave da Anthropic"),
            ("twilio", "Token do Twilio"),
            ("sendgrid", "Chave do SendGrid"),
            ("jwt", "Token JWT"),
            ("npm", "Token do npm"),
            ("heroku", "Chave da Heroku"),
            ("facebook", "Token do Facebook"),
            ("telegram", "Token do Telegram"),
            ("password", "Senha embutida no código"),
            ("generic", "Segredo/chave genérica de API"),
        ]
        for (needle, label) in map where id.contains(needle) { return label }
        return "Possível segredo"
    }

    /// Explicação geral de por que segredos no código são um risco e como resolver.
    public static let gitleaksFixHint =
        "Segredos no código (mesmo em commits antigos) podem ser usados por terceiros. " +
        "Remova do código, gere uma nova credencial (rotacione) e limpe do histórico do Git."

    // MARK: Lynis — categoria por prefixo do ID

    /// Explica em português a categoria de uma recomendação do Lynis pelo prefixo do ID.
    public static func lynisCategory(_ testID: String) -> String {
        let prefix = testID.split(separator: "-").first.map(String.init)?.uppercased() ?? ""
        let map: [String: String] = [
            "SSH": "Servidor/acesso SSH",
            "AUTH": "Autenticação e senhas",
            "ACCT": "Contabilização de processos",
            "FIRE": "Firewall",
            "NETW": "Rede",
            "KRNL": "Kernel",
            "FILE": "Arquivos e permissões",
            "STRG": "Armazenamento e dispositivos",
            "USB": "Dispositivos USB",
            "BOOT": "Inicialização do sistema",
            "HRDN": "Endurecimento geral",
            "MALW": "Antivírus / malware",
            "LOGG": "Logs e auditoria",
            "TIME": "Sincronização de horário (NTP)",
            "CRYP": "Criptografia e certificados",
            "PHP": "Serviços web (PHP)",
            "HTTP": "Servidor web",
            "SSL": "Certificados TLS/SSL",
            "PKGS": "Pacotes e atualizações",
            "PROC": "Processos",
            "HOME": "Pastas de usuário",
        ]
        return map[prefix] ?? "Recomendação de segurança"
    }

    // MARK: osv-scanner — ação sugerida

    /// Sugestão em português para uma vulnerabilidade de dependência.
    public static func osvActionHint(package: String) -> String {
        "Vulnerabilidade conhecida em \(package). Atualize para uma versão corrigida da dependência."
    }
}
