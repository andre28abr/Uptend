import Foundation

// =============================================================================
// AUDITORIA EXTERNA — pontuação por ÁREA (domínio de risco)
// Além da nota geral, dá uma nota (0–100) por área — Acesso, Rede, Endurecimento,
// Atualizações, Registro, Discos — para mostrar onde o servidor está forte/fraco.
// Lógica pura.
// =============================================================================

public struct DomainScore: Identifiable, Equatable, Sendable {
    public let name: String
    public let score: Int
    public let findings: Int
    public var id: String { name }
    public var light: AuditLight { score < 50 ? .red : (score < 80 ? .yellow : .green) }
}

public enum AuditDomains {

    /// Ordem canônica das áreas (para exibição estável).
    static let order = [
        "Acesso e autenticação", "Rede e firewall", "Endurecimento do sistema",
        "Atualizações e patches", "Registro e detecção", "Discos e resiliência",
        "Banco de dados",
    ]

    /// Categoria do achado → área de risco.
    public static func domain(for category: String) -> String {
        let c = category.lowercased()
        if c.contains("banco") || c.contains("lgpd") { return "Banco de dados" }
        if c.contains("ssh") || c.contains("conta") { return "Acesso e autenticação" }
        if c.contains("rede") || c.contains("tls") { return "Rede e firewall" }
        if c.contains("hardening") { return "Endurecimento do sistema" }
        if c.contains("atualiz") || c.contains("sistema operacional") { return "Atualizações e patches" }
        if c.contains("log") || c.contains("malware") { return "Registro e detecção" }
        if c.contains("disco") { return "Discos e resiliência" }
        return "Outros"
    }

    /// Nota por área: 100 − deduções dos achados da área (piso 0). Só áreas com achados.
    public static func scores(_ audit: ExternalAudit) -> [DomainScore] {
        var deduction: [String: Int] = [:]
        var count: [String: Int] = [:]
        for f in audit.findings {
            let d = domain(for: f.category)
            deduction[d, default: 0] += f.severity.deduction
            count[d, default: 0] += 1
        }
        var result: [DomainScore] = []
        for name in order where count[name] != nil {
            let sc = max(0, min(100, 100 - (deduction[name] ?? 0)))
            result.append(DomainScore(name: name, score: sc, findings: count[name] ?? 0))
        }
        // Áreas fora da ordem canônica (ex.: "Outros"), se houver.
        for (name, cnt) in count where !order.contains(name) {
            let sc = max(0, min(100, 100 - (deduction[name] ?? 0)))
            result.append(DomainScore(name: name, score: sc, findings: cnt))
        }
        return result
    }
}
