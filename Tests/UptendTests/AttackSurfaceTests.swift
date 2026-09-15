import Testing
import Foundation
@testable import UptendCore

struct AttackSurfaceTests {
    private func f(_ id: String, _ sev: AuditSeverity, evidence: String? = nil, cat: String = "Segurança / Rede") -> AuditFinding {
        AuditFinding(id: id, title: id, severity: sev, category: cat, evidence: evidence, recommendation: "x")
    }
    private func audit(_ fs: [AuditFinding]) -> ExternalAudit {
        ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "admin"),
            collectedAt: "2026-07-22T00:00:00Z", host: .init(hostname: "srv", machineId: nil),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: fs, lynis: nil)
    }

    @Test func parsesPortsAndRanksRisk() {
        let s = AttackSurfaceMap.from(audit([
            f("exposed-ports", .medium, evidence: "Escutando em todas as interfaces: 22 80 5432 8080")]))
        #expect(s.entries.map(\.port).sorted() == [22, 80, 5432, 8080])
        // Postgres (5432) exposto = risco alto e vem primeiro
        #expect(s.entries.first?.port == 5432)
        #expect(s.entries.first?.risk == .red)
        #expect(s.redCount == 1)
        #expect(AttackSurfaceMap.service(5432) == "PostgreSQL")
    }

    @Test func sshAlwaysPresentEvenWithoutFinding() {
        let s = AttackSurfaceMap.from(audit([]))
        #expect(s.entries.map(\.port) == [22])
        #expect(s.entries.first?.risk == .yellow)
    }

    @Test func tlsWeakDowngradesHttps() {
        let clean = AttackSurfaceMap.from(audit([f("exposed-ports", .medium, evidence: "porta 443")]))
        #expect(clean.entries.first(where: { $0.port == 443 })?.risk == .green)
        let weak = AttackSurfaceMap.from(audit([
            f("exposed-ports", .medium, evidence: "porta 443"),
            f("tls-weak-443", .high, cat: "Segurança / TLS")]))
        let e443 = weak.entries.first(where: { $0.port == 443 })
        #expect(e443?.risk == .yellow)
        #expect(e443?.tls == "TLS fraco")
    }

    @Test func ipsInEvidenceAreNotPorts() {
        // Regressão: capturar qualquer sequência de dígitos fragmentava um IP
        // (192.168.1.10 virava as "portas" 192, 168, 1 e 10).
        let s = AttackSurfaceMap.from(audit([
            f("exposed-ports", .medium, evidence: "192.168.1.10:8080 aberta e 0.0.0.0:3306")]))
        #expect(s.entries.map(\.port).sorted() == [22, 3306, 8080])
    }

    @Test func svgAndReportSelfContained() {
        let s = AttackSurfaceMap.from(audit([f("exposed-ports", .medium, evidence: "22 80 443")]))
        let svg = AttackSurfaceMap.svg(s)
        #expect(svg.hasPrefix("<svg") && svg.contains("</svg>"))
        let html = AuditReport.attackSurfaceHTML(audit([f("exposed-ports", .medium, evidence: "22 80 443")]))
        #expect(html.contains("Superfície de Ataque"))
        #expect(html.contains("http://") == false && html.contains("https://") == false)
    }
}
