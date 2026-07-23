import SwiftUI
import AppKit

// MARK: - Saúde (bateria e SSD)

struct HealthView: View {
    @StateObject private var health = HealthService()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScreenHeader(title: "Saúde", subtitle: health.loading ? "Verificando…" : "Bateria e discos") {
                if health.loading { ProgressView().controlSize(.small) }
                IconButton(systemImage: "arrow.clockwise", help: "Verificar") { Task { await health.load() } }
            }

            if health.battery.present {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                    tile("Condição", health.battery.condition, "heart")
                    tile("Ciclos", health.battery.cycles, "arrow.triangle.2.circlepath")
                    tile("Capacidade máx.", health.battery.maxCapacity, "battery.100")
                    tile("Carga", health.battery.charge, "bolt")
                }
            } else {
                CardRow {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.slash").foregroundStyle(.secondary)
                        Text("Sem bateria (Mac de mesa)").foregroundStyle(.secondary)
                    }
                } trailing: { EmptyView() }
            }

            if !health.disks.isEmpty {
                Text("Discos (SMART)").font(.headline).padding(.top, 4)
                ForEach(health.disks) { disk in
                    CardRow {
                        HStack(spacing: 10) {
                            Image(systemName: "internaldrive").foregroundStyle(.secondary)
                            Text(disk.name).fontWeight(.medium)
                        }
                    } trailing: {
                        let ok = disk.smart.localizedCaseInsensitiveContains("Verified")
                        Label(disk.smart, systemImage: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(ok ? .green : .orange).font(.callout)
                    }
                }
            }
        }
        .task { await health.load() }
    }

    private func tile(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(.secondary)
            Text(value).fontWeight(.medium).lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}

// MARK: - Modo foco

struct FocusView: View {
    @StateObject private var focus = FocusService()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScreenHeader(title: "Modo foco", subtitle: "Limpe a mesa e reduza distrações")

            CardRow {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Modo foco").fontWeight(.medium)
                    Text("Oculta os ícones da Mesa e ativa o Dock automático (reversível).")
                        .font(.callout).foregroundStyle(.secondary)
                }
            } trailing: {
                Toggle("", isOn: Binding(get: { focus.enabled }, set: { on in Task { await focus.setEnabled(on) } }))
                    .toggleStyle(.switch).labelsHidden()
            }

            Button {
                focus.openFocusSettings()
            } label: {
                Label("Abrir Foco nos Ajustes do Sistema", systemImage: "moon.circle")
            }
            Text("O silêncio de notificações usa o Foco do macOS, definido nos Ajustes do Sistema.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Relatório do sistema

