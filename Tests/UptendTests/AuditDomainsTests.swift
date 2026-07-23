import Testing
import Foundation
@testable import UptendCore

struct AuditDomainsTests {

    private func f(_ id: String, _ cat: String, _ sev: AuditSeverity) -> AuditFinding {
        AuditFinding(id: id, title: id, severity: sev, category: cat)
    }
    private func audit(_ fs: [AuditFinding]) -> ExternalAudit {
        ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "admin"),
            collectedAt: "2026-07-20T00:00:00Z", host: .init(hostname: "h", machineId: nil),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: fs, lynis: nil)
    }

    @Test func categoriesMapToDomains() {
        #expect(AuditDomains.domain(for: "Segurança / SSH") == "Acesso e autenticação")
        #expect(AuditDomains.domain(for: "Segurança / Contas") == "Acesso e autenticação")
        #expect(AuditDomains.domain(for: "Segurança / Rede") == "Rede e firewall")
        #expect(AuditDomains.domain(for: "Atualizações") == "Atualizações e patches")
        #expect(AuditDomains.domain(for: "Segurança / Logs") == "Registro e detecção")
        #expect(AuditDomains.domain(for: "Discos & resiliência") == "Discos e resiliência")
    }

    @Test func perDomainScoreDeductsBySeverity() {
        let a = audit([
            f("ssh-root-login", "Segurança / SSH", .high),      // -10
            f("ssh-password-auth", "Segurança / SSH", .medium), // -5
            f("firewall-ok", "Segurança / Rede", .ok),          // -0
        ])
        let ds = AuditDomains.scores(a)
        let acesso = ds.first { $0.name == "Acesso e autenticação" }
        #expect(acesso?.score == 85)   // 100 - 15
        #expect(acesso?.findings == 2)
        let rede = ds.first { $0.name == "Rede e firewall" }
        #expect(rede?.score == 100)
    }

    @Test func reportsHaveProfessionalStructure() throws {
        let url = try #require(Bundle.module.url(forResource: "lab-audit", withExtension: "json", subdirectory: "Fixtures"))
        let a = try ExternalAuditParser.parse(Data(contentsOf: url))
        for html in [AuditReport.executiveHTML(a), AuditReport.socHTML(a), AuditReport.html(a)] {
            #expect(html.contains("CONFIDENCIAL"))
            #expect(html.contains("class='meta'"))
            #expect(html.contains("Pontuação por área"))
            #expect(html.contains("Metodologia e frameworks"))
        }
        #expect(AuditReport.executiveHTML(a).contains("Sumário executivo"))
        #expect(AuditReport.markdown(a).contains("## Pontuação por área"))
    }
}
