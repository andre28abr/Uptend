import SwiftUI
import AppKit
import UptendCore

// =============================================================================
// MÓDULO HOMELAB
// Todas as telas usam dados reais do servidor via SSH (SSHRunner + parsers testados).
// Só interface + disposição de menus/submenus. Nada funcional ainda: todos os
// dados são exemplos estáticos. As funções entram depois (ver HOMELAB.md).
// =============================================================================

// MARK: - Modelo de navegação (categorias do HomeLab)

enum HomeLabSection: String, CaseIterable, Identifiable, Hashable {
    case overview, setup, machines, containers, catalog, services, security, files, storage, backups, network, updates, terminal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Visão geral"
        case .setup: "Configuração"
        case .machines: "Máquinas (VMs)"
        case .containers: "Containers"
        case .catalog: "Catálogo"
        case .services: "Serviços"
        case .security: "Segurança"
        case .files: "Arquivos"
        case .storage: "Discos e RAID"
        case .backups: "Backups"
        case .network: "Rede"
        case .updates: "Atualizações"
        case .terminal: "Terminal"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "gauge.with.dots.needle.bottom.50percent"
        case .setup: "wand.and.stars"
        case .machines: "rectangle.on.rectangle"
        case .containers: "shippingbox"
        case .catalog: "square.grid.2x2"
        case .services: "server.rack"
        case .security: "lock.shield"
        case .files: "folder"
        case .storage: "internaldrive"
        case .backups: "externaldrive.badge.timemachine"
        case .network: "network"
        case .updates: "arrow.triangle.2.circlepath"
        case .terminal: "terminal"
        }
    }

    var help: String {
        switch self {
        case .overview: "Saúde do servidor num relance"
        case .setup: "Assistente de primeira configuração (Docker, firewall, SSH…)"
        case .machines: "Máquinas virtuais e containers LXC (Proxmox)"
        case .containers: "Containers Docker, imagens e volumes"
        case .catalog: "Serviços prontos para instalar com 1 clique"
        case .services: "Serviços do sistema (systemd)"
        case .security: "Firewall, SSH e auditoria de segurança"
        case .files: "Navegar e transferir arquivos (SFTP)"
        case .storage: "Discos, saúde SMART e arranjos RAID"
        case .backups: "Backups locais e na nuvem"
        case .network: "Endereços, portas e VPN"
        case .updates: "Pacotes desatualizados do servidor"
        case .terminal: "Terminal remoto"
        }
    }

    /// Seções disponíveis por tipo de host. Servidor Linux comum não é hipervisor,
    /// então não mostra "Máquinas (VMs)".
    static func sections(for kind: HostKind) -> [HomeLabSection] {
        switch kind {
        case .homelab: return allCases
        case .server: return allCases.filter { $0 != .machines }
        }
    }

    var subsections: [SubSection] {
        switch self {
        case .overview:
            return [SubSection(id: "overview", title: "Visão geral", systemImage: "gauge.with.dots.needle.bottom.50percent")]
        case .setup:
            return [SubSection(id: "setup", title: "Assistente", systemImage: "wand.and.stars")]
        case .machines:
            return [
                SubSection(id: "vms", title: "Máquinas virtuais", systemImage: "rectangle.on.rectangle"),
                SubSection(id: "lxc", title: "Containers LXC", systemImage: "cube.box"),
            ]
        case .containers:
            return [
                SubSection(id: "containers", title: "Containers", systemImage: "shippingbox"),
                SubSection(id: "images", title: "Imagens", systemImage: "square.stack.3d.up"),
                SubSection(id: "volumes", title: "Volumes", systemImage: "externaldrive"),
            ]
        case .catalog:
            return [
                SubSection(id: "catalog", title: "Serviços prontos", systemImage: "square.grid.2x2"),
                SubSection(id: "deploy", title: "Meu projeto", systemImage: "arrow.up.forward.app"),
            ]
        case .security:
            return [
                SubSection(id: "status", title: "Status", systemImage: "checklist"),
                SubSection(id: "monitor", title: "Monitoramento", systemImage: "waveform.path.ecg"),
                SubSection(id: "audit", title: "Auditoria (Lynis)", systemImage: "list.bullet.clipboard"),
            ]
        case .files:
            return [SubSection(id: "files", title: "Arquivos", systemImage: "folder")]
        case .services:
            return [SubSection(id: "services", title: "Serviços (systemd)", systemImage: "server.rack")]
        case .storage:
            return [
                SubSection(id: "disks", title: "Discos", systemImage: "internaldrive"),
                SubSection(id: "raid", title: "RAID", systemImage: "square.stack.3d.down.right"),
                SubSection(id: "smart", title: "Saúde (SMART)", systemImage: "heart.text.square"),
            ]
        case .backups:
            return [
                SubSection(id: "local", title: "Backups locais", systemImage: "externaldrive.badge.timemachine"),
                SubSection(id: "cloud", title: "Nuvem", systemImage: "cloud"),
            ]
        case .network:
            return [
                SubSection(id: "overview", title: "Endereços", systemImage: "number"),
                SubSection(id: "ports", title: "Portas", systemImage: "point.3.connected.trianglepath.dotted"),
                SubSection(id: "tools", title: "Ping e DNS", systemImage: "dot.radiowaves.left.and.right"),
            ]
        case .updates:
            return [SubSection(id: "updates", title: "Atualizações", systemImage: "arrow.triangle.2.circlepath")]
        case .terminal:
            return [SubSection(id: "terminal", title: "Terminal", systemImage: "terminal")]
        }
    }
}

// MARK: - Barra de abas de host (Este Mac / HomeLab / +)

struct HostTabBar: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var hosts: HostStore

    var body: some View {
        HStack(spacing: 6) {
            // Este Mac: botão simples.
            Button { state.activeHost = .thisMac } label: {
                chipLabel("Este Mac", "laptopcomputer", selected: state.activeHost == .thisMac, showChevron: false)
            }
            .buttonStyle(.plain)

            // HomeLab / Servidor: cada um é um menu em cascata (hosts + adicionar).
            typeMenu(.homelab)
            typeMenu(.server)

            // Auditoria Externa: aba própria (área com suas próprias ferramentas).
            Button { state.activeHost = .auditoria } label: {
                chipLabel("Auditoria Externa", "chart.bar.doc.horizontal",
                          selected: state.activeHost.isAuditoria, showChevron: false)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    /// Menu suspenso de um tipo de host: lista os hosts cadastrados + adicionar.
    private func typeMenu(_ kind: HostKind) -> some View {
        let selected = state.activeHost.remoteKind == kind
        let list = hosts.hosts(of: kind)
        return Menu {
            ForEach(list) { host in
                Button {
                    state.activeHost = .remote(kind, host.id)
                    clampSection(kind)
                } label: {
                    if state.activeHost.remoteID == host.id {
                        Label(host.name, systemImage: "checkmark")
                    } else {
                        Text(host.name)
                    }
                }
            }
            if !list.isEmpty { Divider() }
            Button { openAdd(kind) } label: {
                Label("Adicionar \(kind.label)", systemImage: "plus")
            }
        } label: {
            chipLabel(chipTitle(kind), kind.systemImage, selected: selected, showChevron: true)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    /// Título do chip: mostra o nome do host ativo quando é o tipo em foco.
    private func chipTitle(_ kind: HostKind) -> String {
        if state.activeHost.remoteKind == kind, let id = state.activeHost.remoteID,
           let host = hosts.hosts.first(where: { $0.id == id }) {
            return host.name
        }
        return kind.label
    }

    private func chipLabel(_ title: String, _ image: String, selected: Bool, showChevron: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: image).font(.caption)
            Text(title).font(.callout).fontWeight(selected ? .medium : .regular)
            if showChevron {
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold)).opacity(0.5)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(selected ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(selected ? Color.accentColor.opacity(0.4) : .clear, lineWidth: 1))
        .contentShape(Rectangle())
        .foregroundStyle(selected ? Color.accentColor : Color.primary)
    }

    private func clampSection(_ kind: HostKind) {
        if !HomeLabSection.sections(for: kind).contains(state.homelabSection) {
            state.homelabSection = .overview
        }
    }

    private func openAdd(_ kind: HostKind) {
        state.addHostKind = kind
        state.showAddHost = true
    }
}

// MARK: - Colunas (sidebar + subseções) do HomeLab

struct HomeLabSidebar: View {
    @EnvironmentObject var state: AppState

    private var selection: Binding<HomeLabSection?> {
        Binding(get: { state.homelabSection }, set: { if let v = $0 { state.homelabSection = v } })
    }

    private var kind: HostKind { state.activeHost.remoteKind ?? .homelab }

    var body: some View {
        List(selection: selection) {
            Section(kind.label) {
                ForEach(HomeLabSection.sections(for: kind)) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tip(section.help)
                        .tag(section)
                }
            }
        }
        .listStyle(.sidebar)
    }
}

struct HomeLabContentColumn: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        List(selection: $state.homelabSubID) {
            Section(state.homelabSection.title) {
                ForEach(state.homelabSection.subsections) { sub in
                    Label(sub.title, systemImage: sub.systemImage).tag(sub.id)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(state.homelabSection.title)
    }
}

struct HomeLabDetailColumn: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let sub = state.homelabSubsection?.id
        Group {
            switch state.homelabSection {
            case .overview: HLOverviewView()
            case .setup: HLSetupView()
            case .machines: HLMachinesView(sub: sub)
            case .containers: HLContainersView(sub: sub)
            case .catalog:
                switch sub {
                case "deploy": HLDeployView()
                default: HLCatalogView()
                }
            case .services: HLServicesView()
            case .security:
                switch sub {
                case "audit": HLAuditView()
                case "monitor": HLMonitorView()
                default: HLSecurityStatusView()
                }
            case .files: HLFilesView()
            case .storage: HLStorageView(sub: sub)
            case .backups: HLBackupsView(sub: sub)
            case .network: HLNetworkView(sub: sub)
            case .updates: HLUpdatesView()
            case .terminal: HLTerminalView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Peças reutilizáveis da prévia

/// Aviso fixo de que é só interface, sem dados reais.
struct HLPreviewBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye").foregroundStyle(.orange)
            Text("Prévia da interface — valores de exemplo. Ainda não há conexão com um servidor; as funções entram depois.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }
}

/// Barra de uso (capsule) com rótulo à direita.
struct HLBar: View {
    let value: Double            // 0...1
    var tint: Color = .accentColor
    var body: some View {
        GeometryReader { geo in
            Capsule().fill(.quaternary).overlay(alignment: .leading) {
                Capsule().fill(tint).frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 6)
    }
}

/// Semáforo de saúde: verde (ok), amarelo (atenção), vermelho (problema).
struct Semaforo: View {
    let level: Int               // 0 ok, 1 atenção, 2 problema
    private var color: Color { level == 0 ? .green : (level == 1 ? .orange : .red) }
    var body: some View { Circle().fill(color).frame(width: 9, height: 9) }
}

/// Casca padrão de uma tela da prévia: header + banner + conteúdo.
struct HLScreen<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: title, subtitle: subtitle)
                HLPreviewBanner()
                content()
            }
            .screenPadding()
            .frame(maxWidth: 900, alignment: .leading)
        }
    }
}

// MARK: - Visão geral (DADOS REAIS via SSH)

struct HLOverviewView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var hosts: HostStore

    @State private var overview: RemoteOverview?
    @State private var loading = false

    private var host: RemoteHost? {
        guard let id = state.activeHost.remoteID else { return nil }
        return hosts.hosts.first { $0.id == id }
    }

    var body: some View {
        Group {
            if let host {
                content(host)
            } else {
                ContentUnavailableView("Nenhum host selecionado", systemImage: "server.rack")
            }
        }
        .task(id: host?.id) { await load() }
    }

    private func content(_ host: RemoteHost) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: host.name, subtitle: statusLine(host)) {
                    if loading { ProgressView().controlSize(.small) }
                    IconButton(systemImage: "arrow.clockwise", help: "Atualizar") { Task { await load() } }
                }

                if let error = overview?.error, overview?.reachable == false {
                    ErrorBanner("Não foi possível conectar: \(error)")
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    StatCard(title: "CPU", value: pct(overview?.cpuUsed), systemImage: "cpu",
                             tint: tint(overview?.cpuUsed))
                    StatCard(title: "Memória", value: pct(overview?.memUsed), systemImage: "memorychip",
                             tint: tint(overview?.memUsed))
                    StatCard(title: "Disco", value: pct(overview?.diskUsed), systemImage: "internaldrive",
                             tint: tint(overview?.diskUsed))
                    StatCard(title: "Uptime", value: overview?.uptime ?? "—", systemImage: "clock", tint: .secondary)
                    StatCard(title: "Carga (1m)", value: load1Text, systemImage: "waveform.path.ecg", tint: .orange)
                }

                Text("Containers, serviços, discos e atualizações nas abas ao lado.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .screenPadding()
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private func statusLine(_ host: RemoteHost) -> String {
        if loading && overview == nil { return "conectando…" }
        let reachable = overview?.reachable == true
        return "\(host.user)@\(host.address)  ·  " + (reachable ? "online" : "sem conexão")
    }

    private var load1Text: String {
        guard let l = overview?.load1 else { return "—" }
        return String(format: "%.2f", l)
    }

    private func pct(_ f: Double?) -> String { f.map { "\(Int(($0 * 100).rounded()))%" } ?? "—" }

    private func tint(_ f: Double?) -> Color {
        guard let f else { return .secondary }
        return f > 0.85 ? .red : (f > 0.7 ? .orange : .blue)
    }

    @MainActor
    private func load() async {
        guard let host else { return }
        loading = true
        overview = await HomeLabMonitor.overview(host)
        loading = false
    }
}

// MARK: - Assistente de primeira configuração (DADOS REAIS)

struct HLSetupView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var hosts: HostStore

    @State private var status: [String: Bool] = [:]
    @State private var loading = false
    @State private var pendingTask: TaskRequest?

    private var host: RemoteHost? {
        guard let id = state.activeHost.remoteID else { return nil }
        return hosts.hosts.first { $0.id == id }
    }

    private var appliedCount: Int { ServerSetup.steps.filter { status[$0.id] == true }.count }

    var body: some View {
        Group {
            if let host { content(host) }
            else { ContentUnavailableView("Nenhum host selecionado", systemImage: "server.rack") }
        }
        .task(id: host?.id) { await load() }
        .sheet(item: $pendingTask) { req in
            if let host {
                RemoteTaskSheet(title: req.title, host: host, args: req.args)
                    .onDisappear { Task { await load() } }
            }
        }
    }

    private func content(_ host: RemoteHost) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Configuração", subtitle: "\(appliedCount) de \(ServerSetup.steps.count) aplicados") {
                    if loading { ProgressView().controlSize(.small) }
                    IconButton(systemImage: "arrow.clockwise", help: "Reverificar") { Task { await load() } }
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "wand.and.stars").foregroundStyle(.blue)
                    Text("Deixa o servidor pronto e mais seguro em poucos cliques. Cada passo mostra o que faz e roda com log ao vivo. Melhora também a nota da Auditoria (Lynis).")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()

                VStack(spacing: 8) {
                    ForEach(ServerSetup.steps) { step in
                        let done = status[step.id] == true
                        CardRow {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(done ? .green : .secondary).padding(.top, 1)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.title).fontWeight(.medium)
                                    Text(step.detail).font(.caption).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        } trailing: {
                            if done {
                                Text("Aplicado").font(.callout).foregroundStyle(.green)
                            } else {
                                Button { pendingTask = TaskRequest(title: step.title, args: step.args) } label: {
                                    Label("Aplicar", systemImage: "play.fill")
                                }
                            }
                        }
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    @MainActor
    private func load() async {
        guard let host else { return }
        loading = true
        status = await ServerSetup.status(host)
        loading = false
    }
}

// MARK: - Máquinas (VMs / LXC)

private struct MockVM: Identifiable { let id = UUID(); let name: String; let os: String; let on: Bool; let cpu: Double; let ram: Double }

struct HLMachinesView: View {
    let sub: String?
    private let vms: [MockVM] = [
        MockVM(name: "ubuntu-docker", os: "Ubuntu Server 24.04", on: true, cpu: 0.18, ram: 0.52),
        MockVM(name: "truenas", os: "TrueNAS SCALE", on: true, cpu: 0.06, ram: 0.44),
        MockVM(name: "lab-testes", os: "Debian 12", on: false, cpu: 0, ram: 0),
    ]
    private let lxc: [MockVM] = [
        MockVM(name: "pihole", os: "LXC · Alpine", on: true, cpu: 0.02, ram: 0.10),
        MockVM(name: "nginx-proxy", os: "LXC · Debian", on: true, cpu: 0.01, ram: 0.08),
    ]

    var body: some View {
        if sub == "lxc" {
            HLScreen(title: "Containers LXC", subtitle: "\(lxc.count) containers · Proxmox") { list(lxc) }
        } else {
            HLScreen(title: "Máquinas virtuais", subtitle: "\(vms.count) VMs · 2 ligadas") { list(vms) }
        }
    }

    private func list(_ items: [MockVM]) -> some View {
        VStack(spacing: 8) {
            ForEach(items) { vm in
                CardRow {
                    HStack(spacing: 12) {
                        Circle().fill(vm.on ? Color.green : Color.secondary).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(vm.name).fontWeight(.medium)
                            Text(vm.os).font(.caption).foregroundStyle(.secondary)
                            if vm.on {
                                HStack(spacing: 8) {
                                    Text("CPU").font(.caption2).foregroundStyle(.secondary)
                                    HLBar(value: vm.cpu, tint: .blue).frame(width: 80)
                                    Text("RAM").font(.caption2).foregroundStyle(.secondary)
                                    HLBar(value: vm.ram, tint: .purple).frame(width: 80)
                                }
                            }
                        }
                    }
                } trailing: {
                    if vm.on {
                        IconButton(systemImage: "stop.circle", help: "Desligar (prévia)")
                        IconButton(systemImage: "arrow.clockwise.circle", help: "Reiniciar (prévia)")
                    } else {
                        IconButton(systemImage: "play.circle", help: "Ligar (prévia)")
                    }
                    IconButton(systemImage: "terminal", help: "Console (prévia)")
                }
            }
        }
    }
}

// MARK: - Containers Docker (DADOS REAIS via SSH)

private struct DockerRemoval: Identifiable {
    let id = UUID()
    let kind: String        // "container" | "image" | "volume"
    let name: String        // nome/id para remover
    let label: String       // texto amigável na confirmação
}
private struct LogTarget: Identifiable { let id = UUID(); let name: String }

struct HLContainersView: View {
    let sub: String?
    @EnvironmentObject var state: AppState
    @EnvironmentObject var hosts: HostStore

    @State private var containers: [RemoteContainer] = []
    @State private var images: [RemoteImage] = []
    @State private var volumes: [RemoteVolume] = []
    @State private var loading = false
    @State private var error: String?
    @State private var busy: String?
    @State private var logTarget: LogTarget?
    @State private var pendingRemoval: DockerRemoval?

    private var host: RemoteHost? {
        guard let id = state.activeHost.remoteID else { return nil }
        return hosts.hosts.first { $0.id == id }
    }

    var body: some View {
        Group {
            if let host {
                content(host)
            } else {
                ContentUnavailableView("Nenhum host selecionado", systemImage: "server.rack")
            }
        }
        .task(id: "\(host?.id.uuidString ?? "")-\(sub ?? "")") { await load() }
        .sheet(item: $logTarget) { t in
            if let host { ContainerLogsSheet(host: host, name: t.name) }
        }
        .confirmationDialog("Remover \(pendingRemoval?.label ?? "")?",
                            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
                            titleVisibility: .visible) {
            if let r = pendingRemoval {
                Button("Remover", role: .destructive) { remove(r) }
            }
            Button("Cancelar", role: .cancel) { pendingRemoval = nil }
        } message: {
            Text("Esta ação não pode ser desfeita.")
        }
    }

    @ViewBuilder
    private func content(_ host: RemoteHost) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: title, subtitle: subtitle) {
                    if loading { ProgressView().controlSize(.small) }
                    IconButton(systemImage: "arrow.clockwise", help: "Atualizar") { Task { await load() } }
                }
                if let error { ErrorBanner(error) { self.error = nil } }

                switch sub {
                case "images": imageList
                case "volumes": volumeList
                default: containerList(host)
                }
            }
            .screenPadding()
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private var title: String { sub == "images" ? "Imagens" : (sub == "volumes" ? "Volumes" : "Containers") }
    private var subtitle: String {
        switch sub {
        case "images": return "\(images.count) imagens"
        case "volumes": return "\(volumes.count) volumes"
        default:
            let running = containers.filter(\.isRunning).count
            return "\(containers.count) containers · \(running) rodando"
        }
    }

    // MARK: Containers

    @ViewBuilder
    private func containerList(_ host: RemoteHost) -> some View {
        if containers.isEmpty && !loading && error == nil {
            ContentUnavailableView("Nenhum container", systemImage: "shippingbox").padding(.top, 20)
        } else {
            VStack(spacing: 8) {
                ForEach(containers) { c in
                    CardRow {
                        HStack(spacing: 12) {
                            Circle().fill(c.isRunning ? Color.green : Color.secondary).frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name).fontWeight(.medium)
                                Text("\(c.image) · \(c.status)").font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(1).truncationMode(.middle)
                                if !c.ports.isEmpty {
                                    Text(c.ports).font(.caption2).foregroundStyle(.secondary)
                                        .lineLimit(1).truncationMode(.middle)
                                }
                            }
                        }
                    } trailing: {
                        if busy == c.id {
                            ProgressView().controlSize(.small).frame(width: 24, height: 24)
                        } else {
                            if c.isRunning {
                                IconButton(systemImage: "stop.circle", help: "Parar") { act(.stop, c) }
                                IconButton(systemImage: "arrow.clockwise.circle", help: "Reiniciar") { act(.restart, c) }
                            } else {
                                IconButton(systemImage: "play.circle", help: "Iniciar") { act(.start, c) }
                            }
                            IconButton(systemImage: "doc.plaintext", help: "Ver logs") { logTarget = LogTarget(name: c.name) }
                            IconButton(systemImage: "trash", help: "Remover container") {
                                pendingRemoval = DockerRemoval(kind: "container", name: c.name, label: "o container \(c.name)")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Imagens

    @ViewBuilder
    private var imageList: some View {
        VStack(spacing: 8) {
            ForEach(images) { img in
                CardRow {
                    HStack(spacing: 12) {
                        Image(systemName: "square.stack.3d.up").foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(img.repoTag).lineLimit(1).truncationMode(.middle)
                            Text(img.imageID).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                } trailing: {
                    Text(img.size).font(.callout).foregroundStyle(.secondary)
                    IconButton(systemImage: "trash", help: "Remover imagem") {
                        pendingRemoval = DockerRemoval(kind: "image", name: img.imageID, label: "a imagem \(img.repoTag)")
                    }
                }
            }
        }
    }

    // MARK: Volumes

    @ViewBuilder
    private var volumeList: some View {
        VStack(spacing: 8) {
            ForEach(volumes) { v in
                CardRow {
                    HStack(spacing: 12) {
                        Image(systemName: "externaldrive").foregroundStyle(.secondary)
                        Text(v.name).lineLimit(1).truncationMode(.middle)
                    }
                } trailing: {
                    Text(v.driver).font(.callout).foregroundStyle(.secondary)
                    IconButton(systemImage: "trash", help: "Remover volume") {
                        pendingRemoval = DockerRemoval(kind: "volume", name: v.name, label: "o volume \(v.name)")
                    }
                }
            }
        }
    }

    // MARK: Ações

    @MainActor
    private func load() async {
        guard let host else { return }
        loading = true
        error = nil
        switch sub {
        case "images": images = await RemoteDocker.images(host)
        case "volumes": volumes = await RemoteDocker.volumes(host)
        default:
            let r = await RemoteDocker.containers(host)
            containers = r.items
            error = r.error
        }
        loading = false
    }

    private func act(_ action: RemoteDocker.ContainerAction, _ c: RemoteContainer) {
        guard let host else { return }
        busy = c.id
        Task {
            let r = await RemoteDocker.container(host, action, c.name)
            if !r.ok { error = (r.stderr.isEmpty ? r.stdout : r.stderr).trimmingCharacters(in: .whitespacesAndNewlines) }
            await load()
            busy = nil
        }
    }

    private func remove(_ r: DockerRemoval) {
        guard let host else { return }
        busy = r.name
        Task {
            let result: CommandResult
            switch r.kind {
            case "image": result = await RemoteDocker.removeImage(host, r.name)
            case "volume": result = await RemoteDocker.removeVolume(host, r.name)
            default: result = await RemoteDocker.container(host, .remove, r.name)
            }
            if !result.ok { error = (result.stderr.isEmpty ? result.stdout : result.stderr).trimmingCharacters(in: .whitespacesAndNewlines) }
            await load()
            busy = nil
        }
    }
}

/// Folha com os logs de um container.
struct ContainerLogsSheet: View {
    let host: RemoteHost
    let name: String
    @Environment(\.dismiss) private var dismiss
    @State private var text = "Carregando…"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Logs · \(name)").font(.headline)
                Spacer()
                Button("Fechar") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            ScrollView {
                Text(text).font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
            }
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
        }
        .padding(16)
        .frame(width: 660, height: 460)
        .task { text = await RemoteDocker.logs(host, name) }
    }
}

// MARK: - Catálogo (templates de serviços, deploy 1 clique)

struct HLCatalogView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var hosts: HostStore

    @State private var installed: [String: RemoteContainer] = [:]   // nome → container
    @State private var installing: ServiceTemplate?
    @State private var panel: PanelTarget?
    @State private var stackTask: TaskRequest?

    private var host: RemoteHost? {
        guard let id = state.activeHost.remoteID else { return nil }
        return hosts.hosts.first { $0.id == id }
    }

    var body: some View {
        Group {
            if let host { content(host) }
            else { ContentUnavailableView("Nenhum host selecionado", systemImage: "server.rack") }
        }
        .task(id: host?.id) { await loadInstalled() }
        .sheet(item: $installing) { template in
            if let host {
                TemplateInstallSheet(host: host, template: template)
                    .onDisappear { Task { await loadInstalled() } }
            }
        }
        .sheet(item: $panel) { p in ServicePanelSheet(title: p.title, url: p.url) }
        .sheet(item: $stackTask) { req in
            if let host {
                RemoteTaskSheet(title: req.title, host: host, args: req.args)
                    .onDisappear { Task { await loadInstalled() } }
            }
        }
    }

    private func content(_ host: RemoteHost) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Catálogo", subtitle: "Serviços prontos — instale com 1 clique (Docker)")

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle").foregroundStyle(.blue)
                    Text("Escolha um serviço, ajuste a porta (e senha, se pedir) e instale. O Uptend sobe o container no servidor e mostra o endereço para acessar.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()

                ForEach(ServiceCatalog.categories, id: \.self) { category in
                    Text(category).font(.headline).padding(.top, 4)
                    ForEach(ServiceCatalog.templates.filter { $0.category == category }) { t in
                        row(t)
                    }
                }

                Text("Stacks avançados").font(.headline).padding(.top, 8)
                Text("Serviços pesados (vários containers). Só instalam quando você clicar — ideal para servidor com bastante RAM.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(ServiceCatalog.stacks) { stack in stackRow(stack) }
            }
            .screenPadding()
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private func stackRow(_ stack: ServiceStack) -> some View {
        CardRow {
            HStack(spacing: 12) {
                Image(systemName: stack.icon).font(.title3).foregroundStyle(.orange).frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(stack.name).fontWeight(.medium)
                    Text(stack.description).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(stack.ramNote, systemImage: "exclamationmark.triangle")
                        .font(.caption2).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
            }
        } trailing: {
            Button { stackTask = TaskRequest(title: "Instalar \(stack.name)", args: stack.deployArgs) } label: {
                Label("Instalar", systemImage: "arrow.down.circle")
            }
            .help(stack.openNote)
        }
    }

    private func row(_ t: ServiceTemplate) -> some View {
        let container = installed[t.id]
        return CardRow {
            HStack(spacing: 12) {
                Image(systemName: t.icon).font(.title3).foregroundStyle(.blue).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.name).fontWeight(.medium)
                    Text(t.description).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } trailing: {
            if let container {
                Label("Instalado", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green).labelStyle(.iconOnly)
                    .help(container.isRunning ? "Instalado e rodando" : "Instalado (parado)")
                    .frame(width: 24, height: 24)
                if let url = openURL(t, container) {
                    Button { panel = PanelTarget(title: t.name, url: url) } label: { Label("Abrir painel", systemImage: "macwindow") }
                        .help("Abre o painel do serviço dentro do Uptend")
                }
            } else {
                Button { installing = t } label: { Label("Instalar", systemImage: "arrow.down.circle") }
            }
        }
    }

    /// URL de acesso de um serviço instalado (descobre a porta real do container).
    private func openURL(_ t: ServiceTemplate, _ container: RemoteContainer) -> URL? {
        guard let host, container.isRunning, let cp = t.webContainerPort,
              let hp = ServiceTemplate.hostPort(forContainerPort: cp, in: container.ports) else { return nil }
        return URL(string: "http://\(host.address):\(hp)")
    }

    @MainActor
    private func loadInstalled() async {
        guard let host else { return }
        let r = await RemoteDocker.containers(host)
        installed = Dictionary(uniqueKeysWithValues: r.items.map { ($0.name, $0) })
    }
}

/// Folha de instalação de um template: formulário → deploy com log ao vivo.
struct TemplateInstallSheet: View {
    let host: RemoteHost
    let template: ServiceTemplate
    @Environment(\.dismiss) private var dismiss
    @StateObject private var task = RemoteTask()

    @State private var name: String
    @State private var fields: [TemplateField]
    @State private var error: String?

    init(host: RemoteHost, template: ServiceTemplate) {
        self.host = host
        self.template = template
        _name = State(initialValue: template.id)
        _fields = State(initialValue: template.fields)
    }

    private var url: String? {
        guard task.finished, task.success, let p = template.webHostPort(fields) else { return nil }
        return "http://\(host.address):\(p)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: template.icon).foregroundStyle(.blue)
                Text(template.name).font(.title3).fontWeight(.medium)
                Spacer()
            }

            if task.running || task.finished {
                logView
            } else {
                formView
            }
        }
        .padding(20)
        .frame(width: 500, height: 460)
    }

    private var formView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(template.description).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            field("Nome do container", text: $name)
            ForEach($fields) { $f in
                if f.kind == .password {
                    secureField(f.label, text: $f.value)
                } else {
                    field(f.label, text: $f.value)
                }
            }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill").font(.callout).foregroundStyle(.orange)
            }

            Text("Imagem: \(template.image)").font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)

            Spacer()
            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Instalar") { install() }.keyboardShortcut(.defaultAction)
            }
        }
    }

    private var logView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if task.running { ProgressView().controlSize(.small); Text("Instalando… (pode baixar a imagem)").foregroundStyle(.secondary) }
                else if task.success { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green); Text("Instalado!").fontWeight(.medium) }
                else { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange); Text("Falhou").fontWeight(.medium) }
            }
            if task.finished && task.success {
                Text("O serviço pode levar alguns segundos para ficar pronto na primeira vez.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    Text(task.log).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                    Color.clear.frame(height: 1).id("bottom")
                }
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
                .onChange(of: task.log) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
            }
            HStack {
                if let url {
                    Button { if let u = URL(string: url) { NSWorkspace.shared.open(u) } } label: {
                        Label("Abrir \(url)", systemImage: "arrow.up.right.square")
                    }
                }
                Spacer()
                Button("Fechar") { dismiss() }.keyboardShortcut(.defaultAction).disabled(task.running)
            }
        }
    }

    private func install() {
        if let e = template.validate(name: name, fields: fields) { error = e; return }
        error = nil
        task.run(host: host, args: template.dockerRunArgs(name: name, fields: fields))
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField("", text: text).textFieldStyle(.roundedBorder)
        }
    }
    private func secureField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            SecureField("", text: text).textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: - Deploy do Mac para o servidor (DADOS REAIS)

struct HLDeployView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var hosts: HostStore

    @State private var name = ""
    @State private var localPath = ""
    @State private var port = ""
    @State private var transferring = false
    @State private var error: String?
    @State private var pendingTask: TaskRequest?

    private var host: RemoteHost? {
        guard let id = state.activeHost.remoteID else { return nil }
        return hosts.hosts.first { $0.id == id }
    }

    private var hasDockerfile: Bool {
        !localPath.isEmpty && FileManager.default.fileExists(atPath: localPath + "/Dockerfile")
    }
    private var canDeploy: Bool {
        InputValidator.isValidContainerName(name.trimmingCharacters(in: .whitespaces))
            && hasDockerfile
            && (port.isEmpty || RemoteDeploy.isValidPortMapping(port.trimmingCharacters(in: .whitespaces)))
            && !transferring
    }

    var body: some View {
        Group {
            if let host { content(host) }
            else { ContentUnavailableView("Nenhum host selecionado", systemImage: "server.rack") }
        }
        .sheet(item: $pendingTask) { req in
            if let host { RemoteTaskSheet(title: req.title, host: host, args: req.args) }
        }
        .task(id: host?.id) {
            // Ao trocar de servidor, limpa o formulário para não fazer deploy no host errado.
            name = ""; localPath = ""; port = ""; error = nil
        }
    }

    private func content(_ host: RemoteHost) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Meu projeto", subtitle: "Deploy do Mac para o servidor")

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle").foregroundStyle(.blue)
                    Text("Escolha uma pasta que tenha um Dockerfile. O Uptend envia pro servidor, builda a imagem lá (evita problema de arquitetura) e sobe o container.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()

                field("Nome do app", "ex.: meu-site", text: $name)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Pasta do projeto").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Text(localPath.isEmpty ? "Nenhuma pasta escolhida" : localPath)
                            .font(.callout).foregroundStyle(localPath.isEmpty ? .secondary : .primary)
                            .lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button("Escolher pasta…") { pickFolder() }
                    }
                    .padding(8).cardBackground()
                    if !localPath.isEmpty && !hasDockerfile {
                        Label("Esta pasta não tem um Dockerfile.", systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }

                field("Porta (opcional) — host:container", "ex.: 8080:80", text: $port)

                if let error { ErrorBanner(error) { self.error = nil } }

                HStack(spacing: 8) {
                    Button { deploy(host) } label: { Label("Fazer deploy", systemImage: "arrow.up.forward.app") }
                        .disabled(!canDeploy)
                    if transferring {
                        ProgressView().controlSize(.small); Text("Enviando arquivos…").foregroundStyle(.secondary).font(.callout)
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        panel.prompt = "Usar esta pasta"
        if panel.runModal() == .OK, let url = panel.url {
            localPath = url.path
            if name.isEmpty { name = url.lastPathComponent.lowercased().replacingOccurrences(of: " ", with: "-") }
        }
    }

    private func deploy(_ host: RemoteHost) {
        let appName = name.trimmingCharacters(in: .whitespaces)
        error = nil
        transferring = true
        Task {
            let t = await RemoteDeploy.transfer(host, localPath: localPath, name: appName)
            transferring = false
            guard t.ok else {
                error = "Falha ao enviar: " + (t.stderr.isEmpty ? t.stdout : t.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
                return
            }
            pendingTask = TaskRequest(title: "Deploy de \(appName)",
                                      args: RemoteDeploy.buildRunArgs(host, name: appName, port: port.trimmingCharacters(in: .whitespaces)))
        }
    }

    private func field(_ label: String, _ prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(prompt, text: text).textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: - Serviços (systemd) — DADOS REAIS

struct HLServicesView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var hosts: HostStore

    @State private var services: [ServiceUnit] = []
    @State private var loading = false
    @State private var error: String?
    @State private var busy: String?
    @State private var filter = ""
    @State private var pendingAction: PendingServiceAction?

    /// Ação pedida sobre um serviço, à espera de confirmação (só para as arriscadas).
    private struct PendingServiceAction: Identifiable {
        let id = UUID()
        let action: RemoteSystemd.Action
        let svc: ServiceUnit
    }

    /// Serviços em que parar/desabilitar pode te trancar para fora ou derrubar tudo.
    private static let sensitive = ["ssh", "sshd", "docker", "systemd-networkd",
                                    "NetworkManager", "network", "systemd-logind"]
    private func isSensitive(_ svc: ServiceUnit) -> Bool {
        Self.sensitive.contains(svc.shortName)
    }

    private var host: RemoteHost? {
        guard let id = state.activeHost.remoteID else { return nil }
        return hosts.hosts.first { $0.id == id }
    }

    private var filtered: [ServiceUnit] {
        let q = filter.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return services }
        return services.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        Group {
            if let host { content(host) }
            else { ContentUnavailableView("Nenhum host selecionado", systemImage: "server.rack") }
        }
        .task(id: host?.id) { await load() }
        .confirmationDialog(pendingAction.map { "\($0.action == .stop ? "Parar" : "Desabilitar") \($0.svc.shortName)?" } ?? "",
                            isPresented: Binding(get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } }),
                            titleVisibility: .visible) {
            if let p = pendingAction {
                Button(p.action == .stop ? "Parar mesmo assim" : "Desabilitar mesmo assim",
                       role: .destructive) { act(p.action, p.svc) }
            }
            Button("Cancelar", role: .cancel) { pendingAction = nil }
        } message: {
            Text("Este é um serviço crítico. Pará-lo ou desabilitá-lo pode te desconectar do servidor (SSH) ou derrubar seus containers (Docker) — inclusive no próximo boot.")
        }
    }

    private func content(_ host: RemoteHost) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Serviços", subtitle: "\(services.count) serviços · systemd") {
                    if loading { ProgressView().controlSize(.small) }
                    IconButton(systemImage: "arrow.clockwise", help: "Atualizar") { Task { await load() } }
                }
                if let error { ErrorBanner(error) { self.error = nil } }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Filtrar serviços…", text: $filter).textFieldStyle(.plain)
                }
                .padding(10).cardBackground()

                VStack(spacing: 8) {
                    ForEach(filtered) { svc in row(svc) }
                }
            }
            .screenPadding()
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private func row(_ svc: ServiceUnit) -> some View {
        CardRow {
            HStack(spacing: 10) {
                Circle().fill(svc.isRunning ? Color.green : Color.secondary).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(svc.shortName).fontWeight(.medium)
                        if svc.enabled {
                            Text("no boot").font(.caption2)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(.blue.opacity(0.12), in: Capsule()).foregroundStyle(.blue)
                        }
                    }
                    Text("\(svc.active) · \(svc.sub)\(svc.description.isEmpty ? "" : " · \(svc.description)")")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                }
            }
        } trailing: {
            if busy == svc.id {
                ProgressView().controlSize(.small).frame(width: 24, height: 24)
            } else {
                if svc.isRunning {
                    IconButton(systemImage: "stop.circle", help: "Parar") { request(.stop, svc) }
                    IconButton(systemImage: "arrow.clockwise.circle", help: "Reiniciar") { act(.restart, svc) }
                } else {
                    IconButton(systemImage: "play.circle", help: "Iniciar") { act(.start, svc) }
                }
                IconButton(systemImage: svc.enabled ? "bolt.slash" : "bolt",
                           help: svc.enabled ? "Desabilitar no boot" : "Habilitar no boot") {
                    request(svc.enabled ? .disable : .enable, svc)
                }
            }
        }
    }

    @MainActor
    private func load() async {
        guard let host else { return }
        loading = true; error = nil
        let r = await RemoteSystemd.services(host)
        services = r.items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        error = r.error
        loading = false
    }

    /// Pede a ação; se for arriscada (parar/desabilitar um serviço crítico), confirma antes.
    private func request(_ action: RemoteSystemd.Action, _ svc: ServiceUnit) {
        if (action == .stop || action == .disable), isSensitive(svc) {
            pendingAction = PendingServiceAction(action: action, svc: svc)
        } else {
            act(action, svc)
        }
    }

    private func act(_ action: RemoteSystemd.Action, _ svc: ServiceUnit) {
        guard let host else { return }
        pendingAction = nil
        busy = svc.id
        Task {
            let r = await RemoteSystemd.perform(host, action, svc.name)
            if !r.ok {
                let e = (r.stderr.isEmpty ? r.stdout : r.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
                error = e.contains("password") || e.contains("sudo") ? "Precisa de sudo sem senha para esta ação. \(e)" : e
            }
            await load()
            busy = nil
        }
    }
}

// MARK: - Segurança: Status (DADOS REAIS)

struct HLSecurityStatusView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var hosts: HostStore

    @State private var checks: [ServerSecurityCheck] = []
    @State private var loading = false

    private var host: RemoteHost? {
        guard let id = state.activeHost.remoteID else { return nil }
        return hosts.hosts.first { $0.id == id }
    }

    var body: some View {
        Group {
            if let host { content(host) }
            else { ContentUnavailableView("Nenhum host selecionado", systemImage: "server.rack") }
        }
        .task(id: host?.id) { await load() }
    }

    private func content(_ host: RemoteHost) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Segurança", subtitle: statusSummary) {
                    if loading { ProgressView().controlSize(.small) }
                    IconButton(systemImage: "arrow.clockwise", help: "Reverificar") { Task { await load() } }
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle").foregroundStyle(.blue)
                    Text("Um retrato rápido da postura de segurança do servidor. Verde = ok, amarelo = melhorar, vermelho = corrigir.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()

                VStack(spacing: 8) {
                    ForEach(checks) { c in
                        CardRow {
                            HStack(spacing: 10) {
                                Semaforo(level: c.level)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.title).fontWeight(.medium)
                                    Text(c.detail).font(.caption).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        } trailing: { EmptyView() }
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private var statusSummary: String {
        if loading && checks.isEmpty { return "Verificando…" }
        let problems = checks.filter { $0.level == 2 }.count
        let warns = checks.filter { $0.level == 1 }.count
        if problems == 0 && warns == 0 { return "Tudo certo" }
        return "\(problems) a corrigir · \(warns) a melhorar"
    }

    @MainActor
    private func load() async {
        guard let host else { return }
        loading = true
        checks = await RemoteSecurity.status(host)
        loading = false
    }
}

// MARK: - Segurança: Central de Monitoramento (SIEM leve, DADOS REAIS)

private struct FixTarget: Identifiable { let id: String; let event: SecurityEvent; let fix: SecurityMonitor.Fix }
private struct AppliedFix: Identifiable { let id = UUID(); let title: String; let undoArgs: [String] }

struct HLMonitorView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var hosts: HostStore

    @State private var events: [SecurityEvent] = []
    @State private var loading = false
    @State private var previewFix: FixTarget?
    @State private var applied: [AppliedFix] = []
    @State private var pendingTask: TaskRequest?
    @State private var pendingRevert: AppliedFix?

    private var host: RemoteHost? {
        guard let id = state.activeHost.remoteID else { return nil }
        return hosts.hosts.first { $0.id == id }
    }

    var body: some View {
        Group {
            if let host { content(host) }
            else { ContentUnavailableView("Nenhum host selecionado", systemImage: "server.rack") }
        }
        // Limpa a lista de "reverter" ao TROCAR de host (evita reverter no servidor errado).
        .task(id: host?.id) { applied = []; await load() }
        .sheet(item: $previewFix) { t in
            if let host {
                FixPreviewSheet(event: t.event, fix: t.fix, host: host,
                                onApplied: { applied.append(AppliedFix(title: t.event.title, undoArgs: t.fix.undoArgs ?? [])) })
                    .onDisappear { Task { await load() } }
            }
        }
        .sheet(item: $pendingTask) { req in
            if let host {
                RemoteTaskSheet(title: req.title, host: host, args: req.args)
                    .onDisappear { Task { await load() } }
            }
        }
        .confirmationDialog("Reverter \"\(pendingRevert?.title ?? "")\"?",
                            isPresented: Binding(get: { pendingRevert != nil }, set: { if !$0 { pendingRevert = nil } }),
                            titleVisibility: .visible) {
            if let af = pendingRevert {
                Button("Reverter", role: .destructive) {
                    pendingTask = TaskRequest(title: "Reverter: \(af.title)", args: af.undoArgs)
                    applied.removeAll { $0.id == af.id }
                }
            }
            Button("Cancelar", role: .cancel) { pendingRevert = nil }
        } message: {
            Text("Isto desfaz a correção — pode reduzir a segurança do servidor (ex.: reativar login por senha).")
        }
    }

    private func content(_ host: RemoteHost) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Monitoramento", subtitle: summary) {
                    if loading { ProgressView().controlSize(.small) }
                    IconButton(systemImage: "arrow.clockwise", help: "Verificar agora") { Task { await load() } }
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle").foregroundStyle(.blue)
                    Text("Um raio-x de segurança do servidor, em português: o que está acontecendo e como corrigir. Onde há conserto conhecido, use \"Corrigir…\" — ele mostra o que vai fazer antes.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()

                // Ponte para o SIEM completo (Wazuh), que precisa ser instalado antes.
                CardRow {
                    HStack(spacing: 10) {
                        Image(systemName: "shield.checkerboard").foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quer monitoramento avançado (SIEM completo)?").fontWeight(.medium)
                            Text("Este é o monitoramento nativo (leve). Para análise de logs e detecção de vulnerabilidades, instale o Wazuh — é pesado e opcional.")
                                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } trailing: {
                    Button {
                        state.homelabSection = .catalog
                        state.homelabSubID = "catalog"
                    } label: { Label("Instalar no Catálogo", systemImage: "arrow.up.forward.app") }
                    .help("Abre o Catálogo ▸ Stacks avançados, onde o Wazuh fica")
                }

                if !applied.isEmpty {
                    Text("Correções aplicadas nesta sessão").font(.headline)
                    VStack(spacing: 8) {
                        ForEach(applied) { af in
                            CardRow {
                                HStack(spacing: 10) {
                                    Image(systemName: "arrow.uturn.backward.circle").foregroundStyle(.secondary)
                                    Text(af.title)
                                }
                            } trailing: {
                                Button("Reverter") { pendingRevert = af }
                            }
                        }
                    }
                }

                VStack(spacing: 8) {
                    ForEach(events) { e in row(e) }
                }
            }
            .screenPadding()
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private func row(_ e: SecurityEvent) -> some View {
        let fix = e.level > 0 ? SecurityMonitor.fix(for: e.id) : nil
        return CardRow {
            HStack(alignment: .top, spacing: 10) {
                Semaforo(level: e.level).padding(.top, 4)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(e.title).fontWeight(.medium)
                        Text(e.category).font(.caption2)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.quaternary, in: Capsule()).foregroundStyle(.secondary)
                    }
                    Text(e.detail).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !e.remediation.isEmpty {
                        Label(e.remediation, systemImage: "wrench.and.screwdriver")
                            .font(.caption).foregroundStyle(.blue).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        } trailing: {
            if let fix {
                Button { previewFix = FixTarget(id: e.id, event: e, fix: fix) } label: {
                    Label("Corrigir…", systemImage: "wand.and.stars")
                }
            }
        }
    }

    private var summary: String {
        if loading && events.isEmpty { return "Verificando…" }
        let crit = events.filter { $0.level == 2 }.count
        let warn = events.filter { $0.level == 1 }.count
        if crit == 0 && warn == 0 { return "Tudo tranquilo" }
        return "\(crit) crítico(s) · \(warn) atenção"
    }

    @MainActor
    private func load() async {
        guard let host else { return }
        loading = true
        events = await SecurityMonitor.scan(host)
        loading = false
    }
}

/// Prévia transparente de uma correção ("lupinha") + aplicar com log ao vivo, num sheet só.
struct FixPreviewSheet: View {
    let event: SecurityEvent
    let fix: SecurityMonitor.Fix
    let host: RemoteHost
    let onApplied: () -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var task = RemoteTask()

    private var commandText: String {
        fix.applyArgs.first == "bash" ? (fix.applyArgs.last ?? "") : fix.applyArgs.joined(separator: " ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Corrigir: \(event.title)").font(.title3).fontWeight(.medium)

            if !task.running && !task.finished {
                Text("O que o Uptend vai fazer:").font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(fix.steps.enumerated()), id: \.offset) { i, s in
                        Label("\(i + 1). \(s)", systemImage: "checkmark.circle").font(.callout).labelStyle(.titleOnly)
                    }
                }
                Text("Comando que será executado no servidor:").font(.caption).foregroundStyle(.secondary)
                Text(commandText).font(.system(.caption2, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
                Label(fix.reversible ? "Reversível — dá para desfazer depois (\"Reverter\")." : "Não reversível — não dá para desfazer com segurança.",
                      systemImage: fix.reversible ? "arrow.uturn.backward" : "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(fix.reversible ? .green : .orange)

                Spacer()
                HStack {
                    Spacer()
                    Button("Cancelar") { dismiss() }.keyboardShortcut(.cancelAction)
                    Button("Aplicar") {
                        task.run(host: host, args: fix.applyArgs)
                    }.keyboardShortcut(.defaultAction)
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(task.log.isEmpty ? "Aplicando…" : task.log)
                            .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
                    .onChange(of: task.log) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
                }
                HStack {
                    Spacer()
                    Button("Fechar") { dismiss() }.keyboardShortcut(.defaultAction).disabled(task.running)
                }
            }
        }
        .padding(20)
        .frame(width: 540, height: 460)
        // Só registra o "reverter" quando a correção realmente deu certo.
        .onChange(of: task.finished) { _, done in
            if done, task.success, fix.reversible { onApplied() }
        }
    }
}

// MARK: - Segurança: Auditoria (Lynis) — reusa o parser do Mac

struct HLAuditView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var hosts: HostStore

    @StateObject private var task = RemoteTask()
    @State private var index: Int?
    @State private var warnings: [LynisFinding] = []
    @State private var suggestions: [LynisFinding] = []
    @State private var parsing = false

    private var host: RemoteHost? {
        guard let id = state.activeHost.remoteID else { return nil }
        return hosts.hosts.first { $0.id == id }
    }

    var body: some View {
        Group {
            if let host { content(host) }
            else { ContentUnavailableView("Nenhum host selecionado", systemImage: "server.rack") }
        }
        .onChange(of: task.finished) { _, done in
            if done, task.success { Task { await parse() } }
        }
        // Ao trocar de host, zera o resultado (não mostrar a auditoria do host anterior).
        .task(id: host?.id) { index = nil; warnings = []; suggestions = [] }
    }

    private func content(_ host: RemoteHost) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Auditoria (Lynis)", subtitle: "Verificação de endurecimento (OSS)") {
                    if task.running || parsing { ProgressView().controlSize(.small) }
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle").foregroundStyle(.blue)
                    Text("O Lynis inspeciona o servidor e dá uma nota de endurecimento (0–100) com recomendações. Se não estiver instalado, o Uptend instala antes de rodar.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()

                if !task.running && !task.finished {
                    Button { task.run(host: host, args: RemoteSecurity.auditArgs) } label: {
                        Label("Instalar e rodar auditoria", systemImage: "play.fill")
                    }
                }

                if let index {
                    scoreCard(index)
                    findingsSection("Avisos", warnings, tint: .red)
                    findingsSection("Sugestões", suggestions, tint: .orange)
                    Button { task.run(host: host, args: RemoteSecurity.auditArgs) } label: {
                        Label("Rodar de novo", systemImage: "arrow.clockwise")
                    }.disabled(task.running)
                } else if task.running || (task.finished && parsing) {
                    logView
                } else if task.finished && !task.success {
                    ErrorBanner("A auditoria falhou. Veja a saída abaixo.")
                    logView
                }
            }
            .screenPadding()
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private func scoreCard(_ index: Int) -> some View {
        let tint: Color = index >= 75 ? .green : (index >= 50 ? .orange : .red)
        return HStack(spacing: 16) {
            ZStack {
                Circle().stroke(tint.opacity(0.25), lineWidth: 6).frame(width: 64, height: 64)
                Text("\(index)").font(.system(size: 24, weight: .semibold)).foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Índice de endurecimento").fontWeight(.medium)
                Text("\(warnings.count) aviso(s) · \(suggestions.count) sugestão(ões)")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    @ViewBuilder
    private func findingsSection(_ title: String, _ items: [LynisFinding], tint: Color) -> some View {
        if !items.isEmpty {
            Text("\(title) (\(items.count))").font(.headline).padding(.top, 4)
            VStack(spacing: 8) {
                ForEach(items) { f in
                    CardRow {
                        HStack(alignment: .top, spacing: 10) {
                            Circle().fill(tint).frame(width: 8, height: 8).padding(.top, 5)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.text).fixedSize(horizontal: false, vertical: true)
                                Text(f.category).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    } trailing: { EmptyView() }
                }
            }
        }
    }

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(task.log.isEmpty ? "Iniciando…" : task.log)
                    .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                Color.clear.frame(height: 1).id("bottom")
            }
            .frame(minHeight: 200, maxHeight: 320)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
            .onChange(of: task.log) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }

    @MainActor
    private func parse() async {
        guard let host else { return }
        parsing = true
        let r = await RemoteSecurity.readAudit(host)
        index = r.index
        warnings = r.warnings
        suggestions = r.suggestions
        parsing = false
    }
}

// MARK: - Discos e RAID (DADOS REAIS, leitura)

struct HLStorageView: View {
    let sub: String?
    @EnvironmentObject var state: AppState
    @EnvironmentObject var hosts: HostStore

    @State private var usage: [FSUsage] = []
    @State private var devices: [BlockDevice] = []
    @State private var raid = ""
    @State private var loading = false

    // SMART
    @State private var smartOut: [String: String] = [:]     // device → resultado
    @State private var smartRunning = false

    private var host: RemoteHost? {
        guard let id = state.activeHost.remoteID else { return nil }
        return hosts.hosts.first { $0.id == id }
    }

    var body: some View {
        Group {
            if let host { content(host) }
            else { ContentUnavailableView("Nenhum host selecionado", systemImage: "server.rack") }
        }
        .task(id: "\(host?.id.uuidString ?? "")-\(sub ?? "")") { await load() }
    }

    @ViewBuilder
    private func content(_ host: RemoteHost) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch sub {
                case "raid": raidScreen
                case "smart": smartScreen(host)
                default: disksScreen
                }
            }
            .screenPadding()
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    // Discos: uso dos sistemas de arquivos + dispositivos
    private var disksScreen: some View {
        Group {
            ScreenHeader(title: "Discos", subtitle: "Uso e dispositivos") {
                if loading { ProgressView().controlSize(.small) }
                IconButton(systemImage: "arrow.clockwise", help: "Atualizar") { Task { await load() } }
            }

            Text("Uso dos sistemas de arquivos").font(.headline)
            VStack(spacing: 8) {
                ForEach(usage) { u in
                    CardRow {
                        HStack(spacing: 12) {
                            Image(systemName: "internaldrive").foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(u.mount).fontWeight(.medium)
                                HLBar(value: u.usedFraction,
                                      tint: u.usedFraction > 0.85 ? .red : (u.usedFraction > 0.7 ? .orange : .accentColor))
                                    .frame(width: 240)
                                Text("\(u.source) · \(u.fstype)").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    } trailing: {
                        Text("\(u.usedLabel) de \(u.sizeLabel)").font(.callout).foregroundStyle(.secondary)
                    }
                }
            }

            Text("Dispositivos").font(.headline).padding(.top, 4)
            VStack(spacing: 8) {
                ForEach(devices) { d in
                    CardRow {
                        HStack(spacing: 10) {
                            Image(systemName: d.isDisk ? "internaldrive" : "square.split.2x1").foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(d.name).fontWeight(.medium)
                                Text("\(d.type)\(d.fstype.isEmpty ? "" : " · \(d.fstype)")\(d.mount.isEmpty ? "" : " · \(d.mount)")")
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                            }
                        }
                    } trailing: { Text(d.sizeLabel).font(.callout).foregroundStyle(.secondary) }
                }
            }
        }
    }

    // RAID
    private var raidScreen: some View {
        Group {
            ScreenHeader(title: "RAID", subtitle: "mdadm / ZFS") {
                if loading { ProgressView().controlSize(.small) }
                IconButton(systemImage: "arrow.clockwise", help: "Atualizar") { Task { await load() } }
            }
            CardRow {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "square.stack.3d.down.right").foregroundStyle(.secondary)
                    Text(raid.isEmpty ? "Verificando…" : raid).font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } trailing: { EmptyView() }
            Text("Criar/gerenciar arranjos RAID é uma operação destrutiva — será adicionada depois, com confirmações e em hardware real.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    // SMART
    private func smartScreen(_ host: RemoteHost) -> some View {
        Group {
            ScreenHeader(title: "Saúde (SMART)", subtitle: "Health check dos discos")

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle").foregroundStyle(.blue)
                Text("O SMART lê a saúde de discos físicos. Em discos virtuais (VM/OrbStack) costuma não estar disponível — vai funcionar num servidor com HDs/SSDs reais.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()

            Button {
                Task { await runSmart(host) }
            } label: {
                HStack(spacing: 6) {
                    if smartRunning { ProgressView().controlSize(.small) }
                    Text(smartRunning ? "Verificando…" : (smartOut.isEmpty ? "Instalar e verificar SMART" : "Verificar novamente"))
                }
            }.disabled(smartRunning)

            if !smartOut.isEmpty && !smartRunning {
                Label("Verificação concluída. Resultado por disco abaixo.", systemImage: "checkmark.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }

            ForEach(devices.filter { $0.isDisk }) { d in
                CardRow {
                    HStack(spacing: 10) {
                        Semaforo(level: smartLevel(smartOut[d.name]))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("/dev/\(d.name)").fontWeight(.medium)
                            Text(smartSummary(smartOut[d.name])).font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } trailing: { Text(d.sizeLabel).font(.callout).foregroundStyle(.secondary) }
            }
        }
    }

    // MARK: Lógica

    @MainActor
    private func load() async {
        guard let host else { return }
        loading = true
        smartOut = [:]   // zera resultados SMART (evita mostrar do host/estado anterior)
        switch sub {
        case "raid": raid = await RemoteDisks.raidStatus(host)
        case "smart": devices = await RemoteDisks.devices(host)
        default:
            async let u = RemoteDisks.usage(host)
            async let d = RemoteDisks.devices(host)
            usage = await u
            devices = await d
        }
        loading = false
    }

    @MainActor
    private func runSmart(_ host: RemoteHost) async {
        smartRunning = true
        // instala smartmontools se preciso
        if !(await RemoteDisks.smartInstalled(host)) {
            _ = await SSHRunner.run(host, RemoteDisks.installSmartArgs)
        }
        for d in devices where d.isDisk {
            smartOut[d.name] = await RemoteDisks.smart(host, device: d.name)
        }
        smartRunning = false
    }

    private func smartLevel(_ out: String?) -> Int {
        guard let out else { return 1 }
        let l = out.lowercased()
        if l.contains("passed") { return 0 }
        if l.contains("failed") { return 2 }
        return 1
    }
    private func smartSummary(_ out: String?) -> String {
        guard let out, !out.isEmpty else { return "Ainda não verificado." }
        if out.lowercased().contains("passed") { return "PASSED — saudável." }
        if out.lowercased().contains("failed") { return "FAILED — atenção!" }
        if out.lowercased().contains("unable") || out.lowercased().contains("unavailable") || out.lowercased().contains("open") {
            return "SMART não disponível neste disco (provável disco virtual)."
        }
        return String(out.prefix(140))
    }
}

// MARK: - Arquivos (SFTP) — DADOS REAIS

struct HLFilesView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var hosts: HostStore

    @State private var path = ""
    @State private var items: [RemoteFile] = []
    @State private var loading = false
    @State private var error: String?
    @State private var busy: String?
    @State private var transferMsg: String?
    @State private var showNewFolder = false
    @State private var newFolderName = ""
    @State private var pendingDelete: RemoteFile?

    private var host: RemoteHost? {
        guard let id = state.activeHost.remoteID else { return nil }
        return hosts.hosts.first { $0.id == id }
    }

    var body: some View {
        Group {
            if let host { content(host) }
            else { ContentUnavailableView("Nenhum host selecionado", systemImage: "server.rack") }
        }
        .task(id: host?.id) {
            if path.isEmpty, let host { path = "/home/\(host.user)" }
            await load()
        }
        .alert("Nova pasta", isPresented: $showNewFolder) {
            TextField("Nome", text: $newFolderName)
            Button("Criar") { createFolder() }
            Button("Cancelar", role: .cancel) { newFolderName = "" }
        } message: { Text("Criar em \(path)") }
        .confirmationDialog("Apagar \(pendingDelete?.name ?? "")?",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            if let f = pendingDelete {
                Button("Apagar", role: .destructive) { delete(f) }
            }
            Button("Cancelar", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("No servidor não há Lixeira — isto apaga de forma permanente.")
        }
    }

    private func content(_ host: RemoteHost) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ScreenHeader(title: "Arquivos", subtitle: path) {
                    if loading || busy != nil { ProgressView().controlSize(.small) }
                    IconButton(systemImage: "arrow.clockwise", help: "Atualizar") { Task { await load() } }
                }

                HStack(spacing: 8) {
                    IconButton(systemImage: "arrow.up", help: "Pasta acima") { navigate(to: RemoteFiles.parent(of: path)) }
                    TextField("/caminho", text: $path).textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await load() } }
                    Button("Ir") { Task { await load() } }
                    Button { showNewFolder = true } label: { Label("Nova pasta", systemImage: "folder.badge.plus") }
                    Button { upload(host) } label: { Label("Enviar", systemImage: "square.and.arrow.up") }
                }

                if let error { ErrorBanner(error) { self.error = nil } }
                if let transferMsg {
                    Label(transferMsg, systemImage: "info.circle").font(.callout).foregroundStyle(.secondary)
                }

                if items.isEmpty && !loading && error == nil {
                    ContentUnavailableView("Pasta vazia", systemImage: "folder").padding(.top, 20)
                } else {
                    VStack(spacing: 6) {
                        ForEach(items) { f in row(host, f) }
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private func row(_ host: RemoteHost, _ f: RemoteFile) -> some View {
        CardRow {
            HStack(spacing: 10) {
                Image(systemName: f.isDir ? "folder.fill" : (f.isLink ? "arrow.up.right.square" : "doc"))
                    .foregroundStyle(f.isDir ? .blue : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.name).fontWeight(f.isDir ? .medium : .regular)
                    Text("\(f.modified)\(f.isDir ? "" : " · \(f.sizeLabel)")").font(.caption).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { if f.isDir { navigate(to: childPath(f.name)) } }
            }
        } trailing: {
            if busy == f.name {
                ProgressView().controlSize(.small).frame(width: 24, height: 24)
            } else {
                if !f.isDir {
                    IconButton(systemImage: "square.and.arrow.down", help: "Baixar para o Mac") { download(host, f) }
                }
                IconButton(systemImage: "trash", help: "Apagar no servidor") { pendingDelete = f }
            }
        }
    }

    // MARK: Navegação/ações

    private func childPath(_ name: String) -> String { (path.hasSuffix("/") ? path : path + "/") + name }

    private func navigate(to newPath: String) {
        path = newPath
        Task { await load() }
    }

    @MainActor
    private func load() async {
        guard let host else { return }
        loading = true; error = nil
        let r = await RemoteFiles.list(host, path.trimmingCharacters(in: .whitespaces))
        items = r.items
        error = r.error
        loading = false
    }

    private func createFolder() {
        guard let host else { return }
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        newFolderName = ""
        guard !name.isEmpty else { return }
        Task {
            let r = await RemoteFiles.makeDir(host, in: path, name: name)
            if !r.ok { error = (r.stderr.isEmpty ? r.stdout : r.stderr).trimmingCharacters(in: .whitespacesAndNewlines) }
            await load()
        }
    }

    private func delete(_ f: RemoteFile) {
        guard let host else { return }
        busy = f.name
        Task {
            let r = await RemoteFiles.delete(host, childPath(f.name))
            if !r.ok { error = (r.stderr.isEmpty ? r.stdout : r.stderr).trimmingCharacters(in: .whitespacesAndNewlines) }
            await load()
            busy = nil
        }
    }

    private func download(_ host: RemoteHost, _ f: RemoteFile) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = f.name
        panel.prompt = "Baixar"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        busy = f.name
        transferMsg = nil
        Task {
            let r = await RemoteFiles.download(host, childPath(f.name), to: url.path)
            transferMsg = r.ok ? "Baixado: \(url.lastPathComponent)" : "Falha ao baixar: " + (r.stderr.isEmpty ? r.stdout : r.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
            busy = nil
        }
    }

    private func upload(_ host: RemoteHost) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.prompt = "Enviar"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        busy = "__upload"
        transferMsg = nil
        Task {
            let r = await RemoteFiles.upload(host, url.path, toDir: path)
            transferMsg = r.ok ? "Enviado: \(url.lastPathComponent)" : "Falha ao enviar: " + (r.stderr.isEmpty ? r.stdout : r.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
            await load()
            busy = nil
        }
    }
}

// MARK: - Backups (restic) — DADOS REAIS

struct HLBackupsView: View {
    let sub: String?
    @EnvironmentObject var state: AppState
    @EnvironmentObject var hosts: HostStore

    @State private var installed = false
    @State private var initialized = false
    @State private var snapshots: [BackupSnapshot] = []
    @State private var loading = false
    @State private var backupFolder = ""
    @State private var pendingTask: TaskRequest?
    @State private var restoreSnap: BackupSnapshot?
    @State private var restoreTarget = "/tmp/uptend-restore"

    private var host: RemoteHost? {
        guard let id = state.activeHost.remoteID else { return nil }
        return hosts.hosts.first { $0.id == id }
    }

    var body: some View {
        Group {
            if sub == "cloud" { cloudScreen }
            else if let host { localScreen(host) }
            else { ContentUnavailableView("Nenhum host selecionado", systemImage: "server.rack") }
        }
        .task(id: "\(host?.id.uuidString ?? "")-\(sub ?? "")") {
            if backupFolder.isEmpty, let host { backupFolder = "/home/\(host.user)" }
            if sub != "cloud" { await load() }
        }
        .sheet(item: $pendingTask) { req in
            if let host {
                RemoteTaskSheet(title: req.title, host: host, args: req.args)
                    .onDisappear { Task { await load() } }
            }
        }
        .alert("Restaurar snapshot", isPresented: Binding(get: { restoreSnap != nil }, set: { if !$0 { restoreSnap = nil } })) {
            TextField("Pasta de destino", text: $restoreTarget)
            Button("Restaurar") { doRestore() }
            Button("Cancelar", role: .cancel) { restoreSnap = nil }
        } message: {
            Text("Os arquivos do snapshot \(restoreSnap?.id ?? "") serão restaurados em \(restoreTarget) no servidor.")
        }
    }

    // Backups locais (restic)
    private func localScreen(_ host: RemoteHost) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Backups", subtitle: initialized ? "\(snapshots.count) snapshot(s)" : "restic (local, criptografado)") {
                    if loading { ProgressView().controlSize(.small) }
                    IconButton(systemImage: "arrow.clockwise", help: "Atualizar") { Task { await load() } }
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle").foregroundStyle(.blue)
                    Text("Backups incrementais e criptografados com o restic, num repositório local no servidor. A senha é gerada no servidor e guardada só-root — nunca sai daqui.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()

                if !initialized {
                    Button {
                        pendingTask = TaskRequest(title: "Preparar repositório de backup", args: RemoteBackup.prepareArgs)
                    } label: { Label("Preparar repositório de backup", systemImage: "wrench.and.screwdriver") }
                } else {
                    // Fazer backup de uma pasta
                    Text("Fazer backup").font(.headline)
                    HStack(spacing: 8) {
                        TextField("/pasta a salvar", text: $backupFolder).textFieldStyle(.roundedBorder)
                        Button { startBackup() } label: { Label("Fazer backup", systemImage: "arrow.up.doc") }
                            .disabled(!InputValidator.isSafeRemotePath(backupFolder.trimmingCharacters(in: .whitespaces)))
                    }

                    Text("Snapshots").font(.headline).padding(.top, 4)
                    if snapshots.isEmpty {
                        Text("Nenhum snapshot ainda.").font(.callout).foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(snapshots) { s in
                                CardRow {
                                    HStack(spacing: 10) {
                                        Image(systemName: "clock.arrow.circlepath").foregroundStyle(.blue)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(s.time).fontWeight(.medium)
                                            Text("\(s.paths.joined(separator: ", ")) · \(s.sizeLabel) · \(s.id)")
                                                .font(.caption).foregroundStyle(.secondary)
                                                .lineLimit(1).truncationMode(.middle)
                                        }
                                    }
                                } trailing: {
                                    Button { restoreSnap = s } label: { Label("Restaurar", systemImage: "arrow.down.doc") }
                                }
                            }
                        }
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    // Backup na nuvem (próximo passo)
    private var cloudScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Backup na nuvem", subtitle: "Próximo passo")
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "cloud").foregroundStyle(.blue)
                    Text("Em breve: enviar o mesmo repositório restic para a nuvem (Backblaze B2, S3, etc.), com as credenciais guardadas no Keychain do Mac. A base (restic) já está pronta na aba \"Backups locais\".")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
            }
            .screenPadding()
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    @MainActor
    private func load() async {
        guard let host else { return }
        loading = true
        let s = await RemoteBackup.status(host)
        installed = s.installed
        initialized = s.initialized
        if initialized { snapshots = await RemoteBackup.snapshots(host) }
        loading = false
    }

    private func startBackup() {
        let folder = backupFolder.trimmingCharacters(in: .whitespaces)
        guard InputValidator.isSafeRemotePath(folder) else { return }
        pendingTask = TaskRequest(title: "Backup de \(folder)", args: RemoteBackup.backupArgs(folder: folder))
    }

    private func doRestore() {
        guard let snap = restoreSnap else { return }
        let target = restoreTarget.trimmingCharacters(in: .whitespaces)
        restoreSnap = nil
        guard InputValidator.isSafeRemotePath(target) else { return }
        pendingTask = TaskRequest(title: "Restaurar \(snap.id) em \(target)", args: RemoteBackup.restoreArgs(id: snap.id, target: target))
    }
}

// MARK: - Rede (DADOS REAIS)

struct HLNetworkView: View {
    let sub: String?
    @EnvironmentObject var state: AppState
    @EnvironmentObject var hosts: HostStore

    @State private var info = NetworkInfo()
    @State private var ports: [RemoteListeningPort] = []
    @State private var loading = false

    // Ferramentas (ping/DNS)
    @State private var pingTarget = "1.1.1.1"
    @State private var pingOut = ""
    @State private var pinging = false
    @State private var dnsTarget = "github.com"
    @State private var dnsOut = ""
    @State private var resolving = false

    private var host: RemoteHost? {
        guard let id = state.activeHost.remoteID else { return nil }
        return hosts.hosts.first { $0.id == id }
    }

    var body: some View {
        Group {
            if let host { content(host) }
            else { ContentUnavailableView("Nenhum host selecionado", systemImage: "server.rack") }
        }
        .task(id: "\(host?.id.uuidString ?? "")-\(sub ?? "")") { await load() }
    }

    @ViewBuilder
    private func content(_ host: RemoteHost) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch sub {
                case "ports": portsScreen
                case "tools": toolsScreen(host)
                default: addressesScreen
                }
            }
            .screenPadding()
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    // Endereços
    private var addressesScreen: some View {
        Group {
            ScreenHeader(title: "Endereços", subtitle: info.hostname) {
                if loading { ProgressView().controlSize(.small) }
                IconButton(systemImage: "arrow.clockwise", help: "Atualizar") { Task { await load() } }
            }
            CardRow { Text("IP local") } trailing: { Text(info.ipLocal).foregroundStyle(.secondary).textSelection(.enabled) }
            CardRow { Text("Gateway") } trailing: { Text(info.gateway).foregroundStyle(.secondary).textSelection(.enabled) }
            CardRow { Text("DNS") } trailing: { Text(info.dns.isEmpty ? "—" : info.dns.joined(separator: ", ")).foregroundStyle(.secondary).textSelection(.enabled) }
            CardRow { Text("Hostname") } trailing: { Text(info.hostname).foregroundStyle(.secondary).textSelection(.enabled) }
        }
    }

    // Portas
    private var portsScreen: some View {
        Group {
            ScreenHeader(title: "Portas em uso", subtitle: "\(ports.count) serviços escutando") {
                if loading { ProgressView().controlSize(.small) }
                IconButton(systemImage: "arrow.clockwise", help: "Atualizar") { Task { await load() } }
            }
            VStack(spacing: 8) {
                ForEach(ports) { p in
                    CardRow {
                        HStack(spacing: 10) {
                            Circle().fill(p.isPublic ? Color.orange : Color.green).frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("porta \(p.port)").fontWeight(.medium)
                                Text(p.isPublic ? "exposto na rede (\(p.address))" : "só local (\(p.address))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } trailing: {
                        Text(p.process.isEmpty ? "—" : p.process).font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // Ping e DNS
    private func toolsScreen(_ host: RemoteHost) -> some View {
        Group {
            ScreenHeader(title: "Ping e DNS", subtitle: "Testes a partir do servidor")

            Text("Ping").font(.headline)
            HStack(spacing: 8) {
                TextField("Host (ex.: 1.1.1.1)", text: $pingTarget).textFieldStyle(.roundedBorder)
                Button { Task { await runPing(host) } } label: {
                    if pinging { ProgressView().controlSize(.small) } else { Text("Testar") }
                }.disabled(pinging || !InputValidator.isValidHost(pingTarget))
            }
            if !pingOut.isEmpty { outputBox(pingOut) }

            Text("DNS").font(.headline).padding(.top, 6)
            HStack(spacing: 8) {
                TextField("Nome (ex.: github.com)", text: $dnsTarget).textFieldStyle(.roundedBorder)
                Button { Task { await runDNS(host) } } label: {
                    if resolving { ProgressView().controlSize(.small) } else { Text("Resolver") }
                }.disabled(resolving || !InputValidator.isValidHost(dnsTarget))
            }
            if !dnsOut.isEmpty { outputBox(dnsOut) }
        }
    }

    private func outputBox(_ text: String) -> some View {
        Text(text).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading).padding(10)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
    }

    @MainActor
    private func load() async {
        guard let host else { return }
        loading = true
        switch sub {
        case "ports": ports = await RemoteNetwork.ports(host)
        case "tools": break
        default: info = await RemoteNetwork.info(host)
        }
        loading = false
    }

    @MainActor
    private func runPing(_ host: RemoteHost) async {
        pinging = true; pingOut = "Pingando…"
        pingOut = await RemoteNetwork.ping(host, pingTarget.trimmingCharacters(in: .whitespaces))
        pinging = false
    }
    @MainActor
    private func runDNS(_ host: RemoteHost) async {
        resolving = true; dnsOut = "Resolvendo…"
        dnsOut = await RemoteNetwork.dnsLookup(host, dnsTarget.trimmingCharacters(in: .whitespaces))
        resolving = false
    }
}

// MARK: - Atualizações (apt) — DADOS REAIS

/// Pedido de uma tarefa remota streamada (apt update/upgrade).
private struct TaskRequest: Identifiable {
    let id = UUID()
    let title: String
    let args: [String]
}

struct HLUpdatesView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var hosts: HostStore

    @State private var packages: [AptPackage] = []
    @State private var loading = false
    @State private var pendingTask: TaskRequest?

    private var host: RemoteHost? {
        guard let id = state.activeHost.remoteID else { return nil }
        return hosts.hosts.first { $0.id == id }
    }

    var body: some View {
        Group {
            if let host { content(host) }
            else { ContentUnavailableView("Nenhum host selecionado", systemImage: "server.rack") }
        }
        .task(id: host?.id) { await load() }
        .sheet(item: $pendingTask) { req in
            if let host {
                RemoteTaskSheet(title: req.title, host: host, args: req.args)
                    .onDisappear { Task { await load() } }
            }
        }
    }

    private func content(_ host: RemoteHost) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Atualizações", subtitle: subtitle) {
                    if loading { ProgressView().controlSize(.small) }
                    IconButton(systemImage: "arrow.clockwise", help: "Recarregar lista") { Task { await load() } }
                }

                HStack(spacing: 8) {
                    Button {
                        pendingTask = TaskRequest(title: "Atualizar catálogo (apt update)", args: RemoteApt.updateArgs)
                    } label: { Label("Atualizar catálogo", systemImage: "arrow.down.circle") }
                        .help("Sincroniza a lista de pacotes (apt update)")
                    Button {
                        pendingTask = TaskRequest(title: "Atualizar pacotes (apt upgrade)", args: RemoteApt.upgradeArgs)
                    } label: { Label("Atualizar tudo", systemImage: "arrow.triangle.2.circlepath") }
                        .disabled(packages.isEmpty)
                    Spacer()
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.shield").foregroundStyle(.blue)
                    Text("As atualizações usam sudo sem senha no servidor. Se pedir senha, o Uptend mostra o erro — nada é aplicado às cegas.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }

                if packages.isEmpty && !loading {
                    Label("Tudo atualizado.", systemImage: "checkmark.circle.fill").foregroundStyle(.green).padding(.top, 8)
                } else {
                    VStack(spacing: 8) {
                        ForEach(packages) { p in
                            CardRow {
                                HStack(spacing: 10) {
                                    Image(systemName: "shippingbox").foregroundStyle(.secondary)
                                    Text(p.name).fontWeight(.medium)
                                }
                            } trailing: {
                                HStack(spacing: 6) {
                                    if !p.oldVersion.isEmpty {
                                        Text(p.oldVersion).foregroundStyle(.secondary)
                                        Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Text(p.newVersion).foregroundStyle(.blue)
                                }
                                .font(.callout).lineLimit(1).truncationMode(.middle)
                            }
                        }
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private var subtitle: String {
        loading ? "Verificando…" : (packages.isEmpty ? "Tudo atualizado" : "\(packages.count) pacotes desatualizados (apt)")
    }

    @MainActor
    private func load() async {
        guard let host else { return }
        loading = true
        packages = await RemoteApt.upgradable(host)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        loading = false
    }
}

/// Folha genérica para uma tarefa remota com log ao vivo (apt update/upgrade, etc.).
struct RemoteTaskSheet: View {
    let title: String
    let host: RemoteHost
    let args: [String]
    @Environment(\.dismiss) private var dismiss
    @StateObject private var task = RemoteTask()
    @State private var started = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if task.running { ProgressView().controlSize(.small) }
                else if task.finished { Image(systemName: task.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill").foregroundStyle(task.success ? .green : .orange) }
                Text(title).font(.headline)
                Spacer()
            }
            ScrollViewReader { proxy in
                ScrollView {
                    Text(task.log.isEmpty ? "Iniciando…" : task.log)
                        .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                    Color.clear.frame(height: 1).id("bottom")
                }
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
                .onChange(of: task.log) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
            }
            HStack {
                Spacer()
                Button("Fechar") { dismiss() }.keyboardShortcut(.defaultAction).disabled(task.running)
            }
        }
        .padding(16)
        .frame(width: 660, height: 460)
        .task { if !started { started = true; task.run(host: host, args: args) } }
    }
}

// MARK: - Terminal (REAL — executa comandos no servidor)

struct HLTerminalView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var hosts: HostStore

    @State private var cwd = ""
    @State private var log = ""
    @State private var command = ""
    @State private var running = false

    private var host: RemoteHost? {
        guard let id = state.activeHost.remoteID else { return nil }
        return hosts.hosts.first { $0.id == id }
    }

    var body: some View {
        Group {
            if let host { content(host) }
            else { ContentUnavailableView("Nenhum host selecionado", systemImage: "server.rack") }
        }
        .task(id: host?.id) { if cwd.isEmpty, let host { cwd = "/home/\(host.user)" } }
    }

    private func content(_ host: RemoteHost) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ScreenHeader(title: "Terminal", subtitle: "\(host.user)@\(host.address)") {
                    if running { ProgressView().controlSize(.small) }
                    IconButton(systemImage: "trash", help: "Limpar") { log = "" }
                }

                Text("Comandos rodam no servidor via SSH. Não-interativos: top, vim ou sudo com senha não funcionam aqui.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

                ScrollViewReader { proxy in
                    ScrollView {
                        Text(log.isEmpty ? "Pronto. Digite um comando abaixo." : log)
                            .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                            .foregroundStyle(log.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .frame(height: 380)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
                    .onChange(of: log) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
                }

                HStack(spacing: 8) {
                    Text(cwd).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.head)
                    Text("$").font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                    TextField("comando…", text: $command)
                        .textFieldStyle(.plain).font(.system(.body, design: .monospaced))
                        .onSubmit { run(host) }
                        .disabled(running)
                    Button { run(host) } label: { Image(systemName: "return") }
                        .disabled(running || command.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(10).cardBackground()
            }
            .screenPadding()
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private func run(_ host: RemoteHost) {
        let cmd = command.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty, !running else { return }
        command = ""
        log += "\(cwd) $ \(cmd)\n"
        running = true
        Task {
            let result = await RemoteTerminal.run(host, cwd: cwd, command: cmd)
            if !result.output.isEmpty { log += result.output + "\n" }
            cwd = result.cwd
            running = false
        }
    }
}

// MARK: - Adicionar host (conexão real via SSH)

struct AddHostSheet: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var hosts: HostStore

    @State private var name = ""
    @State private var address = ""
    @State private var user = ""
    @State private var port = "22"
    @State private var keyPath = "~/.ssh/id_ed25519"
    @State private var testing = false
    @State private var testResult: (ok: Bool, message: String)?
    @State private var jumpHost = ""
    @State private var advanced = false
    // Credencial de banco (opcional)
    @State private var dbEnabled = false
    @State private var dbKind = "postgres"
    @State private var dbUser = ""
    @State private var dbPassword = ""
    @State private var dbHost = "localhost"
    @State private var dbPort = "5432"
    @State private var dbName = ""

    private var kind: HostKind { state.addHostKind }

    private func dbCredential() -> DBCredential? {
        guard dbEnabled, !dbUser.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return DBCredential(kind: dbKind, user: dbUser.trimmingCharacters(in: .whitespaces),
                            host: dbHost.trimmingCharacters(in: .whitespaces).isEmpty ? "localhost" : dbHost.trimmingCharacters(in: .whitespaces),
                            port: Int(dbPort) ?? 5432,
                            database: dbName.trimmingCharacters(in: .whitespaces))
    }

    /// Monta um host com os campos atuais (novo id a cada chamada — usar 1x no salvar).
    private func makeHost() -> RemoteHost {
        RemoteHost(name: name.trimmingCharacters(in: .whitespaces), kind: kind,
                   address: address.trimmingCharacters(in: .whitespaces),
                   user: user.trimmingCharacters(in: .whitespaces),
                   port: Int(port) ?? 0,
                   keyPath: keyPath.trimmingCharacters(in: .whitespaces),
                   db: dbCredential(),
                   jumpHost: jumpHost.trimmingCharacters(in: .whitespaces))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                content.padding(20)
            }
            Divider()
            // Botões de ação FIXOS no rodapé — nunca são empurrados para fora, mesmo
            // com os grupos expandidos e uma mensagem de erro de teste longa (M6).
            HStack {
                Button { Task { await test() } } label: {
                    HStack(spacing: 6) {
                        if testing { ProgressView().controlSize(.small) }
                        Text("Testar conexão")
                    }
                }
                .disabled(testing || !makeHost().isValid)
                Spacer()
                Button("Cancelar") { state.showAddHost = false }.keyboardShortcut(.cancelAction)
                Button("Adicionar") { save() }.keyboardShortcut(.defaultAction).disabled(!makeHost().isValid)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .frame(width: 490, height: 560)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adicionar \(kind.label)").font(.title3).fontWeight(.medium)

            field("Nome", "Ex.: \(kind.label) de casa", text: $name)
            field("Endereço (IP ou hostname)", "Ex.: 192.168.1.50", text: $address)
            HStack(spacing: 10) {
                field("Usuário", "Ex.: andre", text: $user)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Porta").font(.caption).foregroundStyle(.secondary)
                    TextField("22", text: $port).textFieldStyle(.roundedBorder).frame(width: 70)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Chave SSH (privada)").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("~/.ssh/id_ed25519", text: $keyPath).textFieldStyle(.roundedBorder)
                    Button("Escolher…") { pickKey() }
                }
                Text("Acesso SSH só por chave — o Uptend nunca guarda senha de SSH.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            DisclosureGroup(isExpanded: $dbEnabled) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Para auditar o banco (só estrutura, LGPD-safe). Se o banco aceita acesso local sem senha (peer/socket), pode deixar usuário/senha em branco.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Picker("Motor", selection: $dbKind) {
                        Text("PostgreSQL").tag("postgres")
                        Text("MySQL / MariaDB").tag("mysql")
                    }.pickerStyle(.segmented)
                        .onChange(of: dbKind) { _, k in if dbPort == "5432" || dbPort == "3306" { dbPort = k == "mysql" ? "3306" : "5432" } }
                    HStack(spacing: 10) {
                        field("Usuário do banco", "ex.: readonly", text: $dbUser)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Senha").font(.caption).foregroundStyle(.secondary)
                            SecureField("senha", text: $dbPassword).textFieldStyle(.roundedBorder)
                        }
                    }
                    HStack(spacing: 10) {
                        field("Host do banco", "localhost", text: $dbHost)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Porta").font(.caption).foregroundStyle(.secondary)
                            TextField("5432", text: $dbPort).textFieldStyle(.roundedBorder).frame(width: 70)
                        }
                        field("Banco (opcional)", "todos", text: $dbName)
                    }
                    Text("A senha vai para o Keychain do macOS. Recomendado: um usuário read-only.")
                        .font(.caption2).foregroundStyle(.green)
                }
                .padding(.top, 6)
            } label: {
                Label("Banco de dados (opcional)", systemImage: "cylinder.split.1x2").font(.callout)
            }

            DisclosureGroup(isExpanded: $advanced) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Servidor de salto (bastion / ProxyJump)").font(.caption).foregroundStyle(.secondary)
                    TextField("ex.: usuario@bastion.empresa.com:22", text: $jumpHost).textFieldStyle(.roundedBorder)
                    Text("Para servidor em rede privada: o Uptend conecta primeiro no bastion e salta para o destino. Deixe vazio se o servidor é acessível direto.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }.padding(.top, 6)
            } label: {
                Label("Conexão avançada (bastion)", systemImage: "arrow.triangle.branch").font(.callout)
            }

            if let r = testResult {
                Label(r.message, systemImage: r.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(r.ok ? .green : .orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @MainActor
    private func test() async {
        testing = true
        testResult = nil
        let r = await SSHRunner.test(makeHost())
        testResult = (r.ok, r.ok ? "Conectado: \(r.message)" : r.message)
        testing = false
    }

    private func save() {
        let host = makeHost()
        guard hosts.add(host) else { return }
        // Senha do banco (se houver) vai para o Keychain — nunca em UserDefaults.
        if host.db != nil, !dbPassword.isEmpty { DBCredentialStore.setPassword(dbPassword, for: host) }
        state.activeHost = .remote(kind, host.id)
        state.showAddHost = false
    }

    private func pickKey() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.showsHiddenFiles = true
        panel.directoryURL = URL(fileURLWithPath: (("~/.ssh" as NSString).expandingTildeInPath))
        panel.prompt = "Usar esta chave"
        if panel.runModal() == .OK, let url = panel.url {
            keyPath = url.path
        }
    }

    private func field(_ label: String, _ prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(prompt, text: text).textFieldStyle(.roundedBorder)
        }
    }
}
