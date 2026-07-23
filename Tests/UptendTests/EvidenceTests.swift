import Testing
import Foundation
@testable import UptendCore

struct EvidenceTests {

    private func loadFixture() throws -> ExternalAudit {
        let url = try #require(Bundle.module.url(forResource: "lab-audit", withExtension: "json", subdirectory: "Fixtures"))
        return try ExternalAuditParser.parse(Data(contentsOf: url))
    }

    @Test func fixtureCarriesRawEvidence() throws {
        let audit = try loadFixture()
        #expect(audit.findings.contains { ($0.evidenceRaw?.isEmpty == false) })
    }

    @Test func technicalReportShowsCollapsibleEvidence() throws {
        let audit = try loadFixture()
        let html = AuditReport.html(audit)
        #expect(html.contains("<details"))
        #expect(html.contains("Ver evidência"))
    }

    @Test func markdownIncludesEvidenceBlock() throws {
        let audit = try loadFixture()
        let md = AuditReport.markdown(audit)
        #expect(md.contains("**Evidência:**"))
    }

    @Test func rawEvidenceIsHTMLEscaped() {
        let f = AuditFinding(id: "ssh-root-login", title: "t", severity: .high, category: "SSH",
                             evidenceRaw: "linha1\n<script>alert(1)</script>")
        let audit = ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "admin"),
            collectedAt: "2026-07-21T00:00:00Z", host: .init(hostname: "h", machineId: nil),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: [f], lynis: nil)
        let html = AuditReport.html(audit)
        #expect(html.contains("<script>alert(1)</script>") == false)
        #expect(html.contains("&lt;script&gt;"))
    }

    @Test func absentRawEvidenceRendersNoDetails() {
        let f = AuditFinding(id: "ssh-root-login", title: "t", severity: .high, category: "SSH")
        let audit = ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "admin"),
            collectedAt: "2026-07-21T00:00:00Z", host: .init(hostname: "h", machineId: nil),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: [f], lynis: nil)
        #expect(AuditReport.html(audit).contains("Ver evidência") == false)
    }
}
