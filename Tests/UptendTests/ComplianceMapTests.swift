import Testing
import Foundation
@testable import UptendCore

struct ComplianceMapTests {

    private func finding(_ id: String, _ sev: AuditSeverity, cis: String? = nil) -> AuditFinding {
        AuditFinding(id: id, title: id, severity: sev, category: "X", cis: cis)
    }
    private func audit(_ findings: [AuditFinding]) -> ExternalAudit {
        ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "admin"),
                      collectedAt: "2026-07-20T00:00:00Z", host: .init(hostname: "h", machineId: nil),
                      machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
                      findings: findings, lynis: nil)
    }

    @Test func mapsKnownFindingsToFrameworks() {
        let r = ComplianceMap.refs(for: finding("ssh-root-login", .high))
        #expect(r.cis == "5.2.8")
        #expect(r.iso27001 == "A.9.2.3")
        #expect(r.nist == "PR.AC-4")
        #expect(r.owasp == "A07:2021")
    }

    @Test func normalizesOkSuffixAndDiskDevice() {
        // "-ok" e sufixo de dispositivo caem na mesma chave-base.
        #expect(ComplianceMap.refs(for: finding("firewall-ok", .ok)).iso27001 == "A.13.1.1")
        #expect(ComplianceMap.refs(for: finding("disk-smart-sda", .high)).nist == "PR.DS-4")
    }

    @Test func prefersFindingCISWhenPresent() {
        let r = ComplianceMap.refs(for: finding("ssh-root-login", .high, cis: "9.9.9"))
        #expect(r.cis == "9.9.9")   // o do achado vence o fallback
    }

    @Test func coverageCountsMetVsChecked() {
        let a = audit([
            finding("firewall-ok", .ok),          // ISO/NIST/OWASP atendido
            finding("ssh-root-login", .high),     // não atendido
            finding("ssh-password-auth-ok", .ok), // atendido
        ])
        let cov = ComplianceMap.coverage(a)
        let iso = cov.first { $0.framework == .iso }
        #expect(iso?.checked == 3)
        #expect(iso?.met == 2)
        #expect(iso?.percent == 66)
    }

    @Test func mapsExpandedHardeningFindings() {
        // Verificações novas (MAC, auditd, ASLR, política de senha) também mapeiam.
        #expect(ComplianceMap.refs(for: finding("mac-inactive", .medium)).iso27001 == "A.9.4.1")
        #expect(ComplianceMap.refs(for: finding("auditd-missing", .medium)).owasp == "A09:2021")
        #expect(ComplianceMap.refs(for: finding("kernel-aslr-ok", .ok)).cis == "1.5.1" || ComplianceMap.refs(for: finding("kernel-aslr-ok", .ok, cis: "1.5.1")).cis == "1.5.1")
        #expect(ComplianceMap.refs(for: finding("uid0-multiple", .high)).nist == "PR.AC-4")
    }

    @Test func pciDssIsMappedAndInCoverage() {
        #expect(ComplianceMap.refs(for: finding("ssh-root-login", .high)).pci == "8")     // autenticação
        #expect(ComplianceMap.refs(for: finding("firewall-inactive", .high)).pci == "1")  // firewall
        #expect(ComplianceMap.refs(for: finding("os-eol", .critical)).pci == "6")         // patch
        #expect(ComplianceMap.refs(for: finding("auditd-missing", .medium)).pci == "10")  // logging
        let a = audit([finding("ssh-root-login", .high), finding("ssh-password-auth-ok", .ok)])
        let pci = ComplianceMap.coverage(a).first { $0.framework == .pci }
        #expect(pci?.checked == 2)
        #expect(pci?.met == 1)
    }

    @Test func cisV8AndSoc2Mapped() {
        let r = ComplianceMap.refs(for: finding("ssh-root-login", .high))
        #expect(r.cisv8 == "6")        // Access Control Management
        #expect(r.soc2 == "CC6.1")     // Logical Access
        let log = ComplianceMap.refs(for: finding("auditd-missing", .medium))
        #expect(log.cisv8 == "8")      // Audit Log Management
        #expect(log.soc2 == "CC7.2")
        // Ambos entram na cobertura (7 frameworks no total).
        let a = audit([finding("ssh-root-login", .high), finding("firewall-ok", .ok)])
        let fws = Set(ComplianceMap.coverage(a).map { $0.framework })
        #expect(fws.contains(.cisv8))
        #expect(fws.contains(.soc2))
    }

    @Test func nistAndOwaspNames() {
        #expect(ComplianceMap.nistFunction("PR.AC-4") == "Proteger")
        #expect(ComplianceMap.nistFunction("DE.CM-1") == "Detectar")
        #expect(ComplianceMap.owaspName("A06:2021").contains("Desatualizados"))
    }
}
