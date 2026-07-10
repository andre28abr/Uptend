import SwiftUI

struct DashboardView: View {
    let sub: SubSection?
    @EnvironmentObject var brew: BrewService
    @EnvironmentObject var state: AppState
    @EnvironmentObject var schedule: ScheduleService
    @ObservedObject private var log = ActionLog.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch sub?.id {
                case "health": healthContent
                case "activity": activityContent
                default: overviewContent
                }
            }
            .screenPadding()
        }
    }

    private var activityContent: some View {
        Group {
            ScreenHeader(title: "Atividade", subtitle: "\(log.entries.count) ações registradas") {
                IconButton(systemImage: "trash", help: "Limpar histórico") { log.clear() }
            }

            if log.entries.isEmpty {
                ContentUnavailableView("Nada registrado ainda", systemImage: "clock.arrow.circlepath")
                    .padding(.top, 40)
            } else {
                VStack(spacing: 8) {
                    ForEach(log.entries) { entry in
                        CardRow {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.text).fontWeight(.medium)
                                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } trailing: {
                            EmptyView()
                        }
                    }
                }
            }
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
                StatCard(title: "Pacotes instalados (brew)", value: "\(brew.installedCount)", systemImage: "app.badge.checkmark", tint: .blue)
                StatCard(title: "Atualizações pendentes", value: "\(brew.outdated.count)", systemImage: "arrow.triangle.2.circlepath", tint: .orange)
                StatCard(title: "Repositórios fora de sincronia", value: "2", systemImage: "arrow.triangle.branch", tint: .yellow)
                StatCard(title: "Espaço livre", value: Self.freeDisk(), systemImage: "internaldrive", tint: .green)
            }

            Text("Ações rápidas")
                .font(.headline)
                .padding(.top, 4)

            VStack(spacing: 8) {
                quickAction("Atualizar tudo do Homebrew", systemImage: "arrow.triangle.2.circlepath") {
                    Task { await brew.updateAndUpgradeAll() }
                }
                quickAction("Verificar atualizações", systemImage: "arrow.clockwise") {
                    Task { await brew.refreshAll() }
                }
            }
        }
    }

    private var healthContent: some View {
        Group {
            ScreenHeader(title: "Saúde do sistema", subtitle: "Verificações rápidas do estado do Mac") {
                IconButton(systemImage: "arrow.clockwise", help: "Rodar verificações")
            }

            VStack(spacing: 8) {
                healthRow("Homebrew", detail: brew.detected ? "Instalado e funcionando" : "Não encontrado", status: brew.detected ? .ok : .warning)
                healthRow("Atualizações do Homebrew", detail: brew.outdated.isEmpty ? "Tudo atualizado" : "\(brew.outdated.count) pendentes", status: brew.outdated.isEmpty ? .ok : .warning)
                healthRow("Espaço em disco", detail: "\(Self.freeDisk()) livres", status: .ok)
                healthRow("Itens de inicialização", detail: "7 apps abrindo no login", status: .warning)
            }
        }
    }

    private func quickAction(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        CardRow {
            Label(title, systemImage: systemImage)
        } trailing: {
            IconButton(systemImage: "play.fill", help: "Executar", action: action)
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
