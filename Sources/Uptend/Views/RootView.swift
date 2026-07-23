import SwiftUI

/// Layout de três colunas: categorias | subseções | conteúdo.
struct RootView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var brew: BrewService

    private var showingTask: Binding<Bool> {
        Binding(get: { brew.runningTitle != nil }, set: { if !$0 { brew.dismissRunning() } })
    }

    var body: some View {
        VStack(spacing: 0) {
        HostTabBar()
        NavigationSplitView {
            Group {
                if state.activeHost.isAuditoria { AuditoriaSidebar() }
                else if state.activeHost.isRemote { HomeLabSidebar() }
                else { SidebarView() }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } content: {
            Group {
                if state.activeHost.isAuditoria { AuditoriaContentColumn() }
                else if state.activeHost.isRemote { HomeLabContentColumn() }
                else { ContentColumn() }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            if state.activeHost.isAuditoria { AuditoriaDetailColumn() }
            else if state.activeHost.isRemote { HomeLabDetailColumn() }
            else { DetailColumn() }
        }
        .navigationSplitViewStyle(.balanced)
        .tooltipHost()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    state.activeHost = .thisMac
                    state.category = .dashboard
                    state.subID = "overview"
                } label: {
                    Image(systemName: "house")
                        .foregroundStyle(state.activeHost == .thisMac && state.category == .dashboard ? Color.accentColor : Color.primary)
                }
                .help("Início")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    state.activeHost = .thisMac
                    state.category = .settings
                    state.subID = "general"
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(state.activeHost == .thisMac && state.category == .settings ? Color.accentColor : Color.primary)
                }
                .help("Configurações")
            }
            ToolbarItem(placement: .primaryAction) {
                NotificationBell()
            }
        }
        .sheet(isPresented: showingTask) {
            RunningTaskView()
        }
        .sheet(isPresented: $state.showAddHost) {
            AddHostSheet()
        }
        .overlay {
            if state.showNotifications { NotificationPanel() }
        }
        .overlay(alignment: .bottom) { ToastView() }
        }
    }
}

// MARK: - Coluna 1: categorias

struct SidebarView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var brew: BrewService
    @EnvironmentObject var clamav: ClamAVService

    private var selection: Binding<Category?> {
        Binding(get: { state.category }, set: { if let v = $0 { state.category = v } })
    }

    /// Uma categoria está "ativa" quando tem um processo em andamento nela.
    private func isActive(_ category: Category) -> Bool {
        switch category {
        case .security: return clamav.running
        case .homebrew: return brew.runningBusy
        default: return false
        }
    }

    var body: some View {
        List(selection: selection) {
            Section("Uptend") {
                ForEach(Category.primary.alphabetical) { category in
                    HStack {
                        Label(category.title, systemImage: category.systemImage)
                        Spacer(minLength: 6)
                        if isActive(category) { ActivityDot() }
                    }
                    .tip(category.help)
                    .tag(category)
                }
            }
        }
        .listStyle(.sidebar)
    }
}

/// Bolinha pulsante indicando que há um processo rodando naquela seção.
struct ActivityDot: View {
    @State private var pulse = false
    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 8, height: 8)
            .opacity(pulse ? 0.3 : 1)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
            .help("Processo em andamento")
    }
}

// MARK: - Coluna 2: subseções

struct ContentColumn: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        List(selection: $state.subID) {
            Section(state.category.title) {
                ForEach(state.category.subsections.alphabetical) { sub in
                    HStack {
                        Label(sub.title, systemImage: sub.systemImage)
                        Spacer()
                        if let badge = sub.badge {
                            Text(badge)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(sub.id)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(state.category.title)
    }
}

// MARK: - Coluna 3: conteúdo

struct DetailColumn: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let sub = state.currentSubsection
        Group {
            switch state.category {
            case .dashboard:
                switch sub?.id {
                case "ambiente": EnvironmentSetupView()
                case "firstrun", "profiles", "compare", "dotfiles": SetupView(sub: sub)
                default: DashboardView(sub: sub)
                }
            case .homebrew: HomebrewView(sub: sub)
            case .applications: ApplicationsView(sub: sub)
            case .cleanup: CleanupView(sub: sub)
            case .git: GitView(sub: sub)
            case .docker: DockerView(sub: sub)
            case .services: ServicesView(sub: sub)
            case .energy: EnergyView(sub: sub)
            case .xcode: XcodeView(sub: sub)
            case .storage: StorageView(sub: sub)
            case .network: NetworkView(sub: sub)
            case .security: SecurityView(sub: sub)
            case .report: ReportPanel(asSheet: false).padding(20)
            case .tools: ToolsView(sub: sub)
            case .settings:
                switch sub?.id {
                case "info", "health", "toggles", "login", "focus": SystemView(sub: sub)
                case "dados": AppDataView()
                default: SettingsView(sub: sub)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
