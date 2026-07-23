import Testing
import Foundation
@testable import UptendCore

struct FleetRollupTests {

    private func f(_ id: String, _ sev: AuditSeverity, _ cat: String = "Segurança / Rede") -> AuditFinding {
        AuditFinding(id: id, title: id, severity: sev, category: cat, recommendation: "x")
    }
    private func audit(_ host: String, _ mid: String?, _ at: String, _ fs: [AuditFinding]) -> ExternalAudit {
        ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "admin"),
            collectedAt: at, host: .init(hostname: host, machineId: mid),
            machine: nil, os: .init(distro: "ubuntu", version: "24.04", pretty: "Ubuntu 24.04", kernel: nil,
                                    uptimeSeconds: nil, eolDate: nil, updatesTotal: nil, updatesSecurity: nil),
            disks: [], resources: nil, users: nil, docker: nil, profile: nil, findings: fs, lynis: nil)
    }

    @Test func latestPerHostDedupsByDate() {
        let a = [
            audit("srv1", "m1", "2026-07-01T00:00:00Z", [f("x", .high)]),
            audit("srv1", "m1", "2026-07-20T00:00:00Z", [f("x", .ok)]),   // mais nova
            audit("srv2", "m2", "2026-07-10T00:00:00Z", [f("y", .medium)]),
        ]
        let latest = FleetRollup.latestPerHost(a)
        #expect(latest.count == 2)
        let srv1 = latest.first { $0.host.hostname == "srv1" }!
        #expect(srv1.collectedAt == "2026-07-20T00:00:00Z")   // ficou a mais recente
    }

    @Test func distinctMachineIdsAreNotMerged() {
        // Regressão A1: dois hosts físicos com o MESMO hostname (VMs clonadas) mas
        // machineId diferente devem contar como DOIS hosts. Antes, machineId vinha
        // sempre nil e o hostKey caía no hostname → um host sumia da frota.
        let a = [
            audit("localhost", "maq-A", "2026-07-20T00:00:00Z", [f("x", .high)]),
            audit("localhost", "maq-B", "2026-07-20T00:00:00Z", [f("y", .medium)]),
        ]
        #expect(FleetRollup.latestPerHost(a).count == 2)
        #expect(FleetRollup.hostKey(a[0]) == "maq-A")   // prefere o machineId
        #expect(FleetRollup.hostKey(a[0]) != FleetRollup.hostKey(a[1]))
    }

    @Test func rollupSortsWorstFirstAndAverages() {
        let a = [
            audit("bom", "m1", "2026-07-20T00:00:00Z", [f("a", .ok)]),                 // nota alta
            audit("ruim", "m2", "2026-07-20T00:00:00Z", [f("b", .critical), f("c", .high)]),  // nota baixa
        ]
        let fleet = FleetRollup.rollup(a)
        #expect(fleet.hostCount == 2)
        #expect(fleet.hosts.first?.hostname == "ruim")     // pior primeiro
        #expect(fleet.hosts.first!.score <= fleet.hosts.last!.score)
        #expect(fleet.avgScore >= 0 && fleet.avgScore <= 100)
    }

    @Test func topFindingsCountsHostsAcrossFleet() {
        // "firewall-inactive" aberto em 2 dos 2 hosts
        let a = [
            audit("h1", "m1", "2026-07-20T00:00:00Z", [f("firewall-inactive", .high)]),
            audit("h2", "m2", "2026-07-20T00:00:00Z", [f("firewall-inactive", .high), f("ssh-root-login", .high, "Contas / SSH")]),
        ]
        let fleet = FleetRollup.rollup(a)
        let fw = fleet.topFindings.first { $0.baseKey == "firewall" }!
        #expect(fw.hostCount == 2)
        let ssh = fleet.topFindings.first { $0.baseKey == "ssh-root-login" }!
        #expect(ssh.hostCount == 1)
    }

    @Test func csvHasHeaderAndRows() {
        let a = [audit("h1", "m1", "2026-07-20T00:00:00Z", [f("x", .high)])]
        let csv = FleetRollup.csv(FleetRollup.rollup(a))
        #expect(csv.hasPrefix("host,so,coletado_em,nota,semaforo,criticos,altos,abertos"))
        #expect(csv.split(separator: "\n").count == 2)   // cabeçalho + 1 host
    }

    @Test func reportIsSelfContained() {
        let a = [
            audit("h1", "m1", "2026-07-20T00:00:00Z", [f("firewall-inactive", .high)]),
            audit("h2", "m2", "2026-07-20T00:00:00Z", [f("x", .ok)]),
        ]
        let html = AuditReport.fleetHTML(FleetRollup.rollup(a))
        #expect(html.contains("Relatório de Frota"))
        #expect(html.contains("Mapa de conformidade"))
        #expect(html.contains("http://") == false && html.contains("https://") == false)
    }
}
