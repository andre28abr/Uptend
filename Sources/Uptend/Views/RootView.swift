import SwiftUI

/// Layout de três colunas: categorias | subseções | conteúdo.
struct RootView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var brew: BrewService

    private var showingTask: Binding<Bool> {
        Binding(get: { brew.runningTitle != nil }, set: { if !$0 { brew.dismissRunning() } })
    }

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } content: {
            ContentColumn()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            DetailColumn()
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: showingTask) {
            RunningTaskView()
        }
        .overlay(alignment: .bottom) { ToastView() }
    }
}

// MARK: - Coluna 1: categorias

struct SidebarView: View {
    @EnvironmentObject var state: AppState

    private var selection: Binding<Category?> {
        Binding(get: { state.category }, set: { if let v = $0 { state.category = v } })
    }

    var body: some View {
        List(selection: selection) {
            Section("Uptend") {
                ForEach(Category.primary) { category in
                    Label(category.title, systemImage: category.systemImage)
                        .help(category.help)
                        .tag(category)
                }
            }

            Section {
                Label(Category.settings.title, systemImage: Category.settings.systemImage)
                    .help(Category.settings.help)
                    .tag(Category.settings)
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Coluna 2: subseções

struct ContentColumn: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        List(selection: $state.subID) {
            Section(state.category.title) {
                ForEach(state.category.subsections) { sub in
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
            case .dashboard: DashboardView(sub: sub)
            case .setup: SetupView(sub: sub)
            case .homebrew: HomebrewView(sub: sub)
            case .applications: ApplicationsView(sub: sub)
            case .cleanup: CleanupView(sub: sub)
            case .git: GitView(sub: sub)
            case .docker: DockerView(sub: sub)
            case .network: NetworkView(sub: sub)
            case .security: SecurityView(sub: sub)
            case .system: SystemView(sub: sub)
            case .tools: ToolsView(sub: sub)
            case .settings: SettingsView(sub: sub)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
