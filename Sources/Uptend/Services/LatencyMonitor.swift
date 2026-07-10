import Foundation

/// Mede latência continuamente (ping) para avaliar a estabilidade da conexão.
@MainActor
final class LatencyMonitor: ObservableObject {
    @Published var history: [Double] = []   // ms (0 = perda)
    @Published var current: Double = 0
    @Published var average: Double = 0
    @Published var jitter: Double = 0
    @Published var lossPercent: Double = 0

    let host: String
    private var timer: Timer?
    private var samples: [Double?] = []      // nil = pacote perdido
    private let maxSamples = 40

    init(host: String = "1.1.1.1") {
        self.host = host
    }

    func start() {
        guard timer == nil else { return }
        Task { await tick() }
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() async {
        let out = await Shell.capture("/sbin/ping", ["-c", "1", "-t", "2", host])
        let ms = Self.parseTime(out.stdout)

        samples.append(ms)
        if samples.count > maxSamples { samples.removeFirst(samples.count - maxSamples) }

        let ok = samples.compactMap { $0 }
        history = samples.map { $0 ?? 0 }
        if let ms { current = ms }
        average = ok.isEmpty ? 0 : ok.reduce(0, +) / Double(ok.count)
        jitter = Self.stddev(ok)
        lossPercent = samples.isEmpty ? 0 : Double(samples.filter { $0 == nil }.count) / Double(samples.count) * 100
    }

    nonisolated static func parseTime(_ output: String) -> Double? {
        guard let range = output.range(of: "time=") else { return nil }
        let rest = output[range.upperBound...]
        let number = rest.prefix { $0.isNumber || $0 == "." }
        return Double(number)
    }

    nonisolated static func stddev(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return variance.squareRoot()
    }
}
