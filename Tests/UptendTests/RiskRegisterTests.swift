import Testing
import Foundation
@testable import UptendCore

struct RiskRegisterTests {

    private func f(_ id: String, _ sev: AuditSeverity, _ cat: String = "Segurança / Hardening") -> AuditFinding {
        AuditFinding(id: id, title: id, severity: sev, category: cat, recommendation: "faça X")
    }
    private func audit(_ fs: [AuditFinding]) -> ExternalAudit {
        ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "admin"),
            collectedAt: "2026-07-21T00:00:00Z", host: .init(hostname: "h", machineId: nil),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: fs, lynis: nil)
    }

    @Test func derivesRisksFromOpenFindings() {
        let a = audit([f("kernel-aslr", .low), f("firewall-inactive", .high, "Segurança / Rede"), f("ok1", .ok)])
        let risks = RiskRegister.risks(from: a)
        #expect(risks.count == 2)                         // "ok" não vira risco
        #expect(risks.first?.id == "R-001")               // numerado
        #expect(risks.first!.score >= risks.last!.score)  // ordenado por pontuação desc
    }

    @Test func likelihoodImpactAndLevel() {
        // firewall-inactive: high (impacto 4) + categoria Rede (+1 prob) → prob 5, score 20 = Crítico.
        let a = audit([f("firewall-inactive", .high, "Segurança / Rede")])
        let r = RiskRegister.risks(from: a).first!
        #expect(r.impact == 4)
        #expect(r.likelihood == 5)
        #expect(r.score == 20)
        #expect(r.level == .critico)
    }

    @Test func matrixCountsPlaceRisksCorrectly() {
        let a = audit([f("firewall-inactive", .high, "Segurança / Rede")])  // impacto4 prob5
        let grid = RiskRegister.matrixCounts(RiskRegister.risks(from: a))
        // impacto 4 → linha (5-4)=1 ; probabilidade 5 → coluna 4
        #expect(grid[1][4] == 1)
        #expect(grid[0][0] == 0)
    }

    @Test func csvHasHeaderAndRows() {
        let a = audit([f("kernel-aslr", .low), f("firewall-inactive", .high, "Segurança / Rede")])
        let csv = RiskRegister.csv(RiskRegister.risks(from: a))
        #expect(csv.hasPrefix("id,titulo,categoria,probabilidade,impacto,pontuacao,nivel,tratamento,recomendacao"))
        #expect(csv.split(separator: "\n").count == 3)   // cabeçalho + 2 riscos
    }

    @Test func htmlReportIsSelfContained() throws {
        let url = try #require(Bundle.module.url(forResource: "lab-audit", withExtension: "json", subdirectory: "Fixtures"))
        let audit = try ExternalAuditParser.parse(Data(contentsOf: url))
        let html = AuditReport.riskRegisterHTML(audit)
        #expect(html.hasPrefix("<!DOCTYPE html>"))
        #expect(html.contains("Matriz de risco"))
        #expect(html.contains("class='riskmx'"))
        #expect(html.contains("Riscos priorizados"))
        #expect(html.contains("http://") == false && html.contains("https://") == false)
    }
}
