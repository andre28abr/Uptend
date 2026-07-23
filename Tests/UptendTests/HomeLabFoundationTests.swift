import Testing
import Foundation
@testable import Uptend

/// Testes da fundação do HomeLab: modelo de host, armazenamento e parsers de Linux.
/// As fixtures são saídas REAIS capturadas do servidor de teste (uptend-lab, Ubuntu).
struct HomeLabFoundationTests {

    // MARK: RemoteHost

    @Test func validHostPasses() {
        let h = RemoteHost(name: "uptend-lab", kind: .server, address: "192.168.139.188",
                           user: "andresouza", port: 22, keyPath: "~/.ssh/uptend_lab_ed25519")
        #expect(h.isValid)
    }

    @Test func invalidHostsRejected() {
        func host(_ name: String, _ addr: String, _ user: String, _ port: Int, _ key: String) -> RemoteHost {
            RemoteHost(name: name, kind: .server, address: addr, user: user, port: port, keyPath: key)
        }
        #expect(host("", "1.2.3.4", "andre", 22, "~/.ssh/k").isValid == false)          // sem nome
        #expect(host("x", "não host!", "andre", 22, "~/.ssh/k").isValid == false)        // endereço inválido
        #expect(host("x", "1.2.3.4", "Andre Souza", 22, "~/.ssh/k").isValid == false)    // usuário com espaço
        #expect(host("x", "1.2.3.4", "andre", 0, "~/.ssh/k").isValid == false)           // porta inválida
        #expect(host("x", "1.2.3.4", "andre", 22, "../etc/passwd").isValid == false)     // path traversal na chave
        #expect(host("x", "1.2.3.4", "andre", 22, "-oProxyCommand=x").isValid == false)  // chave começando com -
    }

    @MainActor
    @Test func hostStoreAddRemovePersist() {
        let suite = UserDefaults(suiteName: "uptend.tests.\(UUID().uuidString)")!
        let store = HostStore(defaults: suite)
        let h = RemoteHost(name: "lab", kind: .server, address: "192.168.139.188",
                           user: "andresouza", port: 22, keyPath: "~/.ssh/uptend_lab_ed25519")
        #expect(store.add(h) == true)
        #expect(store.add(RemoteHost(name: "", kind: .server, address: "x", user: "a", port: 22, keyPath: "k")) == false)
        #expect(store.hosts(of: .server).count == 1)
        #expect(store.hosts(of: .homelab).isEmpty)

        let reloaded = HostStore(defaults: suite)
        #expect(reloaded.hosts.count == 1)

        store.remove(h)
        #expect(store.hosts.isEmpty)
    }

    // MARK: SSHRunner.shellQuote (evita quebra por espaço/tab no shell remoto)

    @Test func shellQuoteWrapsAndEscapes() {
        #expect(SSHRunner.shellQuote("docker") == "'docker'")
        // Formato com TAB fica num token só (era o bug do docker ps).
        #expect(SSHRunner.shellQuote("{{.Names}}\t{{.State}}") == "'{{.Names}}\t{{.State}}'")
        // Aspas simples internas são escapadas.
        #expect(SSHRunner.shellQuote("a'b") == "'a'\\''b'")
        // Metacaracteres viram literais (não são interpretados no remoto).
        #expect(SSHRunner.shellQuote("; rm -rf /") == "'; rm -rf /'")
    }

    // MARK: LinuxStats (fixtures reais do uptend-lab)

    @Test func parsesLoadAvg() {
        let r = LinuxStats.parseLoadAvg("0.58 0.88 0.84 1/821 5336")
        #expect(r?.one == 0.58)
        #expect(r?.five == 0.88)
        #expect(r?.fifteen == 0.84)
        #expect(LinuxStats.parseLoadAvg("lixo") == nil)
    }

    @Test func parsesAndFormatsUptime() {
        #expect(LinuxStats.parseUptimeSeconds("17366.52 129391.92") == 17366.52)
        #expect(LinuxStats.humanUptime(17366.52) == "4h 49m")
        #expect(LinuxStats.humanUptime(86400 * 12 + 3600 * 3) == "12d 3h")
        #expect(LinuxStats.humanUptime(2700) == "45m")
    }

    @Test func parsesMemUsedFraction() {
        let meminfo = """
        MemTotal:        8197712 kB
        MemFree:         3104156 kB
        MemAvailable:    4408192 kB
        Buffers:             140 kB
        Cached:          1441736 kB
        """
        let f = LinuxStats.parseMemUsedFraction(meminfo)!
        // usado = 8197712 - 4408192 = 3789520 → ~0,462
        #expect(abs(f - 0.4622) < 0.001)
        #expect(LinuxStats.parseMemUsedFraction("lixo") == nil)
    }

    @Test func parsesDiskRoot() {
        let df = """
        Filesystem     1024-blocks     Used Available Capacity Mounted on
        /dev/vdb1        584919888 15902620 569017268       3% /
        """
        let d = LinuxStats.parseDiskRoot(df)!
        #expect(d.totalKB == 584919888)
        #expect(d.usedKB == 15902620)
        #expect(abs(d.usedFraction - 0.0272) < 0.001)
        #expect(LinuxStats.parseDiskRoot("só cabeçalho") == nil)
    }

    @Test func parsesAndComputesCPU() {
        let a = LinuxStats.parseCPUSample("cpu  707967 13283 170818 12939549 2723 0 25593 0 0 0")!
        // idle = 12939549 + 2723 = 12942272
        #expect(a.idle == 12942272)
        // segunda amostra: +100 total, +40 idle → uso = 1 - 40/100 = 0,6
        let b = LinuxStats.CPUSample(idle: a.idle + 40, total: a.total + 100)
        #expect(abs(LinuxStats.cpuUsage(from: a, to: b) - 0.6) < 0.0001)
        #expect(LinuxStats.parseCPUSample("sem cpu aqui") == nil)
    }

    @Test func cpuTotalExcludesGuestFields() {
        // guest/guest_nice (9º/10º campos) já estão contidos em user/nice — somá-los
        // contaria em dobro e distorceria o total. Só os 8 primeiros contam.
        let s = LinuxStats.parseCPUSample("cpu  100 0 0 0 0 0 0 0 500 500")!
        #expect(s.total == 100)   // 100 (user) + zeros; guest=500/guest_nice=500 ignorados
    }
}
