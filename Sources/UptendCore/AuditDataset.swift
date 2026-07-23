import Foundation

// =============================================================================
// AUDITORIA EXTERNA — dataset para BI (Metabase / Power BI / planilha)
// Converte uma ou mais auditorias em CSV plano (tabelas), pronto para carregar
// numa ferramenta de BI e montar dashboards (evolução da nota, riscos por
// servidor, etc.). O Metabase importa CSV direto; o Power BI também.
// Lógica pura → testável.
// =============================================================================

public enum AuditDataset {

    /// Uma linha por (auditoria × achado): drill-down de riscos.
    /// Colunas: host, coletado_em, nota, achado_id, titulo, severidade, peso,
    /// categoria, cis.
    public static func findingsCSV(_ audits: [ExternalAudit]) -> String {
        var rows = "host,coletado_em,nota,achado_id,titulo,severidade,peso,categoria,cis\n"
        for audit in audits {
            let score = AuditScoring.evaluate(audit).score
            for f in audit.findings {
                rows += row([
                    audit.host.hostname,
                    audit.collectedAt,
                    String(score),
                    f.id,
                    f.title,
                    f.severity.rawValue,
                    String(f.severity.deduction),
                    f.category,
                    f.cis ?? "",
                ])
            }
        }
        return rows
    }

    /// Uma linha por auditoria: séries temporais (nota, contagens, hardware).
    /// Colunas: host, coletado_em, modo, nota, situacao, criticos, altos, medios,
    /// baixos, ok, discos, containers, lynis, so, eol.
    public static func summaryCSV(_ audits: [ExternalAudit]) -> String {
        var rows = "host,coletado_em,modo,nota,situacao,criticos,altos,medios,baixos,ok,discos,containers,lynis,so,eol\n"
        for audit in audits {
            let s = AuditScoring.evaluate(audit)
            rows += row([
                audit.host.hostname,
                audit.collectedAt,
                audit.collector.mode,
                String(s.score),
                AuditReport.lightLabel(s.light),
                String(s.counts[.critical] ?? 0),
                String(s.counts[.high] ?? 0),
                String(s.counts[.medium] ?? 0),
                String(s.counts[.low] ?? 0),
                String(s.counts[.ok] ?? 0),
                String(audit.disks.count),
                String(audit.docker?.total ?? 0),
                audit.lynis?.hardeningIndex.map(String.init) ?? "",
                audit.os?.pretty ?? audit.os?.distro ?? "",
                audit.os?.eolDate ?? "",
            ])
        }
        return rows
    }

    // MARK: CSV helpers

    private static func row(_ fields: [String]) -> String {
        fields.map(escape).joined(separator: ",") + "\n"
    }

    /// Campo CSV seguro: entre aspas quando tem vírgula/aspas/quebra de linha (RFC 4180).
    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
