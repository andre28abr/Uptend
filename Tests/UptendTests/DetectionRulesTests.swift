import Testing
import Foundation
@testable import UptendCore

struct DetectionRulesTests {
    private func f(_ id: String, _ sev: AuditSeverity, _ cat: String = "Segurança / SSH") -> AuditFinding {
        AuditFinding(id: id, title: id, severity: sev, category: cat, recommendation: "x")
    }
    private func audit(_ fs: [AuditFinding]) -> ExternalAudit {
        ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "admin"),
            collectedAt: "2026-07-22T00:00:00Z", host: .init(hostname: "h", machineId: nil),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: fs, lynis: nil)
    }

    @Test func bruteForceRuleWhenFail2banMissing() {
        let rules = DetectionRules.rules(for: audit([f("fail2ban-missing", .low)]))
        #expect(rules.contains { $0.key == "uptend-ssh-bruteforce" && $0.format == "sigma" && $0.mitre == "T1110" })
    }

    @Test func sensitiveFileRuleWhenAuditdMissing() {
        let rules = DetectionRules.rules(for: audit([f("auditd-missing", .medium, "Segurança / Logs")]))
        let r = rules.first { $0.key == "uptend-sensitive-file-read" }
        #expect(r?.format == "falco")
        #expect(r?.yaml.contains("/etc/shadow") == true)
    }

    @Test func cleanAuditGivesNoRules() {
        #expect(DetectionRules.rules(for: audit([f("firewall-ok", .ok, "Segurança / Rede")])).isEmpty)
    }

    @Test func bundleGroupsBySigmaAndFalco() {
        let rules = DetectionRules.rules(for: audit([
            f("fail2ban-missing", .low), f("auditd-missing", .medium, "Segurança / Logs")]))
        let b = DetectionRules.bundle(rules)
        #expect(b.contains("SIGMA"))
        #expect(b.contains("FALCO"))
        #expect(b.contains("attack.t1110"))
    }

    @Test func reportIsSelfContained() {
        let html = AuditReport.detectionRulesHTML(audit([f("ssh-root-login", .high)]))
        #expect(html.contains("Regras de Detecção"))
        #expect(html.contains("MITRE"))
        #expect(html.contains("http://") == false && html.contains("https://") == false)
    }
}
