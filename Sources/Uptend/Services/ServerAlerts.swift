import Foundation

// =============================================================================
// ALERTAS DO SERVIDOR — Passo 8 do módulo Servidor
// Vigilância PASSIVA: quando o usuário pede (botão no sino), checa cada host e
// levanta avisos (sem conexão, disco/memória altos, updates de segurança). Rede só
// na ação (nada automático no launch) — Privacy by Design.
// =============================================================================

struct ServerAlert: Identifiable {
    let id: String
    let hostID: UUID
    let kind: HostKind
    let text: String
    let level: Int              // 1 atenção · 2 problema
    let section: HomeLabSection // para onde navegar ao clicar
}

@MainActor
final class ServerAlertsService: ObservableObject {
    @Published var alerts: [ServerAlert] = []
    @Published var checking = false

    /// Checa todos os hosts e atualiza a lista de alertas.
    func check(_ hosts: [RemoteHost]) async {
        checking = true
        defer { checking = false }
        var found: [ServerAlert] = []
        for host in hosts {
            let ov = await HomeLabMonitor.overview(host)
            guard ov.reachable else {
                found.append(ServerAlert(id: "\(host.id)-down", hostID: host.id, kind: host.kind,
                                         text: "\(host.name): sem conexão", level: 2, section: .overview))
                continue
            }
            if let d = ov.diskUsed, d > 0.85 {
                found.append(ServerAlert(id: "\(host.id)-disk", hostID: host.id, kind: host.kind,
                                         text: "\(host.name): disco em \(Int((d * 100).rounded()))%",
                                         level: d > 0.95 ? 2 : 1, section: .storage))
            }
            if let m = ov.memUsed, m > 0.92 {
                found.append(ServerAlert(id: "\(host.id)-mem", hostID: host.id, kind: host.kind,
                                         text: "\(host.name): memória em \(Int((m * 100).rounded()))%",
                                         level: 1, section: .overview))
            }
            let sec = await SSHRunner.run(host, ["bash", "-lc", "apt list --upgradable 2>/dev/null | grep -c security"])
            if let n = Int(sec.stdout.trimmingCharacters(in: .whitespacesAndNewlines)), n > 0 {
                found.append(ServerAlert(id: "\(host.id)-sec", hostID: host.id, kind: host.kind,
                                         text: "\(host.name): \(n) update(s) de segurança pendentes",
                                         level: 2, section: .updates))
            }
        }
        alerts = found
    }
}
