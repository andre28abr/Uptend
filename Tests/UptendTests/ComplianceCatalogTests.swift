import Testing
import Foundation
@testable import UptendCore

struct ComplianceCatalogTests {

    private func f(_ id: String, _ sev: AuditSeverity, _ cat: String = "Segurança / Rede") -> AuditFinding {
        AuditFinding(id: id, title: id, severity: sev, category: cat, recommendation: "faça X")
    }
    private func audit(_ fs: [AuditFinding]) -> ExternalAudit {
        ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "admin"),
            collectedAt: "2026-07-21T00:00:00Z", host: .init(hostname: "h", machineId: nil),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: fs, lynis: nil)
    }

    @Test func catalogHas93Controls() {
        #expect(ComplianceCatalog.iso27001_2022.count == 93)
        // ids únicos
        let ids = Set(ComplianceCatalog.iso27001_2022.map(\.id))
        #expect(ids.count == 93)
    }

    @Test func transitionMapsKnownRefs() {
        #expect(ComplianceCatalog.iso2022("A.13.1.1") == "A.8.20")   // segurança de redes
        #expect(ComplianceCatalog.iso2022("A.9.4.2") == "A.8.5")     // autenticação segura
        #expect(ComplianceCatalog.iso2022("A.99.9.9") == nil)
    }

    @Test func openFindingMakesControlNaoConforme() {
        // firewall-inactive → A.13.1.1 → A.8.20 (segurança de redes)
        let soa = ComplianceCatalog.soaISO27001(audit([f("firewall-inactive", .high)]))
        let net = soa.first { $0.entry.id == "A.8.20" }!
        #expect(net.status == .naoConforme)
        #expect(net.findingIds == ["firewall-inactive"])
    }

    @Test func okFindingMakesControlCoberto() {
        let soa = ComplianceCatalog.soaISO27001(audit([f("firewall-inactive", .ok)]))
        #expect(soa.first { $0.entry.id == "A.8.20" }?.status == .coberto)
    }

    @Test func organizationalControlsAreManualWhenUntouched() {
        let soa = ComplianceCatalog.soaISO27001(audit([]))
        #expect(soa.first { $0.entry.id == "A.5.1" }?.status == .manual)     // política
        #expect(soa.first { $0.entry.id == "A.6.3" }?.status == .manual)     // treinamento
        // controle técnico não coberto = não avaliado
        #expect(soa.first { $0.entry.id == "A.8.20" }?.status == .naoAvaliado)
    }

    @Test func summaryPercentsAreConsistent() {
        // 1 coberto + 1 não conforme mapeados; resto manual/não avaliado
        let soa = ComplianceCatalog.soaISO27001(audit([f("firewall-inactive", .high), f("ssh-root-login", .ok, "Contas / SSH")]))
        let sum = ComplianceCatalog.summary(soa)
        #expect(sum.total == 93)
        #expect((sum.counts[.coberto] ?? 0) >= 1)
        #expect((sum.counts[.naoConforme] ?? 0) >= 1)
        #expect(sum.checkedPercent >= 0 && sum.checkedPercent <= 100)
    }

    @Test func csvHasHeaderAndAllRows() {
        let soa = ComplianceCatalog.soaISO27001(audit([]))
        let csv = ComplianceCatalog.csv(soa)
        #expect(csv.hasPrefix("controle,titulo,tema,natureza,status,achados"))
        #expect(csv.split(separator: "\n").count == 94)   // cabeçalho + 93 controles
    }

    @Test func soaReportIsSelfContained() throws {
        let url = try #require(Bundle.module.url(forResource: "lab-audit", withExtension: "json", subdirectory: "Fixtures"))
        let a = try ExternalAuditParser.parse(Data(contentsOf: url))
        let html = AuditReport.soaHTML(a)
        #expect(html.contains("Declaração de Aplicabilidade"))
        #expect(html.contains("Tecnológico"))
        #expect(html.contains("A.8.20"))
        #expect(html.contains("http://") == false && html.contains("https://") == false)
    }
}
