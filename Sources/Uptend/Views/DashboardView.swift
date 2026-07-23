import SwiftUI

struct DashboardView: View {
    let sub: SubSection?
    @EnvironmentObject var brew: BrewService
    @EnvironmentObject var state: AppState
    @EnvironmentObject var schedule: ScheduleService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                overviewContent
            }
            .screenPadding()
        }
    }

    private var overdueText: String {
        var parts: [String] = []
        if schedule.updateDue { parts.append("atualizações") }
        if schedule.cleanupDue { parts.append("limpeza") }
        return "Está na hora de: " + parts.joined(separator: " e ") + "."
    }

    private var overviewContent: some View {
        Group {
            ScreenHeader(title: "Início", subtitle: "Visão geral do seu Mac") {
                if brew.loading { ProgressView().controlSize(.small) }
                IconButton(systemImage: "arrow.clockwise", help: "Atualizar informações") {
                    Task { await brew.refreshAll() }
                }
            }

            if schedule.updateDue || schedule.cleanupDue {
                CardRow {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.badge.fill").foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Manutenção pendente").fontWeight(.medium)
                            Text(overdueText).font(.callout).foregroundStyle(.secondary)
                        }
                    }
                } trailing: {
                    IconButton(systemImage: "calendar", help: "Ver agendamento") {
                        state.category = .settings
                        state.subID = "schedule"
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                StatCard(title: "Pacotes instalados (brew)", value: "\(brew.installedCount)", systemImage: "app.badge.checkmark", tint: .blue,
                         help: "Total de fórmulas e casks instalados pelo Homebrew.")
                StatCard(title: "Atualizações pendentes", value: "\(brew.outdated.count)", systemImage: "arrow.triangle.2.circlepath", tint: .orange,
                         help: "Pacotes do Homebrew com uma versão mais nova disponível.")
                StatCard(title: "Repositórios fora de sincronia", value: "2", systemImage: "arrow.triangle.branch", tint: .yellow,
                         help: "Repositórios Git monitorados que estão à frente ou atrás do GitHub.")
                StatCard(title: "Espaço livre", value: Self.freeDisk(), systemImage: "internaldrive", tint: .green,
                         help: "Espaço disponível no disco de inicialização do Mac.")
            }

            Text("Homebrew")
                .font(.headline)
                .padding(.top, 4)

            healthRow("Homebrew",
                      detail: brew.detected ? "Instalado e funcionando" : "Não encontrado",
                      status: brew.detected ? .ok : .warning)
        }
    }

    private func healthRow(_ title: String, detail: String, status: CheckStatus) -> some View {
        CardRow {
            HStack(spacing: 10) {
                Image(systemName: status.systemImage).foregroundStyle(status.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).fontWeight(.medium)
                    Text(detail).font(.callout).foregroundStyle(.secondary)
                }
            }
        } trailing: {
            EmptyView()
        }
    }

    static func freeDisk() -> String {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let capacity = values.volumeAvailableCapacityForImportantUsage {
            return ByteCountFormatter.string(fromByteCount: capacity, countStyle: .file)
        }
        return "—"
    }
}
