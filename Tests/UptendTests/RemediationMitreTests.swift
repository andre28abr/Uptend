import Testing
import Foundation
@testable import UptendCore

struct RemediationMitreTests {

    private func finding(_ id: String, _ sev: AuditSeverity) -> AuditFinding {
        AuditFinding(id: id, title: id, severity: sev, category: "X")
    }

    @Test func remediationHasCommandsAndEffort() {
        let r = RemediationMap.remediation(for: finding("ssh-root-login", .high))
        #expect(r.command?.contains("PermitRootLogin") == true)
        #expect(r.effort == .quick)
        let eol = RemediationMap.remediation(for: finding("os-eol", .critical))
        #expect(eol.effort == .project)
        // Chave de disco (com sufixo de dispositivo) normaliza e acha o comando.
        #expect(RemediationMap.remediation(for: finding("disk-smart-sda", .high)).command != nil)
    }

    @Test func mitreMapsAttackTechniques() {
        let t = MitreMap.technique(for: finding("ssh-root-login", .high))
        #expect(t?.id == "T1078")
        #expect(t?.tactic == "Acesso Inicial")
        #expect(MitreMap.technique(for: finding("auditd-missing", .medium))?.id == "T1562.006")
        #expect(MitreMap.technique(for: finding("disk-space-root", .high)) == nil)   // disponibilidade não é técnica
    }

    @Test func nistFunctionCoverageGroups() {
        let a = ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "admin"),
            collectedAt: "2026-07-20T00:00:00Z", host: .init(hostname: "h", machineId: nil),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: [finding("auditd-missing", .medium), finding("fail2ban-missing", .low), finding("firewall-ok", .ok)],
            lynis: nil)
        let cov = ComplianceMap.nistFunctionCoverage(a)
        let detectar = cov.first { $0.function == "Detectar" }
        #expect(detectar?.checked == 2)   // auditd + fail2ban = DE.CM
        #expect(detectar?.met == 0)
    }

    @Test func maturityBands() {
        #expect(AuditReport.maturity(90).level == "Otimizado")
        #expect(AuditReport.maturity(70).level == "Gerenciado")
        #expect(AuditReport.maturity(50).level == "Básico")
        #expect(AuditReport.maturity(20).level == "Inicial")
    }
}
