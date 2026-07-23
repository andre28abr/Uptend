import Foundation

// =============================================================================
// DETECÇÃO DE DESVIO (drift) — FASE B3
// A postura de um host pode "regredir" entre coletas: a nota cai, surge um achado
// crítico, um controle que estava conforme volta a falhar. Esta análise resume o
// desvio entre a coleta anterior e a atual (reusando AuditCompare) e classifica a
// gravidade, para alertar quando algo piorou. Lógica pura → testável.
// =============================================================================

public enum DriftLevel: String, Sendable, CaseIterable {
    case melhorou = "Melhorou"
    case estavel = "Estável"
    case atencao = "Atenção"
    case critico = "Crítico"

    public var colorHex: String {
        switch self {
        case .melhorou: "#30a46c"
        case .estavel: "#8a8a8f"
        case .atencao: "#e2a336"
        case .critico: "#e5484d"
        }
    }
    /// Piorou de forma que merece alerta?
    public var isAlert: Bool { self == .atencao || self == .critico }
}

public struct DriftReport: Sendable, Equatable {
    public let level: DriftLevel
    public let prevDate: String
    public let curDate: String
    public let scoreDelta: Int
    public let newSevere: [AuditFinding]   // novos achados de severidade alta/crítica
    public let newIssuesCount: Int         // total de achados que surgiram
    public let resolvedCount: Int          // achados que sumiram/foram corrigidos
    public let reasons: [String]           // explicação em linguagem simples
}

public enum DriftAnalysis {

    /// Analisa o desvio entre duas auditorias do mesmo host (anterior → atual).
    public static func analyze(previous: ExternalAudit, current: ExternalAudit,
                               scoreDropAttention: Int = 5, scoreDropCritical: Int = 15) -> DriftReport {
        let cmp = AuditCompare.compare(previous: previous, current: current)
        return analyze(cmp, scoreDropAttention: scoreDropAttention, scoreDropCritical: scoreDropCritical)
    }

    /// Analisa o desvio a partir de uma comparação já calculada.
    public static func analyze(_ cmp: AuditComparison,
                               scoreDropAttention: Int = 5, scoreDropCritical: Int = 15) -> DriftReport {
        let newSevere = cmp.newIssues
            .filter { $0.severity >= .high }
            .sorted { $0.severity > $1.severity }
        var reasons: [String] = []
        var level: DriftLevel = .estavel

        if !newSevere.isEmpty {
            level = .critico
            reasons.append("\(newSevere.count) novo(s) achado(s) de severidade alta/crítica")
        }
        if cmp.scoreDelta <= -scoreDropCritical {
            level = .critico
            reasons.append("a nota caiu \(abs(cmp.scoreDelta)) ponto(s)")
        } else if cmp.scoreDelta <= -scoreDropAttention {
            if level != .critico { level = .atencao }
            reasons.append("a nota caiu \(abs(cmp.scoreDelta)) ponto(s)")
        }
        if level == .estavel, cmp.newIssues.count > 0 {
            level = .atencao
            reasons.append("\(cmp.newIssues.count) novo(s) achado(s)")
        }
        if level == .estavel, cmp.scoreDelta > 0 {
            level = .melhorou
        }
        if cmp.scoreDelta > 0 { reasons.append("a nota subiu \(cmp.scoreDelta) ponto(s)") }
        if cmp.resolved.count > 0 { reasons.append("\(cmp.resolved.count) achado(s) resolvido(s)") }
        if reasons.isEmpty { reasons.append("sem mudanças relevantes desde a última coleta") }

        return DriftReport(
            level: level, prevDate: cmp.prevDate, curDate: cmp.curDate,
            scoreDelta: cmp.scoreDelta, newSevere: newSevere,
            newIssuesCount: cmp.newIssues.count, resolvedCount: cmp.resolved.count,
            reasons: reasons)
    }
}
