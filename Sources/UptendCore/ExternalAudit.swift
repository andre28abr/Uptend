import Foundation

// =============================================================================
// AUDITORIA EXTERNA — Schema v1 (modelos puros + parser + pontuação)
// A "verdade" ingerida pelo Uptend: um JSON estruturado e versionado, gerado por
// um coletor portátil read-only (audit-collector.sh). Aqui só há lógica pura
// (sem UI, sem rede) — decodifica, valida a versão do schema e calcula a nota /
// semáforo / top riscos. Testável isoladamente com fixtures reais.
//
// Ver AUDITORIA-EXTERNA.md (seções 4, 5, 7, 9).
// =============================================================================

/// Severidade de um achado, do "tudo certo" ao "crítico". Comparável (para ordenar
/// riscos) e com um "peso" de dedução usado na nota geral.
public enum AuditSeverity: String, Codable, CaseIterable, Comparable, Sendable {
    case ok, low, medium, high, critical

    private var rank: Int {
        switch self {
        case .ok: 0; case .low: 1; case .medium: 2; case .high: 3; case .critical: 4
        }
    }

    /// Quantos pontos (de 100) este achado tira da nota geral.
    public var deduction: Int {
        switch self {
        case .ok: 0; case .low: 2; case .medium: 5; case .high: 10; case .critical: 20
        }
    }

    /// Rótulo amigável em português (para relatórios/painel).
    public var label: String {
        switch self {
        case .ok: "OK"; case .low: "Baixa"; case .medium: "Média"
        case .high: "Alta"; case .critical: "Crítica"
        }
    }

    public static func < (lhs: AuditSeverity, rhs: AuditSeverity) -> Bool { lhs.rank < rhs.rank }
}

/// Um achado normalizado da auditoria (o coração do relatório): o que é, quão
/// grave, a evidência, como corrigir e o **impacto de negócio** (técnico → gestão).
public struct AuditFinding: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let severity: AuditSeverity
    public let category: String
    public let cis: String?               // controle CIS, ex.: "5.2.8" (opcional)
    public let evidence: String?
    public let recommendation: String?
    public let businessImpact: String?    // "impacto de negócio" em linguagem de gestão
    public let evidenceRaw: String?       // saída bruta do comando (reprodutibilidade, redigida)

    public init(id: String, title: String, severity: AuditSeverity, category: String,
                cis: String? = nil, evidence: String? = nil,
                recommendation: String? = nil, businessImpact: String? = nil,
                evidenceRaw: String? = nil) {
        self.id = id; self.title = title; self.severity = severity; self.category = category
        self.cis = cis; self.evidence = evidence
        self.recommendation = recommendation; self.businessImpact = businessImpact
        self.evidenceRaw = evidenceRaw
    }
}

/// O documento completo importado pelo Uptend.
public struct ExternalAudit: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let collector: Collector
    public let collectedAt: String         // ISO 8601 (UTC)
    public let host: HostIdentity
    public let machine: Machine?
    public let os: OSInfo?
    public let disks: [Disk]
    public let resources: Resources?
    public let users: Users?
    public let docker: Docker?
    public let profile: Profile?
    public let findings: [AuditFinding]
    public let lynis: Lynis?
    public let software: [SoftwarePackage]?   // versões colhidas (host + docker) — C1
    public let databases: [DatabaseSchema]?   // schemas de banco (só estrutura) — E4

    public init(schemaVersion: Int, collector: Collector, collectedAt: String, host: HostIdentity,
                machine: Machine?, os: OSInfo?, disks: [Disk], resources: Resources?, users: Users?,
                docker: Docker?, profile: Profile?, findings: [AuditFinding], lynis: Lynis?,
                software: [SoftwarePackage]? = nil, databases: [DatabaseSchema]? = nil) {
        self.schemaVersion = schemaVersion; self.collector = collector; self.collectedAt = collectedAt
        self.host = host; self.machine = machine; self.os = os; self.disks = disks
        self.resources = resources; self.users = users; self.docker = docker; self.profile = profile
        self.findings = findings; self.lynis = lynis; self.software = software; self.databases = databases
    }

    /// Se o coletor trouxe schemas de banco (`databases`), deriva os achados de estrutura/LGPD
    /// e os anexa. Idempotente (não duplica se já houver achados `db-`).
    public func enrichedWithDatabaseFindings() -> ExternalAudit {
        guard let dbs = databases, !dbs.isEmpty,
              !findings.contains(where: { $0.id.hasPrefix("db-") }) else { return self }
        let dbFindings = dbs.flatMap { DatabaseAudit.findings(from: $0).filter { $0.severity > .ok } }
        guard !dbFindings.isEmpty else { return self }
        return replacingFindings(findings + dbFindings)
    }

    /// Software colhido (nome + versão), do host ou de imagens Docker. Base do cruzamento com CVE.
    public struct SoftwarePackage: Codable, Equatable, Sendable, Identifiable {
        public let name: String       // ex.: "openssh", "openssl", "nginx"
        public let version: String    // ex.: "9.6p1", "3.0.2", "1.18.0"
        public let source: String?    // "host" | "docker:<container>"
        public var id: String { "\(name)@\(version)#\(source ?? "")" }
        public init(name: String, version: String, source: String? = nil) {
            self.name = name; self.version = version; self.source = source
        }
    }

    /// Cópia com outra lista de achados (para mesclar achados de varredura ativa).
    public func replacingFindings(_ newFindings: [AuditFinding]) -> ExternalAudit {
        ExternalAudit(schemaVersion: schemaVersion, collector: collector, collectedAt: collectedAt,
                      host: host, machine: machine, os: os, disks: disks, resources: resources,
                      users: users, docker: docker, profile: profile, findings: newFindings, lynis: lynis,
                      software: software, databases: databases)
    }

    public struct Collector: Codable, Equatable, Sendable {
        public let name: String
        public let version: String
        public let mode: String            // "user" | "admin"
    }

    public struct HostIdentity: Codable, Equatable, Sendable {
        public let hostname: String
        public let machineId: String?
    }

    public struct Machine: Codable, Equatable, Sendable {
        public let virtual: Bool?
        public let vendor: String?
        public let model: String?
        public let cpuModel: String?
        public let cpuCores: Int?
        public let ramBytes: Int64?
        public let biosVendor: String?
        public let biosVersion: String?
        public let biosDate: String?
    }

    public struct OSInfo: Codable, Equatable, Sendable {
        public let distro: String?
        public let version: String?
        public let pretty: String?
        public let kernel: String?
        public let uptimeSeconds: Double?
        public let eolDate: String?        // ISO date "AAAA-MM-DD" ou nil
        public let updatesTotal: Int?
        public let updatesSecurity: Int?
    }

    public struct Disk: Codable, Equatable, Identifiable, Sendable {
        public let name: String
        public let model: String?
        public let sizeBytes: Int64?
        public let rotational: Bool?
        public let smartAvailable: Bool?
        public let smartHealthy: Bool?
        public let powerOnHours: Int?
        public let reallocatedSectors: Int?
        public var id: String { name }
    }

    public struct Lynis: Codable, Equatable, Sendable {
        public let available: Bool
        public let hardeningIndex: Int?
        public let warnings: [String]
        public let suggestions: [String]
    }

    /// Recursos e estado operacional (valor para negócio: risco de parada/encher disco).
    public struct Resources: Codable, Equatable, Sendable {
        public let diskRootPercent: Int?
        public let diskRootFreeBytes: Int64?
        public let diskRootTotalBytes: Int64?
        public let swapTotalBytes: Int64?
        public let rebootRequired: Bool?
        public let timeSynced: Bool?
    }

    /// Contas e privilégios (superfície de ataque / governança de acesso).
    public struct Users: Codable, Equatable, Sendable {
        public let loginUsers: Int?
        public let sudoUsers: [String]
        public let emptyPasswordUsers: [String]
    }

    /// Containers Docker do servidor (o que ele hospeda).
    public struct Docker: Codable, Equatable, Sendable {
        public let installed: Bool
        public let running: Int?
        public let total: Int?
        public let containers: [Container]

        public struct Container: Codable, Equatable, Sendable, Identifiable {
            public let name: String
            public let image: String
            public let state: String?
            public let status: String?
            public var id: String { name }
        }
    }

    /// Perfil de propósito do servidor: prontidão (0–100) para cada finalidade, com
    /// os indícios presentes/ausentes. Responde "para que este servidor está preparado?".
    public struct Profile: Codable, Equatable, Sendable {
        public let primary: String?
        public let purposes: [Purpose]

        public struct Purpose: Codable, Equatable, Sendable, Identifiable {
            public let key: String
            public let label: String
            public let score: Int
            public let present: [String]
            public let missing: [String]
            public var id: String { key }
        }
    }
}

// MARK: - Parser + validação de versão

public enum ExternalAuditParser {
    /// Maior versão de schema que este build entende.
    public static let currentSchemaVersion = 1

    public enum ParseError: Error, Equatable {
        case invalidJSON(String)
        case unsupportedVersion(found: Int, max: Int)
    }

    /// Decodifica e valida um arquivo de auditoria. Não faz rede — só processa o dado.
    public static func parse(_ data: Data) throws -> ExternalAudit {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let audit: ExternalAudit
        do {
            audit = try decoder.decode(ExternalAudit.self, from: data)
        } catch {
            throw ParseError.invalidJSON(String(describing: error))
        }
        guard audit.schemaVersion >= 1 else {
            throw ParseError.invalidJSON("schema_version inválido: \(audit.schemaVersion)")
        }
        guard audit.schemaVersion <= currentSchemaVersion else {
            // Arquivo mais novo que o app — pedir para atualizar o Uptend.
            throw ParseError.unsupportedVersion(found: audit.schemaVersion, max: currentSchemaVersion)
        }
        return audit
    }
}

// MARK: - Pontuação / semáforo / top riscos

public enum AuditLight: String, Sendable { case green, yellow, red }

public struct AuditCategoryStatus: Equatable, Identifiable, Sendable {
    public let category: String
    public let worst: AuditSeverity
    public let count: Int
    public var id: String { category }
    public var light: AuditLight {
        if worst >= .high { return .red }
        if worst >= .low { return .yellow }
        return .green
    }
}

public struct AuditScore: Equatable, Sendable {
    public let score: Int                            // 0…100
    public let counts: [AuditSeverity: Int]          // quantos achados por severidade
    public let categories: [AuditCategoryStatus]     // semáforo por categoria (alfabético)
    public let topRisks: [AuditFinding]              // piores primeiro (exclui "ok")

    public var light: AuditLight {
        if score < 50 { return .red }
        if score < 80 { return .yellow }
        return .green
    }
}

public enum AuditScoring {
    /// Calcula a nota geral (100 − deduções, piso 0), contagem por severidade,
    /// semáforo por categoria e os principais riscos.
    public static func evaluate(_ audit: ExternalAudit, topN: Int = 5) -> AuditScore {
        let findings = audit.findings

        var counts: [AuditSeverity: Int] = [:]
        var deductions = 0
        for f in findings {
            counts[f.severity, default: 0] += 1
            deductions += f.severity.deduction
        }
        let score = max(0, min(100, 100 - deductions))

        // Semáforo por categoria: a pior severidade da categoria manda.
        var worstByCategory: [String: (worst: AuditSeverity, count: Int)] = [:]
        for f in findings {
            let cur = worstByCategory[f.category]
            let worst = max(cur?.worst ?? .ok, f.severity)
            worstByCategory[f.category] = (worst, (cur?.count ?? 0) + 1)
        }
        let categories = worstByCategory
            .map { AuditCategoryStatus(category: $0.key, worst: $0.value.worst, count: $0.value.count) }
            .sorted { $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending }

        // Top riscos: piores primeiro; desempate estável por título.
        let topRisks = findings
            .filter { $0.severity > .ok }
            .sorted {
                $0.severity != $1.severity
                    ? $0.severity > $1.severity
                    : $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            .prefix(topN)

        return AuditScore(score: score, counts: counts, categories: categories, topRisks: Array(topRisks))
    }
}
