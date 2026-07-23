import SwiftUI

/// Bateria & Energia: saúde da bateria e apps que mais consomem.
struct EnergyView: View {
    let sub: SubSection?
    @StateObject private var energy = EnergyService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch sub?.id {
                case "consumption": consumptionContent
                default: batteryContent
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
        .task { await energy.refresh() }
    }

    // MARK: Bateria

    private var batteryContent: some View {
        Group {
            ScreenHeader(title: "Bateria", subtitle: energy.battery.hasBattery ? stateLabel : "Sem bateria (desktop?)") {
                if energy.loading { ProgressView().controlSize(.small) }
                IconButton(systemImage: "arrow.clockwise", help: "Atualizar") { Task { await energy.refresh() } }
            }

            if energy.battery.hasBattery {
                let b = energy.battery
                Gauge(value: Double(b.charge), in: 0...100) {
                    Text("Carga")
                } currentValueLabel: {
                    Text("\(b.charge)%")
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(b.charge < 20 ? .red : (b.charge < 50 ? .orange : .green))
                .padding(16).frame(maxWidth: .infinity).cardBackground()

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                    tile("Condição", b.condition, "heart.text.square",
                         help: "\"Normal\" = bateria saudável. \"Service Recommended\" = considere trocar.")
                    tile("Capacidade máxima", b.maxCapacity, "battery.75percent",
                         help: "Quanto a bateria segura hoje vs. quando era nova. Abaixo de ~80% já perdeu bastante.")
                    tile("Ciclos", b.cycleCount, "arrow.triangle.2.circlepath",
                         help: "Quantas cargas completas a bateria já teve. Macs modernos aguentam ~1000.")
                    if !b.timeRemaining.isEmpty {
                        tile("Tempo restante", b.timeRemaining.replacingOccurrences(of: " remaining", with: ""),
                             "clock", help: "Estimativa no ritmo de uso atual.")
                    }
                }
            } else {
                ContentUnavailableView("Sem bateria detectada", systemImage: "bolt.slash",
                    description: Text("Este Mac parece não ter bateria (ex.: um Mac de mesa)."))
                    .padding(.top, 30)
            }
        }
    }

    // MARK: Consumo

    private var consumptionContent: some View {
        Group {
            ScreenHeader(title: "Consumo de energia", subtitle: "Apps que mais usam o processador agora") {
                if energy.loading { ProgressView().controlSize(.small) }
                IconButton(systemImage: "arrow.clockwise", help: "Atualizar") { Task { await energy.refresh() } }
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle").foregroundStyle(.blue)
                Text("Quanto mais um app usa o processador, mais energia e bateria ele gasta. Esta lista mostra os maiores consumidores neste instante.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()

            if energy.topProcesses.isEmpty {
                Text("Nada consumindo de forma relevante.").foregroundStyle(.secondary).padding(.top, 8)
            } else {
                let maxCPU = energy.topProcesses.map(\.cpu).max() ?? 1
                VStack(spacing: 8) {
                    ForEach(energy.topProcesses) { proc in
                        CardRow {
                            HStack(spacing: 10) {
                                Image(systemName: "cpu").foregroundStyle(proc.cpu > 50 ? .orange : .secondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(proc.name).fontWeight(.medium)
                                    GeometryReader { geo in
                                        Capsule().fill(.quaternary)
                                            .overlay(alignment: .leading) {
                                                Capsule().fill(Color.accentColor)
                                                    .frame(width: geo.size.width * min(proc.cpu / maxCPU, 1))
                                            }
                                    }.frame(height: 5)
                                }
                            }
                        } trailing: {
                            Text(String(format: "%.0f%%", proc.cpu)).font(.callout).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var stateLabel: String {
        switch energy.battery.state {
        case "charging", "finishing charge": "Carregando"
        case "discharging": "Na bateria"
        case "charged": "Carregada"
        case "ac attached": "Na tomada"
        default: "\(energy.battery.charge)%"
        }
    }

    private func tile(_ title: String, _ value: String, _ icon: String, help: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(.secondary)
            Text(value.isEmpty ? "—" : value).font(.system(size: 18, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
        .tip(help)
    }
}
