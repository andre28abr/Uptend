import SwiftUI

/// Painel de "superfície de ataque": firewall, stealth e serviços de acesso remoto
/// ouvindo em portas expostas à rede. Tudo por leitura, sem sudo.
struct ExposureView: View {
    @StateObject private var exposure = ExposureService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(
                    title: "Exposição do Mac",
                    subtitle: exposure.loading ? "Verificando…" : "O que está acessível pela rede"
                ) {
                    if exposure.loading { ProgressView().controlSize(.small) }
                    IconButton(systemImage: "arrow.clockwise", help: "Verificar novamente") {
                        Task { await exposure.refresh() }
                    }
                }

                Text("Serviços de acesso remoto ligados e expostos aumentam a superfície de ataque. O ideal é manter desligado o que você não usa (Ajustes do sistema › Geral › Compartilhamento).")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 8) {
                    ForEach(exposure.checks) { check in
                        CardRow {
                            HStack(spacing: 10) {
                                Image(systemName: check.status.systemImage)
                                    .foregroundStyle(check.status.color)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(check.name).fontWeight(.medium)
                                    Text(check.detail).font(.callout).foregroundStyle(.secondary)
                                }
                            }
                        } trailing: { EmptyView() }
                    }
                }

                if !exposure.otherPorts.isEmpty {
                    Text("Outras portas abertas à rede")
                        .font(.headline).padding(.top, 6)
                    Text("Portas ouvindo em todas as interfaces (podem ser apps de desenvolvimento). Veja detalhes em Ferramentas › Portas em uso.")
                        .font(.caption).foregroundStyle(.secondary)
                    VStack(spacing: 6) {
                        ForEach(Array(exposure.otherPorts.enumerated()), id: \.offset) { _, port in
                            CardRow {
                                HStack(spacing: 10) {
                                    Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(.secondary)
                                    Text("Porta \(port.port)").fontWeight(.medium)
                                    Spacer()
                                    Text("exposta").font(.caption).foregroundStyle(.orange)
                                }
                            } trailing: { EmptyView() }
                        }
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
        .task {
            if exposure.checks.isEmpty { await exposure.refresh() }
        }
    }
}
