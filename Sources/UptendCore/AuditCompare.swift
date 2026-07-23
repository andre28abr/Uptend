import Foundation

// =============================================================================
// AUDITORIA EXTERNA — comparação entre duas auditorias (evolução no tempo)
// "O que mudou desde a última auditoria": nota, achados resolvidos, novos e
// persistentes, e a variação por área. Lógica pura.
// =============================================================================

public struct AuditComparison: Equatable, Sendable {
    public let host: String
    public let prevDate: String
    public let curDate: String
    public let prevScore: Int
    public let curScore: Int
    public var scoreDelta: Int { curScore - prevScore }
    public let resolved: [AuditFinding]    // eram problema antes, agora conformes/ausentes
    public let newIssues: [AuditFinding]   // problemas que surgiram
    public let persistent: [AuditFinding]  // continuam abertos
    public let domainDeltas: [DomainDelta]

    public struct DomainDelta: Equatable, Sendable, Identifiable {
        public let name: String
        public let prev: Int
        public let cur: Int
        public var id: String { name }
        public var delta: Int { cur - prev }
    }
}

public enum AuditCompare {

    public static func compare(previous: ExternalAudit, current: ExternalAudit) -> AuditComparison {
        // controlKey (não baseKey) para casar variantes do MESMO controle: se só o
        // MOTIVO muda (mac-inactive→mac-missing, updates-pending→updates-security-
        // pending), o controle continua "persistente", não vira resolvido+novo (o que
        // dispararia um alerta de drift "Crítico" espúrio). Igual a Baseline/Fleet.
        let prevProblems = Dictionary(previous.findings.filter { $0.severity > .ok }
            .map { (ComplianceMap.controlKey($0.id), $0) }, uniquingKeysWith: { a, _ in a })
        let curProblems = Dictionary(current.findings.filter { $0.severity > .ok }
            .map { (ComplianceMap.controlKey($0.id), $0) }, uniquingKeysWith: { a, _ in a })

        let resolved = prevProblems.filter { curProblems[$0.key] == nil }.map(\.value)
            .sorted { $0.severity > $1.severity }
        let newIssues = curProblems.filter { prevProblems[$0.key] == nil }.map(\.value)
            .sorted { $0.severity > $1.severity }
        let persistent = curProblems.filter { prevProblems[$0.key] != nil }.map(\.value)
            .sorted { $0.severity > $1.severity }

        let prevDomains = Dictionary(AuditDomains.scores(previous).map { ($0.name, $0.score) }, uniquingKeysWith: { a, _ in a })
        let curDomains = AuditDomains.scores(current)
        let deltas = curDomains.map {
            AuditComparison.DomainDelta(name: $0.name, prev: prevDomains[$0.name] ?? $0.score, cur: $0.score)
        }

        return AuditComparison(
            host: current.host.hostname,
            prevDate: previous.collectedAt, curDate: current.collectedAt,
            prevScore: AuditScoring.evaluate(previous).score,
            curScore: AuditScoring.evaluate(current).score,
            resolved: resolved, newIssues: newIssues, persistent: persistent,
            domainDeltas: deltas)
    }
}
