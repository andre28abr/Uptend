import SwiftUI
import AppKit

/// Mini painel que aparece ao clicar no ícone da barra de menu.
struct MenuBarDashboard: View {
    @EnvironmentObject var monitor: MonitorService

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Uptend").font(.headline)

            metric(title: "CPU", value: "\(Int((monitor.cpuUsage * 100).rounded()))%",
                   history: monitor.cpuHistory, maxValue: 1, tint: .blue)

            metric(title: "Memória",
                   value: "\(Int((monitor.memFraction * 100).rounded()))% · \(FileUtils.label(Int64(monitor.memUsed)))",
                   history: monitor.memHistory, maxValue: 1, tint: .purple)

            HStack(spacing: 12) {
                netStat(title: "Baixando", rate: monitor.downRate, history: monitor.downHistory, tint: .blue)
                netStat(title: "Enviando", rate: monitor.upRate, history: monitor.upHistory, tint: .green)
            }

            Divider()

            HStack {
                Button("Abrir Uptend") { activateMainWindow() }
                Spacer()
                Button("Sair") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    private func metric(title: String, value: String, history: [Double], maxValue: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.callout).foregroundStyle(.secondary)
                Spacer()
                Text(value).font(.callout.monospacedDigit()).fontWeight(.medium)
            }
            Sparkline(values: history, tint: tint, maxValue: maxValue)
                .frame(height: 28)
        }
    }

    private func netStat(title: String, rate: Double, history: [Double], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(MonitorService.formatRate(rate)).font(.callout.monospacedDigit()).fontWeight(.medium)
            Sparkline(values: history, tint: tint)
                .frame(height: 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func activateMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
