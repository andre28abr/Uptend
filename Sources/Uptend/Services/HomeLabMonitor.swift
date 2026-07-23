import Foundation

/// Instantâneo de saúde de um host remoto (para a "Visão geral").
struct RemoteOverview: Sendable {
    var reachable = false
    var error: String?
    var cpuUsed: Double?     // 0…1
    var memUsed: Double?     // 0…1
    var diskUsed: Double?    // 0…1
    var uptime: String?
    var load1: Double?       // carga de 1 minuto
}

/// Lê estatísticas de um host Linux via SSH e monta o `RemoteOverview`.
/// Só comandos FIXOS (sem entrada do usuário) — leitura de /proc e `df`.
enum HomeLabMonitor {

    static func overview(_ host: RemoteHost) async -> RemoteOverview {
        var o = RemoteOverview()

        // Dispara as leituras em paralelo.
        async let loadC = SSHRunner.run(host, ["cat", "/proc/loadavg"])
        async let upC = SSHRunner.run(host, ["cat", "/proc/uptime"])
        async let memC = SSHRunner.run(host, ["cat", "/proc/meminfo"])
        async let dfC = SSHRunner.run(host, ["df", "-P", "/"])
        async let cpu1C = SSHRunner.run(host, ["cat", "/proc/stat"])

        let load = await loadC
        guard load.ok else {
            o.error = (load.stderr.isEmpty ? load.stdout : load.stderr)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return o          // não alcançável / erro de conexão
        }
        o.reachable = true
        o.load1 = LinuxStats.parseLoadAvg(load.stdout)?.one
        if let s = LinuxStats.parseUptimeSeconds((await upC).stdout) {
            o.uptime = LinuxStats.humanUptime(s)
        }
        o.memUsed = LinuxStats.parseMemUsedFraction((await memC).stdout)
        o.diskUsed = LinuxStats.parseDiskRoot((await dfC).stdout)?.usedFraction

        // CPU: duas amostras de /proc/stat com um pequeno intervalo.
        if let c1 = LinuxStats.parseCPUSample((await cpu1C).stdout) {
            try? await Task.sleep(nanoseconds: 350_000_000)
            let cpu2 = await SSHRunner.run(host, ["cat", "/proc/stat"])
            if let c2 = LinuxStats.parseCPUSample(cpu2.stdout) {
                o.cpuUsed = LinuxStats.cpuUsage(from: c1, to: c2)
            }
        }
        return o
    }
}
