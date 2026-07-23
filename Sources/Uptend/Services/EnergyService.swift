import Foundation

struct BatteryInfo2: Sendable {
    var charge: Int = 0
    var state: String = "—"            // charging / discharging / charged / AC attached
    var timeRemaining: String = ""
    var cycleCount: String = "—"
    var condition: String = "—"
    var maxCapacity: String = "—"
    var hasBattery: Bool = false
}

struct ProcInfo: Identifiable, Sendable, Hashable {
    let name: String
    let cpu: Double
    var id: String { name }
}

/// Lê saúde da bateria (`pmset`, `system_profiler`) e os processos que mais
/// consomem CPU/energia (`ps`). Tudo leitura, sem sudo.
@MainActor
final class EnergyService: ObservableObject {
    @Published var battery = BatteryInfo2()
    @Published var topProcesses: [ProcInfo] = []
    @Published var loading = false

    func refresh() async {
        loading = true
        defer { loading = false }
        async let battC = Shell.capture("/usr/bin/pmset", ["-g", "batt"])
        async let powerC = Shell.capture("/usr/sbin/system_profiler", ["SPPowerDataType"])
        async let psC = Shell.capture("/bin/ps", ["-A", "-r", "-o", "%cpu,comm"])
        let batt = await battC, power = await powerC, ps = await psC

        var info = Self.parsePmset(batt.stdout)
        info.cycleCount = Self.value(power.stdout, "Cycle Count")
        info.condition = Self.value(power.stdout, "Condition")
        info.maxCapacity = Self.value(power.stdout, "Maximum Capacity")
        info.hasBattery = batt.stdout.contains("InternalBattery") || !info.cycleCount.isEmpty
        battery = info
        topProcesses = Self.parseTopProcesses(ps.stdout, limit: 8)
    }

    // MARK: Parsers (puros, testáveis)

    nonisolated static func parsePmset(_ output: String) -> BatteryInfo2 {
        var info = BatteryInfo2()
        if let r = output.range(of: "\\d+%", options: .regularExpression) {
            info.charge = Int(output[r].dropLast()) ?? 0
        }
        // Ordem importa: "discharging" contém "charging".
        let lower = output.lowercased()
        for s in ["discharging", "finishing charge", "charging", "charged", "ac attached"] where lower.contains(s) {
            info.state = s; break
        }
        if let r = output.range(of: "\\d+:\\d\\d remaining", options: .regularExpression) {
            info.timeRemaining = String(output[r])
        } else if lower.contains("no estimate") {
            info.timeRemaining = "calculando…"
        }
        return info
    }

    nonisolated static func value(_ output: String, _ key: String) -> String {
        for raw in output.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix(key), let colon = line.firstIndex(of: ":") {
                return line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }

    /// Lê `ps -A -r -o %cpu,comm` (ordenado por CPU): [(nome do app, %cpu)].
    nonisolated static func parseTopProcesses(_ output: String, limit: Int) -> [ProcInfo] {
        var result: [ProcInfo] = []
        for raw in output.split(whereSeparator: \.isNewline).dropFirst() {   // pula o cabeçalho
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard let space = line.firstIndex(of: " ") else { continue }
            guard let cpu = Double(line[..<space]) else { continue }
            let comm = line[line.index(after: space)...].trimmingCharacters(in: .whitespaces)
            let name = URL(fileURLWithPath: String(comm)).lastPathComponent
            guard !name.isEmpty, cpu > 0.1 else { continue }
            result.append(ProcInfo(name: name, cpu: cpu))
            if result.count >= limit { break }
        }
        return result
    }
}
