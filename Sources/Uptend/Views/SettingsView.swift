import SwiftUI

struct SettingsView: View {
    let sub: SubSection?
    @EnvironmentObject var state: AppState
    @EnvironmentObject var schedule: ScheduleService
    @EnvironmentObject var brew: BrewService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch sub?.id {
                case "about": aboutContent
                case "schedule": scheduleContent
                default: generalContent
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
    }

    private var scheduleContent: some View {
        Group {
            ScreenHeader(title: "Agendamento", subtitle: "Lembretes de manutenção (enquanto o app está aberto)")

            scheduleCard(
                title: "Atualizações",
                status: schedule.updateStatus(),
                due: schedule.updateDue,
                interval: Binding(get: { schedule.updateIntervalDays }, set: { schedule.updateIntervalDays = $0 }),
                runLabel: "Atualizar agora",
                run: { Task { await brew.updateAndUpgradeAll(); schedule.markUpdateDone() } },
                markDone: { schedule.markUpdateDone() }
            )

            scheduleCard(
                title: "Limpeza",
                status: schedule.cleanupStatus(),
                due: schedule.cleanupDue,
                interval: Binding(get: { schedule.cleanupIntervalDays }, set: { schedule.cleanupIntervalDays = $0 }),
                runLabel: "Ir para Limpeza",
                run: { state.category = .cleanup; state.subID = "caches" },
                markDone: { schedule.markCleanupDone() }
            )

            Text("O Uptend só lembra enquanto está aberto — não roda tarefas em segundo plano nesta versão.")
                .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
        }
    }

    private func scheduleCard(title: String, status: String, due: Bool, interval: Binding<Int>,
                              runLabel: String, run: @escaping () -> Void, markDone: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: due ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(due ? .orange : .green)
                Text(title).fontWeight(.medium)
                Spacer()
                Text(status).font(.callout).foregroundStyle(.secondary)
            }
            Stepper("A cada \(interval.wrappedValue) dias", value: interval, in: 1...90)
                .frame(maxWidth: 260)
            HStack {
                Button(runLabel, action: run)
                Button("Marcar como feito hoje", action: markDone)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    private var generalContent: some View {
        Group {
            ScreenHeader(title: "Geral", subtitle: "Preferências do Uptend")

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Aparência").fontWeight(.medium)
                    Picker("Aparência", selection: $state.appearance) {
                        ForEach(Appearance.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 320)
                }

                Divider()

                Toggle("Verificar atualizações ao abrir", isOn: .constant(true))
                Toggle("Confirmar antes de limpar arquivos", isOn: .constant(true))
                Toggle("Mostrar itens instalados no topo da lista", isOn: .constant(false))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardBackground()
        }
    }

    private var aboutContent: some View {
        Group {
            ScreenHeader(title: "Sobre", subtitle: "Uptend")

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Image(systemName: "hammer.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Uptend").font(.title2).fontWeight(.medium)
                        Text("Versão 0.1 · protótipo de interface").foregroundStyle(.secondary)
                    }
                }
                Divider()
                Text("Central para instalar, atualizar, limpar e manter o seu Mac. Esta é uma prévia da interface com dados de exemplo.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardBackground()
        }
    }
}
