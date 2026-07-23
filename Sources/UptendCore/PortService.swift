import Foundation

// =============================================================================
// PORTA → SERVIÇO — o que costuma rodar em cada porta (para leigos e relatório)
// Tabela local (sem rede, sem dependência). Explica em linguagem simples.
// =============================================================================

public enum PortService {

    public struct Info: Sendable {
        public let name: String        // ex.: "HTTPS"
        public let description: String // ex.: "Site/web seguro (com criptografia)"
        public let expectsTLS: Bool    // deveria falar TLS?
    }

    private static let table: [Int: Info] = [
        21:   .init(name: "FTP", description: "Transferência de arquivos (antigo, inseguro)", expectsTLS: false),
        22:   .init(name: "SSH", description: "Acesso remoto ao servidor (terminal)", expectsTLS: false),
        23:   .init(name: "Telnet", description: "Acesso remoto em texto puro (obsoleto/inseguro)", expectsTLS: false),
        25:   .init(name: "SMTP", description: "Envio de e-mail (servidor)", expectsTLS: false),
        53:   .init(name: "DNS", description: "Resolução de nomes de domínio", expectsTLS: false),
        80:   .init(name: "HTTP", description: "Site/web sem criptografia", expectsTLS: false),
        110:  .init(name: "POP3", description: "Recebimento de e-mail", expectsTLS: false),
        143:  .init(name: "IMAP", description: "Leitura de e-mail", expectsTLS: false),
        389:  .init(name: "LDAP", description: "Diretório de usuários (sem criptografia)", expectsTLS: false),
        443:  .init(name: "HTTPS", description: "Site/web seguro (com criptografia)", expectsTLS: true),
        465:  .init(name: "SMTPS", description: "Envio de e-mail com criptografia", expectsTLS: true),
        587:  .init(name: "SMTP (submissão)", description: "Envio de e-mail autenticado", expectsTLS: false),
        636:  .init(name: "LDAPS", description: "Diretório de usuários com criptografia", expectsTLS: true),
        993:  .init(name: "IMAPS", description: "Leitura de e-mail com criptografia", expectsTLS: true),
        995:  .init(name: "POP3S", description: "Recebimento de e-mail com criptografia", expectsTLS: true),
        1433: .init(name: "SQL Server", description: "Banco de dados Microsoft SQL", expectsTLS: false),
        1521: .init(name: "Oracle DB", description: "Banco de dados Oracle", expectsTLS: false),
        2375: .init(name: "Docker API", description: "API do Docker SEM TLS (perigoso se exposto)", expectsTLS: false),
        2376: .init(name: "Docker API (TLS)", description: "API do Docker com criptografia", expectsTLS: true),
        3000: .init(name: "App web", description: "Aplicação web (ex.: Grafana, Node)", expectsTLS: false),
        3306: .init(name: "MySQL", description: "Banco de dados MySQL/MariaDB", expectsTLS: false),
        3389: .init(name: "RDP", description: "Área de trabalho remota (Windows)", expectsTLS: true),
        5432: .init(name: "PostgreSQL", description: "Banco de dados PostgreSQL", expectsTLS: false),
        5601: .init(name: "Kibana", description: "Painel de logs (Elastic)", expectsTLS: false),
        5672: .init(name: "AMQP", description: "Fila de mensagens (RabbitMQ)", expectsTLS: false),
        6379: .init(name: "Redis", description: "Cache/banco em memória", expectsTLS: false),
        8080: .init(name: "HTTP (alt)", description: "Site/web alternativo sem criptografia", expectsTLS: false),
        8443: .init(name: "HTTPS (alt)", description: "Site/web seguro alternativo", expectsTLS: true),
        9000: .init(name: "App/console", description: "Console de aplicação (ex.: Portainer)", expectsTLS: false),
        9200: .init(name: "Elasticsearch", description: "Motor de busca/índice", expectsTLS: false),
        15672:.init(name: "RabbitMQ (painel)", description: "Painel de gerência de filas", expectsTLS: false),
        27017:.init(name: "MongoDB", description: "Banco de dados MongoDB", expectsTLS: false),
    ]

    public static func info(_ port: Int) -> Info? { table[port] }

    /// Nome curto do serviço (ou "porta N" se desconhecida).
    public static func name(_ port: Int) -> String { table[port]?.name ?? "porta \(port)" }

    /// A porta deveria falar TLS? (para reprovar serviço em texto puro onde se espera criptografia)
    public static func expectsTLS(_ port: Int) -> Bool { table[port]?.expectsTLS ?? false }
}
