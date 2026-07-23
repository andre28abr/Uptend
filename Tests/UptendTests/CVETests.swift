import Testing
import Foundation
@testable import UptendCore

struct CVETests {

    private func sw(_ name: String, _ version: String, _ source: String? = "host") -> ExternalAudit.SoftwarePackage {
        .init(name: name, version: version, source: source)
    }

    // MARK: Comparador de versões

    @Test func parseHandlesFormats() {
        #expect(CVEMatcher.parse("9.6p1") == [9, 6, 1])       // openssh: p → separador
        #expect(CVEMatcher.parse("1.0.1f") == [1, 0, 1, 6])   // openssl: letra f = 6
        #expect(CVEMatcher.parse("1.18.0") == [1, 18, 0])
        #expect(CVEMatcher.parse("2.4.52") == [2, 4, 52])
    }

    @Test func compareOrdersCorrectly() {
        #expect(CVEMatcher.compare(CVEMatcher.parse("9.6p1"), CVEMatcher.parse("9.8p1")) == -1)
        #expect(CVEMatcher.compare(CVEMatcher.parse("1.0.1g"), CVEMatcher.parse("1.0.1f")) == 1)
        #expect(CVEMatcher.compare(CVEMatcher.parse("2.4.51"), CVEMatcher.parse("2.4.51")) == 0)
        #expect(CVEMatcher.compare(CVEMatcher.parse("1.21.0"), CVEMatcher.parse("1.21")) == 0)   // padding com 0
    }

    @Test func rangeInclusiveIntroducedExclusiveFixed() {
        let r = CVE.Range("2.4.49", "2.4.50")
        #expect(CVEMatcher.inRange("2.4.49", r) == true)     // introduced inclusive
        #expect(CVEMatcher.inRange("2.4.50", r) == false)    // fixed exclusive
        #expect(CVEMatcher.inRange("2.4.48", r) == false)
    }

    // MARK: Cruzamento

    @Test func regreSSHionMatchesVulnerableOpenSSH() {
        let m = CVEMatcher.matches([sw("openssh", "9.6p1")])
        #expect(m.contains { $0.cve.id == "CVE-2024-6387" })
    }

    @Test func patchedOpenSSHDoesNotMatch() {
        let m = CVEMatcher.matches([sw("openssh", "9.8p1")])
        #expect(m.contains { $0.cve.id == "CVE-2024-6387" } == false)   // 9.8p1 = corrigido
    }

    @Test func heartbleedRangeBoundaries() {
        #expect(CVEMatcher.matches([sw("openssl", "1.0.1f")]).contains { $0.cve.id == "CVE-2014-0160" })
        #expect(CVEMatcher.matches([sw("openssl", "1.0.1g")]).contains { $0.cve.id == "CVE-2014-0160" } == false)
    }

    @Test func sudoBaronSameditMultiRange() {
        #expect(CVEMatcher.matches([sw("sudo", "1.9.5p1")]).contains { $0.cve.id == "CVE-2021-3156" })
        #expect(CVEMatcher.matches([sw("sudo", "1.9.5p2")]).contains { $0.cve.id == "CVE-2021-3156" } == false)
        #expect(CVEMatcher.matches([sw("sudo", "1.8.20")]).contains { $0.cve.id == "CVE-2021-3156" })
    }

    @Test func severityDerivedFromCVSS() {
        let apache41773 = CVEDatabase.all.first { $0.id == "CVE-2021-42013" }!
        #expect(apache41773.severity == .critical)   // 9.8
        let heartbleed = CVEDatabase.all.first { $0.id == "CVE-2014-0160" }!
        #expect(heartbleed.severity == .high)         // 7.5
    }

    @Test func dockerImagesBecomeSoftware() {
        let audit = ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "admin"),
            collectedAt: "2026-07-21T00:00:00Z", host: .init(hostname: "h", machineId: nil),
            machine: nil, os: nil, disks: [], resources: nil, users: nil,
            docker: .init(installed: true, running: 1, total: 1, containers: [
                .init(name: "web", image: "library/nginx:1.18.0", state: "running", status: "up")]),
            profile: nil, findings: [], lynis: nil)
        let derived = CVEMatcher.softwareFromDocker(audit)
        #expect(derived.first?.name == "nginx")
        #expect(derived.first?.version == "1.18.0")
        #expect(CVEMatcher.matches(for: audit).contains { $0.cve.id == "CVE-2021-23017" })  // nginx 1.18 vulnerável
    }

    @Test func reportIsSelfContained() {
        let audit = ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "admin"),
            collectedAt: "2026-07-21T00:00:00Z", host: .init(hostname: "h", machineId: nil),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: [], lynis: nil, software: [sw("openssh", "9.6p1")])
        let html = AuditReport.cveHTML(audit)
        #expect(html.contains("Vulnerabilidades Conhecidas"))
        #expect(html.contains("CVE-2024-6387"))
        #expect(html.contains("backport"))       // aviso de honestidade presente
        #expect(html.contains("http://") == false && html.contains("https://") == false)
    }
}
