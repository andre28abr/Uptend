import Foundation
import Darwin

/// Amostra CPU, memória e tráfego de rede em intervalos, mantendo um pequeno
/// histórico para os mini-gráficos. Tudo local (leitura de contadores do sistema).
@MainActor
final class MonitorService: ObservableObject {
    @Published var cpuUsage: Double = 0            // 0...1
    @Published var memUsed: UInt64 = 0
    @Published var memTotal: UInt64 = ProcessInfo.processInfo.physicalMemory
    @Published var downRate: Double = 0            // bytes/s
    @Published var upRate: Double = 0

    @Published var cpuHistory: [Double] = []
    @Published var memHistory: [Double] = []       // 0...1
    @Published var downHistory: [Double] = []
    @Published var upHistory: [Double] = []

    @Published var sessionDown: UInt64 = 0         // total baixado desde que o app abriu
    @Published var sessionUp: UInt64 = 0

    private let interval: Double = 1.5
    private let maxHistory = 40
    private var timer: Timer?
    private var prevCPU: (used: Double, total: Double)?
    private var prevNet: (rx: UInt64, tx: UInt64)?
    private var baseNet: (rx: UInt64, tx: UInt64)?

    var memFraction: Double { memTotal > 0 ? Double(memUsed) / Double(memTotal) : 0 }

    func start() {
        guard timer == nil else { return }
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
    }

    private func sample() {
        if let current = Self.cpuTicks() {
            if let previous = prevCPU {
                let usedDelta = current.used - previous.used
                let totalDelta = current.total - previous.total
                cpuUsage = totalDelta > 0 ? max(0, min(1, usedDelta / totalDelta)) : 0
            }
            prevCPU = current
        }

        if let used = Self.memoryUsed() { memUsed = used }

        let net = Self.netCounters()
        if let previous = prevNet {
            let down = net.rx >= previous.rx ? net.rx - previous.rx : 0
            let up = net.tx >= previous.tx ? net.tx - previous.tx : 0
            downRate = Double(down) / interval
            upRate = Double(up) / interval
        }
        prevNet = net
        if baseNet == nil { baseNet = net }
        if let base = baseNet {
            if net.rx >= base.rx { sessionDown = net.rx - base.rx }
            if net.tx >= base.tx { sessionUp = net.tx - base.tx }
        }

        push(&cpuHistory, cpuUsage)
        push(&memHistory, memFraction)
        push(&downHistory, downRate)
        push(&upHistory, upRate)
    }

    private func push(_ array: inout [Double], _ value: Double) {
        array.append(value)
        if array.count > maxHistory { array.removeFirst(array.count - maxHistory) }
    }

    // MARK: - Leitura de contadores (baixo nível)

    nonisolated static func cpuTicks() -> (used: Double, total: Double)? {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let user = Double(info.cpu_ticks.0)
        let system = Double(info.cpu_ticks.1)
        let idle = Double(info.cpu_ticks.2)
        let nice = Double(info.cpu_ticks.3)
        let used = user + system + nice
        return (used, used + idle)
    }

    nonisolated static func memoryUsed() -> UInt64? {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let pageSize = UInt64(vm_page_size)
        let active = UInt64(stats.active_count)
        let wired = UInt64(stats.wire_count)
        let compressed = UInt64(stats.compressor_page_count)
        return (active + wired + compressed) * pageSize
    }

    nonisolated static func netCounters() -> (rx: UInt64, tx: UInt64) {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0 else { return (0, 0) }
        defer { freeifaddrs(ifaddrPtr) }

        var rx: UInt64 = 0
        var tx: UInt64 = 0
        var pointer = ifaddrPtr
        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            guard let addr = current.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
            let name = String(cString: current.pointee.ifa_name)
            guard name != "lo0" else { continue }
            if let data = current.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) {
                rx += UInt64(data.pointee.ifi_ibytes)
                tx += UInt64(data.pointee.ifi_obytes)
            }
        }
        return (rx, tx)
    }

    // MARK: - Formatação (pura, testável)

    nonisolated static func formatRate(_ bytesPerSecond: Double) -> String {
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var value = max(0, bytesPerSecond)
        var index = 0
        while value >= 1024 && index < units.count - 1 {
            value /= 1024
            index += 1
        }
        return index == 0 ? "\(Int(value)) \(units[index])" : String(format: "%.1f %@", value, units[index])
    }
}
