import SwiftUI
import AppKit

/// Central do Homebrew: roteia entre as subseções.
struct HomebrewView: View {
    let sub: SubSection?
    @EnvironmentObject var brew: BrewService

    var body: some View {
        if !brew.detected {
            BrewMissingView()
        } else {
            switch sub?.id {
            case "search": BrewSearchView()
            case "installed": BrewInstalledView()
            case "outdated": BrewOutdatedView()
            case "maintenance": BrewMaintenanceView()
            default: BrewEssentialsView()
            }
        }
    }
}

// MARK: - Buscar e instalar

struct BrewSearchView: View {
    @EnvironmentObject var brew: BrewService
    @State private var query = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Buscar e instalar", subtitle: "Procure qualquer fórmula ou cask do Homebrew")

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Ex.: ffmpeg, vlc, wget…", text: $query)
                        .textFieldStyle(.plain)
                        .onSubmit { Task { await brew.search(query) } }
                    if brew.searching { ProgressView().controlSize(.small) }
                }
                .padding(10)
                .cardBackground()

                if brew.searchResults.isEmpty {
                    Text(brew.searching ? "Buscando…" : "Digite um termo e pressione Enter.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                } else {
                    VStack(spacing: 8) {
                        ForEach(brew.searchResults) { result in
                            CardRow {
                                HStack(spacing: 12) {
                                    Image(systemName: result.isCask ? "macwindow" : "terminal")
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.name).fontWeight(.medium)
                                        Text(result.isCask ? "cask (app)" : "fórmula")
                                            .font(.callout).foregroundStyle(.secondary)
                                    }
                                }
                            } trailing: {
                                if brew.isInstalledToken(result.name, isCask: result.isCask) {
                                    Label("Instalado", systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(.green).labelStyle(.iconOnly)
                                        .help("Já instalado").frame(width: 24, height: 24)
                                } else {
                                    IconButton(systemImage: "arrow.down.circle", help: "Instalar \(result.name)") {
                                        Task { await brew.installToken(result.name, isCask: result.isCask) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
    }
}

// MARK: - Essenciais (catálogo curado)

struct BrewEssentialsView: View {
    @EnvironmentObject var brew: BrewService
    @State private var group = "dev"

    private let groups: [(id: String, title: String)] = [
        ("dev", "Desenvolvimento"), ("sec", "Segurança"), ("design", "Design"),
        ("prod", "Produtividade"), ("util", "Utilidades"),
    ]

    private var items: [AppItem] { MockData.apps[group] ?? [] }
    private var pending: [AppItem] { items.filter { !brew.isInstalled($0) && !$0.token.isEmpty } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(
                    title: "Essenciais",
                    subtitle: "\(items.filter { brew.isInstalled($0) }.count) de \(items.count) instalados"
                ) {
                    if brew.loading { ProgressView().controlSize(.small) }
                    Button {
                        Task { await brew.installMany(pending) }
                    } label: {
                        Label("Instalar tudo", systemImage: "arrow.down.circle")
                    }
                    .disabled(pending.isEmpty)
                }

                Picker("Categoria", selection: $group) {
                    ForEach(groups, id: \.id) { Text($0.title).tag($0.id) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                VStack(spacing: 8) {
                    ForEach(items) { app in
                        AppCatalogRow(app: app)
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
    }
}

struct AppCatalogRow: View {
    let app: AppItem
    @EnvironmentObject var brew: BrewService

    var body: some View {
        CardRow {
            HStack(spacing: 12) {
                Monogram(text: app.name)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).fontWeight(.medium)
                    Text(app.tagline).font(.callout).foregroundStyle(.secondary)
                }
            }
        } trailing: {
            if brew.isInstalled(app) {
                Label("Instalado", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green).labelStyle(.iconOnly)
                    .help("Instalado").frame(width: 24, height: 24)
                if !app.token.isEmpty {
                    IconButton(systemImage: "trash", help: "Desinstalar \(app.name)") {
                        Task { await brew.uninstall(app) }
                    }
                }
            } else {
                IconButton(systemImage: "arrow.down.circle", help: "Instalar \(app.name)") {
                    Task { await brew.install(app) }
                }
            }
        }
    }
}

// MARK: - Instalados

struct BrewInstalledView: View {
    @EnvironmentObject var brew: BrewService
    @State private var filter = ""

    private var formulae: [String] { brew.installedFormulaeSorted.filter { match($0) } }
    private var casks: [String] { brew.installedCasksSorted.filter { match($0) } }

    private func match(_ name: String) -> Bool {
        filter.isEmpty || name.localizedCaseInsensitiveContains(filter)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(
                    title: "Instalados",
                    subtitle: "\(brew.installedCount) pacotes no total"
                ) {
                    if brew.loading { ProgressView().controlSize(.small) }
                    IconButton(systemImage: "arrow.clockwise", help: "Atualizar lista") {
                        Task { await brew.refreshInstalled() }
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Filtrar…", text: $filter).textFieldStyle(.plain)
                }
                .padding(10)
                .cardBackground()

                if !casks.isEmpty {
                    section("Apps (casks)", items: casks, isCask: true)
                }
                if !formulae.isEmpty {
                    section("Fórmulas", items: formulae, isCask: false)
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
    }

    private func section(_ title: String, items: [String], isCask: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) · \(items.count)").font(.headline).padding(.top, 4)
            ForEach(items, id: \.self) { name in
                CardRow {
                    HStack(spacing: 12) {
                        Image(systemName: isCask ? "macwindow" : "terminal").foregroundStyle(.secondary)
                        Text(name).fontWeight(.medium)
                    }
                } trailing: {
                    IconButton(systemImage: "trash", help: "Desinstalar \(name)") {
                        Task { await brew.uninstallToken(name, isCask: isCask) }
                    }
                }
            }
        }
    }
}

// MARK: - Atualizações

struct BrewOutdatedView: View {
    @EnvironmentObject var brew: BrewService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(
                    title: "Atualizações",
                    subtitle: brew.loading ? "Verificando…" : (brew.outdated.isEmpty ? "Tudo atualizado" : "\(brew.outdated.count) disponíveis")
                ) {
                    IconButton(systemImage: "arrow.clockwise", help: "Verificar atualizações") {
                        Task { await brew.refreshOutdated() }
                    }
                    Button {
                        Task { await brew.updateAndUpgradeAll() }
                    } label: {
                        Label("Atualizar tudo", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(brew.outdated.isEmpty)
                }

                if brew.loading {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Verificando…").foregroundStyle(.secondary)
                    }
                    .padding(.top, 40).frame(maxWidth: .infinity)
                } else if brew.outdated.isEmpty {
                    ContentUnavailableView("Tudo atualizado", systemImage: "checkmark.circle",
                                           description: Text("Nenhuma atualização pendente."))
                    .padding(.top, 40)
                } else {
                    VStack(spacing: 8) {
                        ForEach(brew.outdated) { pkg in
                            CardRow {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(pkg.name).fontWeight(.medium)
                                        if pkg.isCask {
                                            Text("cask").font(.caption)
                                                .padding(.horizontal, 6).padding(.vertical, 1)
                                                .background(.quaternary, in: Capsule())
                                        }
                                    }
                                    HStack(spacing: 6) {
                                        Text(pkg.installed).foregroundStyle(.secondary)
                                        Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                                        Text(pkg.latest).foregroundStyle(.blue)
                                    }
                                    .font(.callout)
                                }
                            } trailing: {
                                IconButton(systemImage: "arrow.up.circle", help: "Atualizar \(pkg.name)") {
                                    Task { await brew.upgrade(pkg) }
                                }
                            }
                        }
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
    }
}

// MARK: - Manutenção

struct BrewMaintenanceView: View {
    @EnvironmentObject var brew: BrewService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Manutenção", subtitle: "Comandos de manutenção do Homebrew")

                VStack(spacing: 8) {
                    action("Atualizar catálogo", detail: "Sincroniza a lista de pacotes (brew update)",
                           systemImage: "arrow.clockwise") { Task { await brew.brewUpdate() } }
                    action("Limpar versões antigas", detail: "Remove downloads e versões velhas (brew cleanup)",
                           systemImage: "sparkles") { Task { await brew.brewCleanup() } }
                    action("Diagnóstico", detail: "Procura problemas na instalação (brew doctor)",
                           systemImage: "stethoscope") { Task { await brew.brewDoctor() } }
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
    }

    private func action(_ title: String, detail: String, systemImage: String, run: @escaping () -> Void) -> some View {
        CardRow {
            HStack(spacing: 12) {
                Image(systemName: systemImage).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).fontWeight(.medium)
                    Text(detail).font(.callout).foregroundStyle(.secondary)
                }
            }
        } trailing: {
            IconButton(systemImage: "play.fill", help: title, action: run)
        }
    }
}

// MARK: - Homebrew ausente

struct BrewMissingView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Homebrew não encontrado", systemImage: "mug")
        } description: {
            Text("O Uptend usa o Homebrew para instalar e atualizar apps. Instale o Homebrew para continuar.")
        } actions: {
            Button("Abrir brew.sh") {
                if let url = URL(string: "https://brew.sh") { NSWorkspace.shared.open(url) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
