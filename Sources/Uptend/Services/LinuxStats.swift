import Foundation

/// Parsers puros da saída de comandos Linux (para a "Visão geral" do HomeLab).
/// Sem rede/estado — testáveis com fixtures reais capturadas do servidor.
enum LinuxStats {

    // MARK: /proc/loadavg  →  "0.58 0.88 0.84 1/821 5336"

    static func parseLoadAvg(_ output: String) -> (one: Double, five: Double, fifteen: Double)? {
        let parts = output.split(whereSeparator: { $0 == " " || $0 == "\n" })
        guard parts.count >= 3,
              let a = Double(parts[0]), let b = Double(parts[1]), let c = Double(parts[2]) else { return nil }
        return (a, b, c)
    }

    // MARK: /proc/uptime  →  "17366.52 129391.92"

    static func parseUptimeSeconds(_ output: String) -> Double? {
        Double(output.split(whereSeparator: { $0 == " " || $0 == "\n" }).first ?? "")
    }

    /// Segundos → texto amigável: "45m", "4h 49m", "12d 3h".
    static func humanUptime(_ seconds: Double) -> String {
        let total = Int(seconds)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    // MARK: /proc/meminfo  →  "MemTotal: 8197712 kB\nMemAvailable: 4408192 kB\n…"

    /// Fração de memória em uso (0…1), via MemTotal e MemAvailable.
    static func parseMemUsedFraction(_ output: String) -> Double? {
        var total: Int64?
        var available: Int64?
        for raw in output.split(whereSeparator: \.isNewline) {
            let line = String(raw)
            if line.hasPrefix("MemTotal:") { total = kilobytes(line) }
            else if line.hasPrefix("MemAvailable:") { available = kilobytes(line) }
        }
        guard let total, total > 0, let available else { return nil }
        let used = max(total - available, 0)
        return Double(used) / Double(total)
    }

    private static func kilobytes(_ line: String) -> Int64? {
        // "MemTotal:        8197712 kB" → 8197712
        line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            .compactMap { Int64($0) }.first
    }

    // MARK: df -P /  →  cabeçalho + "…  584919888 15902620 569017268  3% /"

    /// Uso do disco raiz: fração (0…1) e tamanhos em KB (1024-blocks).
    static func parseDiskRoot(_ output: String) -> (usedFraction: Double, usedKB: Int64, totalKB: Int64)? {
        let lines = output.split(whereSeparator: \.isNewline)
        guard lines.count >= 2 else { return nil }
        let fields = lines[1].split(whereSeparator: { $0 == " " || $0 == "\t" })
        guard fields.count >= 4, let total = Int64(fields[1]), let used = Int64(fields[2]), total > 0 else { return nil }
        return (Double(used) / Double(total), used, total)
    }

    // MARK: /proc/stat cpu  →  "cpu  707967 13283 170818 12939549 2723 0 25593 0 0 0"

    struct CPUSample: Equatable { let idle: Int64; let total: Int64 }

    static func parseCPUSample(_ output: String) -> CPUSample? {
        guard let line = output.split(whereSeparator: \.isNewline).first(where: { $0.hasPrefix("cpu ") }) else { return nil }
        let nums = line.split(whereSeparator: { $0 == " " }).compactMap { Int64($0) }
        // user nice system idle iowait irq softirq steal guest guest_nice
        guard nums.count >= 5 else { return nil }
        let idle = nums[3] + nums[4]                 // idle + iowait
        // Só os 8 primeiros campos: guest/guest_nice (9º/10º) já estão contidos em
        // user/nice, então somá-los contaria em dobro.
        let total = nums.prefix(8).reduce(0, +)
        return CPUSample(idle: idle, total: total)
    }

    /// Uso de CPU (0…1) entre duas amostras de /proc/stat.
    static func cpuUsage(from a: CPUSample, to b: CPUSample) -> Double {
        let totalDelta = b.total - a.total
        let idleDelta = b.idle - a.idle
        guard totalDelta > 0 else { return 0 }
        return max(0, min(1, 1 - Double(idleDelta) / Double(totalDelta)))
    }
}
