import Testing
import Foundation
@testable import UptendCore

struct AuditCompareTests {

    private func f(_ id: String, _ sev: AuditSeverity, _ cat: String = "Segurança / SSH") -> AuditFinding {
        AuditFinding(id: id, title: id, severity: sev, category: cat)
    }
    private func audit(_ date: String, _ fs: [AuditFinding]) -> ExternalAudit {
        ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "admin"),
            collectedAt: date, host: .init(hostname: "srv", machineId: nil),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: fs, lynis: nil)
    }

    @Test func detectsResolvedNewAndPersistent() {
        let prev = audit("2026-07-01T00:00:00Z", [
            f("ssh-root-login", .high), f("firewall-inactive", .high, "Segurança / Rede"),
        ])
        let cur = audit("2026-07-20T00:00:00Z", [
            f("ssh-root-login-ok", .ok), f("firewall-inactive", .high, "Segurança / Rede"),
            f("auditd-missing", .medium, "Segurança / Logs"),
        ])
        let c = AuditCompare.compare(previous: prev, current: cur)
        #expect(c.resolved.contains { $0.id == "ssh-root-login" })     // virou ok
        #expect(c.persistent.contains { $0.id == "firewall-inactive" })// continua
        #expect(c.newIssues.contains { $0.id == "auditd-missing" })    // surgiu
    }

    @Test func variantChangeStaysPersistentNotResolvedPlusNew() {
        // M2: o controle continua não-conforme, só MUDA o motivo (mac-inactive →
        // mac-missing). Deve ser "persistente", não resolvido+novo (que dispararia
        // um drift "Crítico" falso). Depende de controlKey unificar as variantes.
        let prev = audit("2026-07-01T00:00:00Z", [f("mac-inactive", .medium, "Segurança / Hardening")])
        let cur  = audit("2026-07-20T00:00:00Z", [f("mac-missing", .medium, "Segurança / Hardening")])
        let c = AuditCompare.compare(previous: prev, current: cur)
        #expect(c.persistent.count == 1)
        #expect(c.resolved.isEmpty)
        #expect(c.newIssues.isEmpty)
        // E o drift não deve acusar regressão espúria.
        let drift = DriftAnalysis.analyze(previous: prev, current: cur)
        #expect(drift.level != .critico)
    }

    @Test func scoreDeltaAndDomainDeltas() {
        let prev = audit("2026-07-01T00:00:00Z", [f("ssh-root-login", .high)])            // 90
        let cur = audit("2026-07-20T00:00:00Z", [f("ssh-root-login-ok", .ok)])            // 100
        let c = AuditCompare.compare(previous: prev, current: cur)
        #expect(c.prevScore == 90)
        #expect(c.curScore == 100)
        #expect(c.scoreDelta == 10)
        let acesso = c.domainDeltas.first { $0.name == "Acesso e autenticação" }
        #expect(acesso?.delta == 10)   // 90 → 100 (um achado alto = −10)
    }

    @Test func comparisonHTMLIsWellFormedAndSelfContained() {
        let prev = audit("2026-07-01T00:00:00Z", [f("ssh-root-login", .high)])
        let cur = audit("2026-07-20T00:00:00Z", [f("auditd-missing", .medium, "Segurança / Logs")])
        let html = AuditReport.comparisonHTML(previous: prev, current: cur)
        #expect(html.hasPrefix("<!DOCTYPE html>"))
        #expect(html.contains("Evolução da Auditoria"))
        #expect(html.contains("Variação por área"))
        #expect(html.contains("http://") == false && html.contains("https://") == false)
    }
}
