import SwiftUI

/// O sino da toolbar. Apenas alterna o estado — o painel é um overlay no RootView
/// (não usa `.popover`, que é instável em toolbars do macOS).
struct NotificationBell: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var brew: BrewService
    @EnvironmentObject var schedule: ScheduleService
    @EnvironmentObject var security: SecurityService
    @EnvironmentObject var serverAlerts: ServerAlertsService

    private var pendingCount: Int {
        var count = 0
        if brew.outdated.count > 0 { count += 1 }
        if schedule.updateDue { count += 1 }
        if schedule.cleanupDue { count += 1 }
        if security.checks.contains(where: { $0.status == .warning }) { count += 1 }
        count += serverAlerts.alerts.count
        return count
    }

    var body: some View {
        Button { state.showNotifications.toggle() } label: {
            Image(systemName: "bell")
                .overlay(alignment: .topTrailing) {
                    if pendingCount > 0 {
                        Text("\(pendingCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(2.5)
                            .background(Circle().fill(.red))
                            .offset(x: 7, y: -7)
                    }
                }
        }
        .help("Notificações")
    }
}

/// Painel flutuante de notificações (overlay), ancorado no topo direito.
struct NotificationPanel: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Captura cliques fora para fechar.
            Color.black.opacity(0.0001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { state.showNotifications = false }

            NotificationCenterView(onNavigate: { state.showNotifications = false })
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
                .shadow(radius: 16, y: 4)
                .padding(.top, 6)
                .padding(.trailing, 12)
        }
        .transition(.opacity)
    }
}

struct TodoItem: Identifiable {
    let id: String
    let text: String
    let icon: String
    let tint: Color
    let action: () -> Void
}

/// Central de notificações do Uptend (popover do sininho): o que precisa de atenção
/// (a fazer) e a atividade recente, em seções separadas.
struct NotificationCenterView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var brew: BrewService
    @EnvironmentObject var schedule: ScheduleService
    @EnvironmentObject var security: SecurityService
    @EnvironmentObject var serverAlerts: ServerAlertsService
    @EnvironmentObject var hosts: HostStore
    @ObservedObject private var log = ActionLog.shared

    let onNavigate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Notificações").font(.headline)
                Spacer()
                if !log.entries.isEmpty {
                    Button("Limpar atividade") { log.clear() }.buttonStyle(.borderless).font(.caption)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section("A fazer") {
                        if !hosts.hosts.isEmpty {
                            Button { Task { await serverAlerts.check(hosts.hosts) } } label: {
                                row(icon: serverAlerts.checking ? "arrow.triangle.2.circlepath" : "server.rack",
                                    tint: .blue,
                                    title: serverAlerts.checking ? "Verificando servidores…" : "Verificar servidores")
                            }
                            .buttonStyle(.plain)
                            .disabled(serverAlerts.checking)
                        }
                        if todos.isEmpty {
                            emptyRow("Tudo em dia", icon: "checkmark.circle")
                        } else {
                            ForEach(todos) { todo in
                                Button {
                                    todo.action()
                                    onNavigate()
                                } label: {
                                    row(icon: todo.icon, tint: todo.tint, title: todo.text, trailingChevron: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    section("Atividade recente") {
                        if log.entries.isEmpty {
                            emptyRow("Nada registrado ainda", icon: "clock")
                        } else {
                            ForEach(log.entries.prefix(8)) { entry in
                                row(icon: "circle.fill", tint: .secondary, title: entry.text,
                                    subtitle: entry.date.formatted(date: .abbreviated, time: .shortened))
                            }
                        }
                    }
                }
                .padding(14)
            }
        }
        .frame(width: 340, height: 440)
        .task { if security.checks.isEmpty { await security.refresh() } }
    }

    // MARK: A fazer

    private var todos: [TodoItem] {
        var items: [TodoItem] = []
        // Alertas dos servidores primeiro (problemas em vermelho, atenção em laranja).
        for alert in serverAlerts.alerts {
            items.append(TodoItem(id: alert.id, text: alert.text,
                                  icon: alert.level == 2 ? "exclamationmark.triangle.fill" : "exclamationmark.circle",
                                  tint: alert.level == 2 ? .red : .orange) {
                state.activeHost = .remote(alert.kind, alert.hostID)
                state.homelabSection = HomeLabSection.sections(for: alert.kind).contains(alert.section) ? alert.section : .overview
            })
        }
        if brew.outdated.count > 0 {
            items.append(TodoItem(id: "updates", text: "\(brew.outdated.count) atualizações pendentes",
                                  icon: "arrow.triangle.2.circlepath", tint: .orange) {
                state.category = .homebrew; state.subID = "outdated"
            })
        }
        if schedule.updateDue {
            items.append(TodoItem(id: "schedUpdate", text: "Atualizações vencidas (agendamento)",
                                  icon: "bell.badge", tint: .orange) {
                state.category = .settings; state.subID = "schedule"
            })
        }
        if schedule.cleanupDue {
            items.append(TodoItem(id: "schedCleanup", text: "Limpeza vencida (agendamento)",
                                  icon: "sparkles", tint: .orange) {
                state.category = .cleanup; state.subID = "caches"
            })
        }
        let warnings = security.checks.filter { $0.status == .warning }.count
        if warnings > 0 {
            items.append(TodoItem(id: "security", text: "\(warnings) pontos de atenção na segurança",
                                  icon: "lock.shield", tint: .orange) {
                state.category = .security; state.subID = "status"
            })
        }
        return items
    }

    // MARK: Componentes

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }

    private func row(icon: String, tint: Color, title: String, subtitle: String? = nil, trailingChevron: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(tint).font(icon == "circle.fill" ? .system(size: 6) : .body)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout)
                if let subtitle { Text(subtitle).font(.caption2).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 4)
            if trailingChevron { Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary) }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func emptyRow(_ text: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(.green).frame(width: 18)
            Text(text).font(.callout).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
