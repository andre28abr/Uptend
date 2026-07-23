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
            case "mypackages": MyPackagesView()
            case "taps": TapManagerView()
            case "installed": BrewInstalledView()
            case "outdated": BrewOutdatedView()
            case "tidy": BrewTidyView()
            case "maintenance": BrewMaintenanceView()
            default: BrewEssentialsView()
            }
        }
    }
}

// MARK: - Buscar e instalar

struct BrewSearchView: View {
    @EnvironmentObject var brew: BrewService
    @EnvironmentObject var providers: TapProvidersStore
    @EnvironmentObject var github: GitHubService
    @State private var query = ""
    @State private var searched = ""
    @State private var infoTarget: SearchResult?

    /// Programas das contas adicionadas que casam com a busca (offline, do cache).
    private var providerMatches: [SearchResult] {
        let q = searched.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return providers.allPrograms
            .filter { $0.name.localizedCaseInsensitiveContains(q) }
            .map { SearchResult(name: $0.name, isCask: $0.isCask, tap: $0.tap) }
    }

    /// Resultados combinados: suas fontes primeiro (mais relevantes), depois o catálogo oficial.
    private var results: [SearchResult] { providerMatches + brew.searchResults }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Buscar e instalar", subtitle: "Procure no catálogo oficial e nas suas fontes")

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Ex.: ffmpeg, vlc, wget…", text: $query)
                        .textFieldStyle(.plain)
                        .onSubmit { run() }
                    if brew.searching { ProgressView().controlSize(.small) }
                }
                .padding(10)
                .cardBackground()

                if results.isEmpty {
                    Text(brew.searching ? "Buscando…" : "Digite um termo e pressione Enter.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                } else {
                    VStack(spacing: 8) {
                        ForEach(results) { result in resultRow(result) }
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
        .sheet(item: $infoTarget) { result in
            BrewInfoSheet(result: result)
        }
    }

    private func resultRow(_ result: SearchResult) -> some View {
        CardRow {
            HStack(spacing: 12) {
                Image(systemName: result.isCask ? "macwindow" : "terminal")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.name).fontWeight(.medium)
                    HStack(spacing: 6) {
                        Text(result.isCask ? "cask (app)" : "fórmula")
                            .font(.callout).foregroundStyle(.secondary)
                        SourceTag(result: result, myLogin: github.account?.login)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { if result.tap == nil { infoTarget = result } }
            }
        } trailing: {
            if let tap = result.tap {
                FavoriteButton(name: result.name, tap: tap, isCask: result.isCask)
            } else {
                IconButton(systemImage: "info.circle", help: "O que é \(result.name)?") { infoTarget = result }
            }
            if brew.isInstalledToken(result.name, isCask: result.isCask) {
                Label("Instalado", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green).labelStyle(.iconOnly)
                    .help("Já instalado").frame(width: 24, height: 24)
            } else {
                IconButton(systemImage: "arrow.down.circle", help: "Instalar \(result.name)") {
                    if let tap = result.tap {
                        Task { await brew.installFromTap(tap: tap, formula: result.name) }
                    } else {
                        Task { await brew.installToken(result.name, isCask: result.isCask) }
                    }
                }
            }
        }
    }

    private func run() {
        searched = query.trimmingCharacters(in: .whitespaces)
        Task { await brew.search(query) }
    }
}

/// Etiqueta de procedência de um resultado de busca: core, sua conta, ou de outra conta.
struct SourceTag: View {
    let result: SearchResult
    let myLogin: String?

    private var label: String {
        guard let owner = result.owner else { return "core" }
        return "@\(owner)"
    }
    private var color: Color {
        guard let owner = result.owner else { return .secondary }
        if let myLogin, owner.lowercased() == myLogin.lowercased() { return .green }
        return .orange
    }

    var body: some View {
        Text(label)
            .font(.caption2).fontWeight(.medium)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
            .help(result.tap == nil ? "Catálogo oficial do Homebrew" : "Fonte de terceiros: \(result.tap ?? "")")
    }
}

// MARK: - Detalhes do pacote (o que é)

/// Painel "o que é este pacote" — busca `brew info` e mostra descrição, site,
/// versão, licença e dependências. Permite instalar direto daqui.
struct BrewInfoSheet: View {
    let result: SearchResult
    @EnvironmentObject var brew: BrewService
    @Environment(\.dismiss) private var dismiss

    @State private var info: BrewInfo?
    @State private var loading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: result.isCask ? "macwindow" : "terminal").foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 1) {
                    Text(info?.name ?? result.name).font(.title3).fontWeight(.medium)
                    Text(result.isCask ? "cask (aplicativo)" : "fórmula (linha de comando)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Fechar") { dismiss() }.keyboardShortcut(.cancelAction)
            }

            if loading {
                HStack { ProgressView().controlSize(.small); Text("Carregando informações…").foregroundStyle(.secondary) }
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let info {
                Text(info.description).fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    detail("Versão", info.version)
                    if let license = info.license, !license.isEmpty { detail("Licença", license) }
                    if !info.dependencies.isEmpty {
                        detail("Dependências", info.dependencies.prefix(12).joined(separator: ", ")
                               + (info.dependencies.count > 12 ? "…" : ""))
                    }
                    if !info.homepage.isEmpty {
                        HStack(spacing: 6) {
                            Text("Site").font(.caption).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
                            Button(info.homepage) {
                                if let url = URL(string: info.homepage) { NSWorkspace.shared.open(url) }
                            }.buttonStyle(.link).lineLimit(1).truncationMode(.middle)
                        }
                    }
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()

                if let caveats = info.caveats, !caveats.isEmpty {
                    Text("Observações").font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    Text(caveats).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10).cardBackground()
                }
            } else {
                Text("Não foi possível carregar as informações deste pacote.")
                    .foregroundStyle(.secondary)
            }

            Spacer()
            HStack {
                Spacer()
                if brew.isInstalledToken(result.name, isCask: result.isCask) {
                    Label("Já instalado", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    Button {
                        Task { await brew.installToken(result.name, isCask: result.isCask); dismiss() }
                    } label: { Label("Instalar", systemImage: "arrow.down.circle") }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 480, height: 420)
        .task {
            info = await brew.info(token: result.name, isCask: result.isCask)
            loading = false
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
            Text(value).font(.callout).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
        }
    }
}

// MARK: - Faxina (dependências órfãs)

struct BrewTidyView: View {
    @EnvironmentObject var brew: BrewService
    @State private var orphans: [String] = []
    @State private var leaves: [String] = []
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Faxina", subtitle: "Remova dependências que ficaram sobrando") {
                    if loading || brew.runningBusy { ProgressView().controlSize(.small) }
                    IconButton(systemImage: "arrow.clockwise", help: "Recalcular") { Task { await load() } }
                }

                if !brew.detected {
                    ContentUnavailableView("Homebrew não detectado", systemImage: "mug").padding(.top, 40)
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle").foregroundStyle(.blue)
                        Text("Ao instalar programas, o Homebrew traz outras peças de que eles dependem. Quando o programa principal sai, essas peças podem ficar sobrando. Aqui você remove esse entulho com segurança.")
                            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()

                    CardRow {
                        HStack(spacing: 10) {
                            Image(systemName: "shippingbox").foregroundStyle(.secondary)
                            Text("\(brew.installedFormulae.count) fórmulas instaladas · \(leaves.count) principais · \(orphans.count) órfãs")
                                .font(.callout)
                        }
                    } trailing: { EmptyView() }

                    if !orphans.isEmpty {
                        HStack {
                            Text("Dependências órfãs (\(orphans.count))").font(.headline)
                            Spacer()
                            Button(role: .destructive) {
                                Task { await brew.runAutoremove(); await load() }
                            } label: {
                                Label("Remover órfãs", systemImage: "trash")
                            }
                            .disabled(brew.runningBusy)
                        }
                        VStack(spacing: 6) {
                            ForEach(orphans, id: \.self) { name in
                                CardRow {
                                    HStack(spacing: 10) {
                                        Image(systemName: "cube").foregroundStyle(.orange)
                                        Text(name).fontWeight(.medium)
                                    }
                                } trailing: { EmptyView() }
                            }
                        }
                        Text("Roda o `brew autoremove` — remove só dependências que nenhum programa instalado usa. Seguro.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else if !loading {
                        Label("Nada para limpar — sem dependências órfãs.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
        .task { await load() }
    }

    private func load() async {
        loading = true
        orphans = await brew.autoremovePreview()
        leaves = await brew.leaves()
        loading = false
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
                .tip("Filtra os apps essenciais por área (desenvolvimento, segurança, design…).")

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
