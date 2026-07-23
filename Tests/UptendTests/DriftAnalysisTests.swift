import Testing
import Foundation
@testable import UptendCore

struct DriftAnalysisTests {

    private func f(_ id: String, _ sev: AuditSeverity, _ cat: String = "Segurança / Rede") -> AuditFinding {
        AuditFinding(id: id, title: id, severity: sev, category: cat, recommendation: "faça X")
    }
    private func audit(_ date: String, _ fs: [AuditFinding]) -> ExternalAudit {
        ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "admin"),
            collectedAt: date, host: .init(hostname: "h", machineId: "m-1"),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: fs, lynis: nil)
    }

    @Test func newSevereFindingIsCritico() {
        let prev = audit("2026-07-01T00:00:00Z", [f("firewall-inactive", .ok)])
        let cur  = audit("2026-07-15T00:00:00Z", [f("firewall-inactive", .high)])   // regrediu
        let d = DriftAnalysis.analyze(previous: prev, current: cur)
        #expect(d.level == .critico)
        #expect(d.newSevere.map(\.id) == ["firewall-inactive"])
        #expect(d.level.isAlert)
    }

    @Test func minorNewIssueIsAtencao() {
        let prev = audit("2026-07-01T00:00:00Z", [])
        let cur  = audit("2026-07-15T00:00:00Z", [f("kernel-aslr", .low, "Config")])
        let d = DriftAnalysis.analyze(previous: prev, current: cur)
        #expect(d.level == .atencao)
        #expect(d.newSevere.isEmpty)            // low não é "severe"
        #expect(d.newIssuesCount == 1)
    }

    @Test func improvementIsMelhorou() {
        let prev = audit("2026-07-01T00:00:00Z", [f("firewall-inactive", .high)])
        let cur  = audit("2026-07-15T00:00:00Z", [f("firewall-inactive", .ok)])       // corrigiu
        let d = DriftAnalysis.analyze(previous: prev, current: cur)
        #expect(d.level == .melhorou)
        #expect(d.scoreDelta > 0)
        #expect(d.resolvedCount == 1)
        #expect(d.level.isAlert == false)
    }

    @Test func noChangeIsEstavel() {
        let same = [f("firewall-inactive", .high)]
        let d = DriftAnalysis.analyze(previous: audit("2026-07-01T00:00:00Z", same),
                                      current: audit("2026-07-15T00:00:00Z", same))
        #expect(d.level == .estavel)
        #expect(d.scoreDelta == 0)
    }
}
