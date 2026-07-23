import Foundation

// =============================================================================
// REGISTRO DE RISCO (risk register) — FASE A4
// Converte os achados abertos em RISCOS na linguagem de GRC: ID, probabilidade ×
// impacto (matriz 5×5), nível, tratamento e recomendação. Base para a matriz de
// calor e para exportar (CSV/HTML). Lógica pura → testável.
// =============================================================================

public enum RiskLevel: String, Sendable, CaseIterable {
    case baixo = "Baixo", medio = "Médio", alto = "Alto", critico = "Crítico"
}

public struct Risk: Identifiable, Equatable, Sendable {
    public let id: String            // ex.: "R-001"
    public let findingId: String
    public let title: String
    public let category: String
    public let likelihood: Int       // probabilidade 1–5
    public let impact: Int           // impacto 1–5
    public let treatment: String     // Mitigar / Aceitar / Transferir / Evitar
    public let recommendation: String?

    public var score: Int { likelihood * impact }   // 1–25
    public var level: RiskLevel {
        switch score { case 15...: .critico; case 10..<15: .alto; case 5..<10: .medio; default: .baixo }
    }
}

public enum RiskRegister {

    /// Probabilidade (1–5): parte da severidade e sobe se o achado é de exposição/acesso
    /// (mais provável de ser explorado) ou de patch (alvo de exploit automatizado).
    static func likelihood(_ f: AuditFinding) -> Int {
        var l: Int
        switch f.severity { case .critical: l = 4; case .high: l = 4; case .medium: l = 3; case .low: l = 2; case .ok: l = 1 }
        let c = f.category.lowercased()
        if c.contains("rede") || c.contains("ssh") || c.contains("tls") || c.contains("conta") { l += 1 }
        let base = ComplianceMap.baseKey(f.id)
        if base.contains("updates") || base == "os-eol" || base == "exposed-ports" { l += 1 }
        return min(5, max(1, l))
    }

    /// Impacto (1–5): direto da severidade.
    static func impact(_ f: AuditFinding) -> Int {
        switch f.severity { case .critical: 5; case .high: 4; case .medium: 3; case .low: 2; case .ok: 1 }
    }

    /// Riscos derivados dos achados abertos (severidade > ok), do mais grave ao menos.
    public static func risks(from audit: ExternalAudit) -> [Risk] {
        let open = audit.findings.filter { $0.severity > .ok }
        let ranked = open.map { f -> Risk in
            Risk(id: "", findingId: f.id, title: f.title, category: f.category,
                 likelihood: likelihood(f), impact: impact(f),
                 treatment: "Mitigar", recommendation: f.recommendation)
        }.sorted {
            $0.score != $1.score ? $0.score > $1.score
                : $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        // Numera R-001, R-002, …
        return ranked.enumerated().map { i, r in
            Risk(id: String(format: "R-%03d", i + 1), findingId: r.findingId, title: r.title,
                 category: r.category, likelihood: r.likelihood, impact: r.impact,
                 treatment: r.treatment, recommendation: r.recommendation)
        }
    }

    /// Contagem de riscos por célula da matriz [impacto 5..1][probabilidade 1..5].
    public static func matrixCounts(_ risks: [Risk]) -> [[Int]] {
        var grid = Array(repeating: Array(repeating: 0, count: 5), count: 5)  // [linha][coluna]
        for r in risks {
            let row = 5 - r.impact       // impacto 5 no topo (linha 0)
            let col = r.likelihood - 1   // probabilidade 1 à esquerda (coluna 0)
            if (0..<5).contains(row), (0..<5).contains(col) { grid[row][col] += 1 }
        }
        return grid
    }

    /// Nível de risco de uma célula (probabilidade × impacto) — para colorir a matriz.
    public static func cellLevel(likelihood: Int, impact: Int) -> RiskLevel {
        let s = likelihood * impact
        switch s { case 15...: return .critico; case 10..<15: return .alto; case 5..<10: return .medio; default: return .baixo }
    }

    // MARK: Export CSV

    public static func csv(_ risks: [Risk]) -> String {
        var out = "id,titulo,categoria,probabilidade,impacto,pontuacao,nivel,tratamento,recomendacao\n"
        for r in risks {
            out += [r.id, r.title, r.category, String(r.likelihood), String(r.impact),
                    String(r.score), r.level.rawValue, r.treatment, r.recommendation ?? ""]
                .map(csvEscape).joined(separator: ",") + "\n"
        }
        return out
    }

    private static func csvEscape(_ v: String) -> String {
        if v.contains(",") || v.contains("\"") || v.contains("\n") {
            return "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return v
    }
}
