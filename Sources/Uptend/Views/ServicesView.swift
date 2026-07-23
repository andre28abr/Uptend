import SwiftUI

/// Serviços de fundo do Homebrew: ligar/desligar bancos de dados e afins.
struct ServicesView: View {
    let sub: SubSection?
    @EnvironmentObject var brew: BrewService
    @StateObject private var svc = ServicesService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Serviços",
                             subtitle: svc.loading ? "Lendo…" : "\(svc.services.count) serviços do Homebrew") {
                    if svc.loading { ProgressView().controlSize(.small) }
                    IconButton(systemImage: "arrow.clockwise", help: "Atualizar lista") { Task { await svc.refresh() } }
                }

                if !brew.detected {
                    ContentUnavailableView("Homebrew não detectado", systemImage: "server.rack").padding(.top, 40)
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle").foregroundStyle(.blue)
                        Text("São programas que rodam em segundo plano (bancos de dados, servidores…) instalados pelo Homebrew. Ligue só quando for usar e desligue depois para poupar recursos.")
                            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()

                    if let error = svc.lastError { ErrorBanner(error) { svc.lastError = nil } }

                    if svc.services.isEmpty && !svc.loading {
                        ContentUnavailableView("Nenhum serviço", systemImage: "server.rack",
                            description: Text("Você não tem serviços do Homebrew instalados (ex.: postgresql, redis, nginx)."))
                            .padding(.top, 30)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(svc.services) { service in row(service) }
                        }
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
        .task { if svc.services.isEmpty { await svc.refresh() } }
    }

    private func row(_ service: BrewServiceItem) -> some View {
        CardRow {
            HStack(spacing: 12) {
                Circle().fill(color(service)).frame(width: 9, height: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.name).fontWeight(.medium)
                    Text(label(service)).font(.callout).foregroundStyle(.secondary)
                }
            }
        } trailing: {
            if svc.busy == service.name {
                ProgressView().controlSize(.small).frame(width: 24, height: 24)
            } else if service.isRunning {
                IconButton(systemImage: "arrow.clockwise.circle", help: "Reiniciar") { Task { await svc.restart(service.name) } }
                Button("Parar", role: .destructive) { Task { await svc.stop(service.name) } }
            } else {
                Button("Iniciar") { Task { await svc.start(service.name) } }
            }
        }
    }

    private func color(_ s: BrewServiceItem) -> Color {
        switch s.status {
        case "started", "scheduled": .green
        case "error": .red
        default: .secondary
        }
    }
    private func label(_ s: BrewServiceItem) -> String {
        switch s.status {
        case "started": "Rodando"
        case "scheduled": "Agendado (inicia no login)"
        case "error": "Erro ao iniciar"
        case "stopped": "Parado"
        default: "Desligado"
        }
    }
}
