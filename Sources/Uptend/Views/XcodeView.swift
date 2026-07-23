import SwiftUI

/// Xcode & Simuladores: versão, limpeza do DerivedData e gestão dos simuladores.
struct XcodeView: View {
    let sub: SubSection?
    @StateObject private var xc = XcodeService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch sub?.id {
                case "simulators": simulatorsContent
                default: xcodeContent
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
        .task { await xc.refresh() }
    }

    // MARK: Xcode

    private var xcodeContent: some View {
        Group {
            ScreenHeader(title: "Xcode", subtitle: xc.installed ? "Instalado" : "Não encontrado") {
                if xc.loading { ProgressView().controlSize(.small) }
                IconButton(systemImage: "arrow.clockwise", help: "Atualizar") { Task { await xc.refresh() } }
            }

            if let error = xc.lastError { ErrorBanner(error) { xc.lastError = nil } }

            if !xc.installed {
                ContentUnavailableView("Xcode não encontrado", systemImage: "hammer",
                    description: Text("Instale o Xcode pela App Store, ou as Command Line Tools com `xcode-select --install`."))
                    .padding(.top, 30)
            } else {
                CardRow {
                    HStack(spacing: 10) {
                        Image(systemName: "hammer.fill").foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Xcode \(xc.version.isEmpty ? "" : xc.version)").fontWeight(.medium)
                            Text(xc.xcodePath).font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.middle)
                        }
                    }
                } trailing: { EmptyView() }

                Text("DerivedData").font(.headline).padding(.top, 4)
                Text("Cache de compilação do Xcode. Pode ocupar dezenas de GB e é 100% seguro apagar — o Xcode recria quando precisar.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                CardRow {
                    HStack(spacing: 10) {
                        Image(systemName: "internaldrive").foregroundStyle(.secondary)
                        Text(xc.derivedDataBytes > 0 ? "Ocupando \(xc.derivedDataLabel)" : "Vazio")
                            .fontWeight(.medium)
                    }
                } trailing: {
                    if xc.busy == "derived" {
                        ProgressView().controlSize(.small).frame(width: 24, height: 24)
                    } else if xc.derivedDataBytes > 0 {
                        Button(role: .destructive) { Task { await xc.cleanDerivedData() } } label: {
                            Label("Limpar", systemImage: "trash")
                        }
                        .help("Move o DerivedData para a Lixeira (reversível)")
                    }
                }
            }
        }
    }

    // MARK: Simuladores

    private var simulatorsContent: some View {
        Group {
            ScreenHeader(title: "Simuladores", subtitle: "\(xc.simulators.count) simuladores disponíveis") {
                if xc.loading { ProgressView().controlSize(.small) }
                IconButton(systemImage: "arrow.clockwise", help: "Atualizar") { Task { await xc.refresh() } }
            }

            if let error = xc.lastError { ErrorBanner(error) { xc.lastError = nil } }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle").foregroundStyle(.blue)
                Text("Simuladores de iPhone/iPad usados pelo Xcode. Cada um ocupa espaço. \"Zerar\" apaga o conteúdo (volta ao estado de fábrica); \"Apagar\" remove o simulador.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()

            CardRow {
                HStack(spacing: 10) {
                    Image(systemName: "internaldrive").foregroundStyle(.secondary)
                    Text("Simuladores ocupam \(xc.simulatorsLabel)").fontWeight(.medium)
                }
            } trailing: {
                if xc.busy == "unavailable" {
                    ProgressView().controlSize(.small).frame(width: 24, height: 24)
                } else {
                    Button { Task { await xc.deleteUnavailable() } } label: { Label("Apagar indisponíveis", systemImage: "trash") }
                        .help("Remove simuladores de versões do iOS que você não tem mais instaladas — libera espaço")
                }
            }

            if xc.runtimeCount > 0 {
                CardRow {
                    HStack(spacing: 10) {
                        Image(systemName: "shippingbox").foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Imagens de iOS ocupam \(xc.runtimeLabel)").fontWeight(.medium)
                            Text("\(xc.runtimeCount) versão(ões) do sistema — a parte mais pesada, guardada separada dos dados acima")
                                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } trailing: { EmptyView() }
                .help("O sistema iOS que roda dentro dos simuladores. É baixado pelo Xcode e compartilhado entre todos os simuladores da mesma versão. Gerencie em Xcode ▸ Settings ▸ Platforms.")
            }

            if xc.simulators.isEmpty && !xc.loading {
                ContentUnavailableView("Nenhum simulador", systemImage: "iphone.slash").padding(.top, 30)
            } else {
                ForEach(groupedOS, id: \.self) { os in
                    Text(os).font(.headline).padding(.top, 4)
                    ForEach(xc.simulators.filter { $0.os == os }) { device in row(device) }
                }
            }
        }
    }

    private var groupedOS: [String] {
        var seen: [String] = []
        for d in xc.simulators where !seen.contains(d.os) { seen.append(d.os) }
        return seen
    }

    private func row(_ device: SimDevice) -> some View {
        CardRow {
            HStack(spacing: 10) {
                Circle().fill(device.isBooted ? Color.green : Color.secondary).frame(width: 8, height: 8)
                Text(device.name).fontWeight(.medium)
                if device.isBooted { Text("ligado").font(.caption2).foregroundStyle(.green) }
            }
        } trailing: {
            if xc.busy == device.udid {
                ProgressView().controlSize(.small).frame(width: 24, height: 24)
            } else {
                if device.isBooted {
                    IconButton(systemImage: "stop.circle", help: "Desligar simulador") { Task { await xc.shutdown(device.udid) } }
                }
                IconButton(systemImage: "arrow.counterclockwise", help: "Zerar (volta ao estado de fábrica)") { Task { await xc.erase(device.udid) } }
                IconButton(systemImage: "trash", help: "Apagar simulador") { Task { await xc.delete(device.udid) } }
            }
        }
    }
}
