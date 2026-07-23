import Foundation

struct BatteryInfo {
    var present = false
    var condition = "—"
    var cycles = "—"
    var maxCapacity = "—"
    var charge = "—"
}

struct DiskHealth: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let smart: String
}

/// Saúde do hardware: bateria (condição, ciclos, capacidade) e status SMART dos discos.
/// Leitura via `system_profiler` (somente leitura, sem sudo). É lento — sob demanda.
@MainActor
final class HealthService: ObservableObject {
    @Published var battery = BatteryInfo()
    @Published var disks: [DiskHealth] = []
    @Published var loading = false

    func load() async {
        loading = true
        defer { loading = false }

        let power = await Shell.capture("/usr/sbin/system_profiler", ["SPPowerDataType"])
        battery = Self.parseBattery(power.stdout)

        let nvme = await Shell.capture("/usr/sbin/system_profiler", ["SPNVMeDataType"])
        let sata = await Shell.capture("/usr/sbin/system_profiler", ["SPSerialATADataType"])
        disks = Self.parseDisks(nvme.stdout) + Self.parseDisks(sata.stdout)
    }

    // MARK: - Parsers (puros, testáveis)

    nonisolated private static func value(_ line: Substring) -> String {
        line.split(separator: ":", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) } ?? "—"
    }

    nonisolated static func parseBattery(_ output: String) -> BatteryInfo {
        var info = BatteryInfo()
        for line in output.split(whereSeparator: \.isNewline) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("Cycle Count:") { info.cycles = value(t[...]); info.present = true }
            else if t.hasPrefix("Condition:") { info.condition = value(t[...]) }
            else if t.hasPrefix("Maximum Capacity:") { info.maxCapacity = value(t[...]) }
            else if t.hasPrefix("State of Charge (%):") { info.charge = value(t[...]) + "%" }
        }
        return info
    }

    nonisolated static func parseDisks(_ output: String) -> [DiskHealth] {
        var result: [DiskHealth] = []
        var currentName = "Disco"
        let headers: Set<String> = ["NVMExpress", "SATA/SATA Express", "Serial-ATA"]
        for line in output.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("SMART Status:") {
                result.append(DiskHealth(name: currentName, smart: value(trimmed[...])))
            } else if trimmed.hasSuffix(":"), !String(trimmed.dropLast()).contains(":") {
                // Nome do dispositivo: linha que termina com ":" e não é cabeçalho de seção.
                let name = String(trimmed.dropLast())
                if !name.isEmpty && !headers.contains(name) { currentName = name }
            }
        }
        return result
    }
}
