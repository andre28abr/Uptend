import Foundation

// =============================================================================
// LENTE LGPD (E4) — mapeia os achados às obrigações de SEGURANÇA da LGPD
// Não é um silo: atravessa TODOS os achados (sistema + banco) e os agrupa pelos
// artigos da LGPD que tocam segurança da informação (art. 46, 6º-VII, 37).
// É uma avaliação TÉCNICA — não parecer jurídico. Lógica pura → testável.
// =============================================================================

public struct LGPDArticle: Sendable, Equatable {
    public let code: String       // ex.: "Art. 46"
    public let theme: String      // ex.: "Medidas de segurança"
}

public struct LGPDItem: Identifiable, Sendable, Equatable {
    public let finding: AuditFinding
    public let article: LGPDArticle
    public var id: String { finding.id }
}

public struct LGPDSummary: Sendable, Equatable {
    public let total: Int
    public let byArticle: [String: Int]     // code → contagem
    public let critical: Int
    public let high: Int
}

public enum LGPDLens {

    /// Artigo da LGPD que o achado toca — nil se não é relevante para LGPD.
    static func article(for f: AuditFinding) -> LGPDArticle? {
        let c = f.category.lowercased()
        let id = f.id.lowercased()
        if c.contains("banco") || c.contains("lgpd") {
            // Dado pessoal em texto plano / senha em claro → segurança + minimização
            if id.contains("pii") || id.contains("password") {
                return LGPDArticle(code: "Art. 46 / 6º-VII", theme: "Segurança de dados pessoais")
            }
            return LGPDArticle(code: "Art. 46", theme: "Integridade e segurança do banco")
        }
        if c.contains("ssh") || c.contains("conta") {
            return LGPDArticle(code: "Art. 46", theme: "Controle de acesso aos dados")
        }
        if c.contains("tls") { return LGPDArticle(code: "Art. 46", theme: "Segurança na transmissão (TLS)") }
        if c.contains("rede") { return LGPDArticle(code: "Art. 46", theme: "Proteção de rede / exposição") }
        if c.contains("log") { return LGPDArticle(code: "Art. 37", theme: "Registro das operações de tratamento") }
        if c.contains("atualiz") || c.contains("sistema operacional") || c.contains("hardening") {
            return LGPDArticle(code: "Art. 46", theme: "Manutenção segura do ambiente")
        }
        return nil   // ex.: discos/SMART — não é obrigação da LGPD
    }

    /// Achados ABERTOS relevantes à LGPD, ordenados por severidade.
    public static func items(_ audit: ExternalAudit) -> [LGPDItem] {
        audit.findings
            .filter { $0.severity > .ok }
            .compactMap { f in article(for: f).map { LGPDItem(finding: f, article: $0) } }
            .sorted { $0.finding.severity > $1.finding.severity }
    }

    public static func summary(_ items: [LGPDItem]) -> LGPDSummary {
        var byArt: [String: Int] = [:]
        for it in items { byArt[it.article.code, default: 0] += 1 }
        return LGPDSummary(
            total: items.count, byArticle: byArt,
            critical: items.filter { $0.finding.severity == .critical }.count,
            high: items.filter { $0.finding.severity == .high }.count)
    }

    // MARK: Export CSV

    public static func csv(_ items: [LGPDItem]) -> String {
        var out = "artigo,tema,severidade,achado,recomendacao\n"
        for it in items {
            out += [it.article.code, it.article.theme, it.finding.severity.label,
                    it.finding.title, it.finding.recommendation ?? ""]
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
