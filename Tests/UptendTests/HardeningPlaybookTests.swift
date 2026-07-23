import Testing
import Foundation
@testable import UptendCore

struct HardeningPlaybookTests {
    private func f(_ id: String, _ sev: AuditSeverity, _ cat: String = "Segurança / SSH") -> AuditFinding {
        AuditFinding(id: id, title: id, severity: sev, category: cat, recommendation: "x")
    }
    private func audit(_ fs: [AuditFinding]) -> ExternalAudit {
        ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "admin"),
            collectedAt: "2026-07-22T00:00:00Z", host: .init(hostname: "srv", machineId: nil),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: fs, lynis: nil)
    }

    @Test func isAutoClassification() {
        #expect(HardeningPlaybook.isAuto("sudo systemctl enable --now fail2ban"))
        #expect(HardeningPlaybook.isAuto("sudo passwd -l <usuario>   # bloqueia") == false)  // placeholder
        #expect(HardeningPlaybook.isAuto("sudo visudo   # remova") == false)                  // interativo
        #expect(HardeningPlaybook.isAuto("Planeje a migração do SO") == false)                // descrição
    }

    @Test func generatesBackupRollbackAndFixes() {
        let s = HardeningPlaybook.generate(for: audit([
            f("ssh-root-login", .high), f("fail2ban-missing", .low), f("sudo-nopasswd", .medium, "Segurança / Contas")]))
        #expect(s.contains("uptend-hardening"))         // dir de backup
        #expect(s.contains("rollback"))                 // modo desfazer
        #expect(s.contains("PermitRootLogin"))          // fix automático do ssh-root-login
        #expect(s.contains("fail2ban"))                 // fix automático
        #expect(s.contains("CORREÇÕES MANUAIS"))        // sudo-nopasswd (visudo) vira nota manual
    }

    @Test func autoCountDedupsByControl() {
        // dois ids do MESMO controle (ssh-root-login e -ok) não contam em dobro
        let n = HardeningPlaybook.autoCount(for: audit([f("ssh-root-login", .high), f("firewall-inactive", .high, "Segurança / Rede")]))
        #expect(n == 2)
    }

    @Test func distroAwareCommands() {
        let fw = f("firewall-inactive", .high, "Segurança / Rede")
        #expect(RemediationMap.remediation(for: fw, family: .apt).command?.contains("ufw") == true)
        #expect(RemediationMap.remediation(for: fw, family: .dnf).command?.contains("firewall-cmd") == true)
        let mac = f("mac-inactive", .medium, "Segurança / Hardening")
        #expect(RemediationMap.remediation(for: mac, family: .apt).command?.contains("apparmor") == true)
        #expect(RemediationMap.remediation(for: mac, family: .dnf).command?.contains("setenforce") == true)
        // família derivada da distro
        #expect(OSFamily.from("rockylinux") == .dnf)
        #expect(OSFamily.from("ubuntu") == .apt)
        #expect(OSFamily.from("fedora") == .dnf)
    }

    @Test func playbookUsesDistroFamily() {
        func mk(_ distro: String) -> ExternalAudit {
            ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "admin"),
                collectedAt: "2026-07-22T00:00:00Z", host: .init(hostname: "srv", machineId: nil),
                machine: nil, os: .init(distro: distro, version: "9", pretty: distro, kernel: nil,
                    uptimeSeconds: nil, eolDate: nil, updatesTotal: nil, updatesSecurity: nil),
                disks: [], resources: nil, users: nil, docker: nil, profile: nil,
                findings: [f("firewall-inactive", .high, "Segurança / Rede"), f("fail2ban-missing", .low)], lynis: nil)
        }
        #expect(HardeningPlaybook.generate(for: mk("ubuntu")).contains("ufw"))
        let rocky = HardeningPlaybook.generate(for: mk("rockylinux"))
        #expect(rocky.contains("firewall-cmd") && rocky.contains("dnf install"))
        #expect(rocky.contains("família dnf"))
    }

    @Test func reportIsSelfContained() {
        let html = AuditReport.playbookHTML(audit([f("ssh-root-login", .high)]))
        #expect(html.contains("Playbook de Hardening"))
        #expect(html.contains("rollback"))
        #expect(html.contains("http://") == false && html.contains("https://") == false)
    }
}
