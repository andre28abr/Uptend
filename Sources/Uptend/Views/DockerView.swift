import SwiftUI

struct DockerView: View {
    let sub: SubSection?
    @EnvironmentObject var docker: DockerService
    @EnvironmentObject var brew: BrewService

    @State private var logsTitle: String?
    @State private var logsText = ""

    var body: some View {
        Group {
            if docker.daemonRunning {
                content
            } else {
                engineScreen
            }
        }
        .task { await docker.bootstrapIfNeeded() }
        .sheet(isPresented: Binding(get: { logsTitle != nil }, set: { if !$0 { logsTitle = nil } })) {
            logsSheet
        }
    }

    // MARK: Tela do motor (didática)

    private var engineScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Docker", subtitle: "O motor de containers não está ativo") {
                    if docker.starting || docker.loading { ProgressView().controlSize(.small) }
                    IconButton(systemImage: "arrow.clockwise", help: "Verificar novamente") {
                        Task { await docker.reload() }
                    }
                }

                explanationCard

                if docker.engines.isEmpty {
                    noEngineCard
                } else {
                    Text("Motores detectados").font(.headline).padding(.top, 4)
                    ForEach(docker.engines) { engine in
                        CardRow {
                            HStack(spacing: 12) {
                                Image(systemName: engine.systemImage).foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(engine.name).fontWeight(.medium)
                                    Text(engine.isApp ? "Aplicativo" : "Linha de comando")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        } trailing: {
                            Button(engine.isApp ? "Abrir" : "Iniciar") { docker.startEngine(engine) }
                                .disabled(docker.starting)
                        }
                    }
                    Text("Depois de abrir/iniciar o motor, aguarde alguns segundos e toque em \"Verificar novamente\".")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
    }

    private var explanationCard: some View {
        CardRow {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lightbulb").foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Como funciona").fontWeight(.medium)
                    Text("No Mac, containers rodam dentro de um \"motor\" (uma pequena máquina Linux). Apps como OrbStack, Docker Desktop, Rancher, Colima ou Podman fornecem esse motor. Seus containers ficam guardados dentro dele — quando o motor está desligado, eles existem em disco, mas não podem ser listados. O Uptend não substitui o motor: ele o pilota. Ligue um motor abaixo para ver seus containers.")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } trailing: {
            EmptyView()
        }
    }

    private var noEngineCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            ContentUnavailableView {
                Label("Nenhum motor de containers instalado", systemImage: "shippingbox")
            } description: {
                Text("Instale um motor para começar. O OrbStack é leve e recomendado.")
            } actions: {
                Button("Instalar OrbStack via Homebrew") {
                    Task { await brew.installToken("orbstack", isCask: true) }
                }
            }
        }
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
