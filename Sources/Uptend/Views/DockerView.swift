import SwiftUI

struct DockerView: View {
    let sub: SubSection?
    @EnvironmentObject var docker: DockerService
    @EnvironmentObject var brew: BrewService

    @State private var logsTitle: String?
    @State private var logsText = ""

    var body: some View {
        Group {
            if !docker.installed {
                missing
            } else if !docker.daemonRunning {
                notRunning
            } else {
                content
            }
        }
        .task { await docker.bootstrapIfNeeded() }
        .sheet(isPresented: Binding(get: { logsTitle != nil }, set: { if !$0 { logsTitle = nil } })) {
            logsSheet
        }
    }

    // MARK: Estados

    private var missing: some View {
        ContentUnavailableView {
            Label("Docker não encontrado", systemImage: "shippingbox")
        } description: {
            Text("Instale o Docker (ou OrbStack) para gerenciar containers pelo Uptend.")
        } actions: {
            Button("Instalar Docker via Homebrew") {
                Task { await brew.installToken("docker", isCask: true) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notRunning: some View {
        ContentUnavailableView {
            Label("\(docker.provider) não está rodando", systemImage: "pause.circle")
        } description: {
            Text("O Docker está instalado, mas o serviço não está ativo. Abra o \(docker.provider) para continuar.")
        } actions: {
            Button("Abrir \(docker.provider)") { docker.openApp() }
            Button("Verificar novamente") { Task { await docker.reload() } }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch sub?.id {
                case "images": imagesContent
                case "volumes": volumesContent
                case "networks": networksContent
                default: containersContent
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
    }

    private func header(_ title: String, _ subtitle: String) -> some View {
        ScreenHeader(title: title, subtitle: subtitle) {
            if docker.loading { ProgressView().controlSize(.small) }
            IconButton(systemImage: "arrow.clockwise", help: "Atualizar") {
                Task { await docker.refreshAll() }
            }
        }
    }

    // MARK: Containers

    private var containersContent: some View {
        Group {
            header("Containers", "\(docker.containers.filter { $0.running }.count) ativos · \(docker.containers.filter { !$0.running }.count) parados")

            if docker.containers.isEmpty {
                ContentUnavailableView("Nenhum container", systemImage: "shippingbox").padding(.top, 40)
            } else {
                VStack(spacing: 8) {
                    ForEach(docker.containers) { container in
                        CardRow {
                            HStack(spacing: 12) {
                                StatusDot(color: container.running ? .green : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(container.name).fontWeight(.medium)
                                    Text("\(container.image) · \(container.status)")
                                        .font(.callout).foregroundStyle(.secondary)
                                        .lineLimit(1).truncationMode(.tail)
                                }
                            }
                            .opacity(container.running ? 1 : 0.6)
                        } trailing: {
                            if container.running {
                                IconButton(systemImage: "stop.fill", help: "Parar") { Task { await docker.stop(container.id) } }
                            } else {
                                IconButton(systemImage: "play.fill", help: "Iniciar") { Task { await docker.start(container.id) } }
                            }
                            IconButton(systemImage: "doc.text", help: "Ver logs") {
                                Task {
                                    logsTitle = container.name
                                    logsText = "Carregando…"
                                    logsText = await docker.logs(container.id)
                                }
                            }
                            IconButton(systemImage: "trash", help: "Remover") { Task { await docker.removeContainer(container.id) } }
                        }
                    }
                }
            }
        }
    }

    // MARK: Imagens

    private var imagesContent: some View {
        Group {
            header("Imagens", "\(docker.images.count) imagens locais")
            if docker.images.isEmpty {
                ContentUnavailableView("Nenhuma imagem", systemImage: "square.stack.3d.up").padding(.top, 40)
            } else {
                VStack(spacing: 8) {
                    ForEach(docker.images) { image in
                        CardRow {
                            HStack(spacing: 12) {
                                Image(systemName: "square.stack.3d.up").foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(image.repository):\(image.tag)").fontWeight(.medium)
                                    Text(image.size).font(.callout).foregroundStyle(.secondary)
                                }
                            }
                        } trailing: {
                            IconButton(systemImage: "trash", help: "Remover imagem") { Task { await docker.removeImage(image.imageID) } }
                        }
                    }
                }
            }
        }
    }

    // MARK: Volumes

    private var volumesContent: some View {
        Group {
            header("Volumes", "\(docker.volumes.count) volumes")
            if docker.volumes.isEmpty {
                ContentUnavailableView("Nenhum volume", systemImage: "externaldrive").padding(.top, 40)
            } else {
                VStack(spacing: 8) {
                    ForEach(docker.volumes) { volume in
                        CardRow {
                            HStack(spacing: 12) {
                                Image(systemName: "externaldrive").foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(volume.name).fontWeight(.medium).lineLimit(1).truncationMode(.middle)
                                    Text(volume.driver).font(.callout).foregroundStyle(.secondary)
                                }
                            }
                        } trailing: {
                            IconButton(systemImage: "trash", help: "Remover volume") { Task { await docker.removeVolume(volume.name) } }
                        }
                    }
                }
            }
        }
    }

    // MARK: Redes

    private var networksContent: some View {
        Group {
            header("Redes", "\(docker.networks.count) redes")
            VStack(spacing: 8) {
                ForEach(docker.networks) { network in
                    CardRow {
                        HStack(spacing: 12) {
                            Image(systemName: "network").foregroundStyle(.secondary)
                            Text(network.name).fontWeight(.medium)
                        }
                    } trailing: {
                        Text(network.driver).foregroundStyle(.secondary).font(.callout)
                    }
                }
            }
        }
    }

    // MARK: Logs

    private var logsSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                Text("Logs · \(logsTitle ?? "")").font(.headline)
                Spacer()
            }
            ScrollView {
                Text(logsText.isEmpty ? "Sem logs." : logsText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(minHeight: 260)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Spacer()
                Button("Fechar") { logsTitle = nil }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 580, height: 420)
    }
}
