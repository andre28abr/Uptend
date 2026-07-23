import Testing
@testable import Uptend

/// Parsers do monitoramento (SIEM leve) — fixtures reais do uptend-lab.
struct SecurityMonitorTests {

    @Test func loginEventLevels() {
        #expect(SecurityMonitor.loginEvent(0).level == 0)
        #expect(SecurityMonitor.loginEvent(5).level == 1)
        #expect(SecurityMonitor.loginEvent(50).level == 2)
        #expect(SecurityMonitor.loginEvent(50).title.contains("50"))
    }

    @Test func parsesFail2banStatus() {
        // Saída real do uptend-lab (0 banimentos).
        let out = """
        Status for the jail: sshd
        |- Filter
        |  `- Total failed:\t0
        `- Actions
           |- Currently banned:\t0
           |- Total banned:\t0
           `- Banned IP list:\t
        """
        let e = SecurityMonitor.fail2banEvent(out)
        #expect(e?.level == 0)
        // com banimentos
        let out2 = out.replacingOccurrences(of: "Currently banned:\t0", with: "Currently banned:\t3")
        #expect(SecurityMonitor.fail2banEvent(out2)?.level == 1)
        #expect(SecurityMonitor.fail2banEvent(out2)?.detail.contains("3") == true)
        // não instalado → nil
        #expect(SecurityMonitor.fail2banEvent("bash: fail2ban-client: not found") == nil)
    }

    @Test func parsesFailedServices() {
        let out = """
        systemd-networkd-wait-online.service loaded failed failed Wait for Network to be Online
        systemd-resolved-monitor.socket      loaded failed failed Resolve Monitor Varlink Socket
        """
        let events = SecurityMonitor.failedServiceEvents(out)
        #expect(events.count == 2)
        #expect(events[0].title.contains("systemd-networkd-wait-online.service"))
        #expect(events.allSatisfy { $0.level == 2 && $0.category == "Serviços" })
    }

    @Test func fixesForKnownEvents() {
        #expect(SecurityMonitor.fix(for: "cfg-Firewall (ufw)")?.reversible == true)
        #expect(SecurityMonitor.fix(for: "cfg-Login por senha (SSH)")?.reversible == true)
        #expect(SecurityMonitor.fix(for: "cfg-Updates de segurança")?.reversible == false)  // apt upgrade não reverte
        #expect(SecurityMonitor.fix(for: "svc-nginx.service")?.applyArgs.last?.contains("restart nginx.service") == true)
        #expect(SecurityMonitor.fix(for: "disk-/dev/vdb1") == nil)   // disco cheio: decisão humana
        #expect(SecurityMonitor.fix(for: "logins") == nil)
        // trava: o conserto de firewall libera a 22 ANTES de ativar (não trancar o SSH)
        let fw = SecurityMonitor.fix(for: "cfg-Firewall (ufw)")!.applyArgs.last!
        #expect(fw.range(of: "allow 22")!.lowerBound < fw.range(of: "--force enable")!.lowerBound)
    }

    @Test func numberAfterLabel() {
        #expect(SecurityMonitor.number(after: "Currently banned:", in: "|- Currently banned:\t7") == 7)
        #expect(SecurityMonitor.number(after: "Total banned:", in: "sem isso") == nil)
    }
}
