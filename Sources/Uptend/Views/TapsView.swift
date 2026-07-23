import SwiftUI

// MARK: - Botão de favoritar (estrela reutilizável, aparece em todo lugar)

/// Estrela para favoritar um programa de fonte de terceiros. Cheia = favoritado.
/// Favoritar joga o programa para o topo de "Meus programas".
struct FavoriteButton: View {
    @EnvironmentObject var store: MyPackagesStore
    let name: String
    let tap: String
    let isCask: Bool

    var body: some View {
        let saved = store.packages.contains { $0.id == "\(tap)/\(name)" }
        IconButton(systemImage: saved ? "star.fill" : "star",
                   help: saved ? "Remover dos favoritos" : "Favoritar (vai para o topo de Meus programas)") {
            let pkg = MyPackage(name: name, tap: tap, formula: name, isCask: isCask)
            if saved { store.remove(pkg) } else { store.add(pkg) }
        }
    }
}

/// Etiqueta do tipo do programa: "app" (cask, com janela) ou "CLI" (fórmula, terminal).
/// Serve para diferenciar quando um mesmo nome existe como fórmula E cask.
struct KindTag: View {
    let isCask: Bool
    var body: some View {
        Text(isCask ? "app" : "CLI")
            .font(.caption2).fontWeight(.medium)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(.quaternary, in: Capsule())
            .foregroundStyle(.secondary)
            .help(isCask ? "Aplicativo com janela (vai para /Applications)"
                         : "Ferramenta de linha de comando (roda no Terminal)")
    }
}

/// Etiqueta de procedência: sempre o usuário do GitHub (@login). Verde quando é a
/// sua conta conectada, laranja quando é de outra pessoa.
struct TapOriginBadge: View {
    let owner: String
    var myLogin: String?

    private var isMine: Bool { myLogin?.lowercased() == owner.lowercased() }

    var body: some View {
        Text("@\(owner)")
            .font(.caption2).fontWeight(.medium)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background((isMine ? Color.green : Color.orange).opacity(0.15), in: Capsule())
            .foregroundStyle(isMine ? Color.green : Color.orange)
            .help("Instalado via Homebrew, da fonte @\(owner)" + (isMine ? " (sua conta)" : ""))
    }
}

// MARK: - Meus programas (instalados das suas fontes + favoritos)

/// Um programa de fonte de terceiros conhecido (descoberto numa conta ou favoritado).
private struct ManagedProgram: Identifiable {
    let name: String
    let tap: String
    let isCask: Bool
    var id: String { "\(tap)/\(name)" }
    var owner: String { String(tap.split(separator: "/").first ?? "") }
}

/// Seus programas de fontes de terceiros: os que estão instalados ou favoritados.
/// Favoritos ficam no topo (estrela cheia). Instalar algo de uma fonte faz o
/// programa aparecer aqui automaticamente.
struct MyPackagesView: View {
    @EnvironmentObject var brew: BrewService
    @EnvironmentObject var store: MyPackagesStore
    @EnvironmentObject var providers: TapProvidersStore

    private func isFavorite(_ m: ManagedProgram) -> Bool {
        store.packages.contains { $0.id == m.id }
    }
    private func isInstalled(_ m: ManagedProgram) -> Bool {
        brew.isInstalledToken(m.name, isCask: m.isCask)
    }

    /// Todos os programas conhecidos (das contas adicionadas + favoritos), sem repetir.
    private var known: [ManagedProgram] {
        var map: [String: ManagedProgram] = [:]
        for p in providers.allPrograms {
            map[p.id] = ManagedProgram(name: p.name, tap: p.tap, isCask: p.isCask)
        }
        for f in store.packages {           // favoritos podem não estar em nenhuma conta adicionada
            let m = ManagedProgram(name: f.formula, tap: f.tap, isCask: f.isCask)
            map[m.id] = m
        }
        return Array(map.values)
    }

    /// O que mostrar: instalados ou favoritados. Favoritos primeiro, depois alfabético.
    private var items: [ManagedProgram] {
        known.filter { isFavorite($0) || isInstalled($0) }
            .sorted { a, b in
                let fa = isFavorite(a), fb = isFavorite(b)
                if fa != fb { return fa }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Meus programas", subtitle: subtitle) {
                    if brew.loading || brew.runningBusy { ProgressView().controlSize(.small) }
                    IconButton(systemImage: "arrow.clockwise", help: "Atualizar") { Task { await brew.refreshInstalled() } }
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle").foregroundStyle(.blue)
                    Text("Os programas de fontes de terceiros que você tem instalados ou favoritou. Favoritos (estrela) ficam no topo. Para descobrir e instalar mais, use \"Fontes (contas)\" ou a busca geral.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()

                if items.isEmpty {
                    ContentUnavailableView {
                        Label("Nada por aqui ainda", systemImage: "shippingbox")
                    } description: {
                        Text("Vá em \"Fontes (contas)\", adicione um usuário do GitHub e instale (ou favorite com a estrela) os programas que quiser.")
                    }
                    .padding(.top, 20)
                } else {
                    VStack(spacing: 8) {
                        ForEach(items) { row($0) }
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
    }

    private var subtitle: String {
        let installed = items.filter { isInstalled($0) }.count
        let favs = items.filter { isFavorite($0) }.count
        return "\(installed) instalado(s) · \(favs) favorito(s)"
    }

    private func row(_ m: ManagedProgram) -> some View {
        CardRow {
            HStack(spacing: 12) {
                Monogram(text: m.name)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(m.name).fontWeight(.medium)
                        KindTag(isCask: m.isCask)
                        if isInstalled(m) {
                            Text("instalado").font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(.green.opacity(0.15), in: Capsule()).foregroundStyle(.green)
                        }
                    }
                    Text(m.tap).font(.callout).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
        } trailing: {
            FavoriteButton(name: m.name, tap: m.tap, isCask: m.isCask)
            if isInstalled(m) {
                IconButton(systemImage: "trash", help: "Desinstalar \(m.name)") {
                    Task { await brew.uninstallToken(m.name, isCask: m.isCask) }
                }
            } else {
                Button {
                    Task { await brew.installFromTap(tap: m.tap, formula: m.name) }
                } label: { Label("Instalar", systemImage: "arrow.down.circle") }
                .disabled(brew.runningBusy)
            }
        }
    }
}

// MARK: - Fontes por conta do GitHub

/// Adiciona uma CONTA do GitHub como fonte: o Uptend varre os repositórios
/// `homebrew-*` do usuário, mostra quantos programas há e instala com 1 clique.
struct TapManagerView: View {
    @EnvironmentObject var brew: BrewService
    @EnvironmentObject var providers: TapProvidersStore
    @EnvironmentObject var github: GitHubService

    @State private var user = ""
    @State private var expanded: String?
    @State private var query = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Fontes (contas)", subtitle: "\(providers.providers.count) conta(s) adicionada(s)") {
                    if github.discovering || brew.runningBusy { ProgressView().controlSize(.small) }
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle").foregroundStyle(.blue)
                    Text("Digite um usuário do GitHub. O Uptend acha sozinho os repositórios de programas dele (os \"homebrew-...\"), mostra quantos há e instala com 1 clique. Esses programas também passam a aparecer na busca geral do Homebrew, marcados com a origem.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()

                HStack(spacing: 8) {
                    Image(systemName: "at").foregroundStyle(.secondary)
                    TextField("Usuário do GitHub — ex.: andre28abr", text: $user)
                        .textFieldStyle(.plain)
                        .onSubmit { discover() }
                    if github.discovering { ProgressView().controlSize(.small) }
                    Button("Adicionar") { discover() }
                        .disabled(github.discovering || !InputValidator.isValidGitHubUser(user.trimmingCharacters(in: .whitespaces)))
                }
                .padding(10)
                .cardBackground()

                if let error = github.lastError { ErrorBanner(error) { github.lastError = nil } }

                if providers.providers.isEmpty && !github.discovering {
                    ContentUnavailableView {
                        Label("Nenhuma conta adicionada", systemImage: "person.crop.circle.badge.plus")
                    } description: {
                        Text("Adicione um usuário do GitHub acima para ver os programas que ele oferece.")
                    }
                    .padding(.top, 20)
                } else {
                    ForEach(providers.providers) { provider in providerCard(provider) }
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
    }

    // MARK: Cartão de uma conta

    private func providerCard(_ provider: TapProvider) -> some View {
        let isOpen = expanded == provider.user
        return VStack(alignment: .leading, spacing: 6) {
            CardRow {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle").foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("@\(provider.user)").fontWeight(.medium)
                        Text("\(provider.programCount) programa(s) · \(provider.tapCount) fonte(s)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            } trailing: {
                IconButton(systemImage: "arrow.clockwise", help: "Reverificar a conta @\(provider.user)") {
                    Task { await refresh(provider.user) }
                }
                IconButton(systemImage: isOpen ? "chevron.up" : "chevron.down",
                           help: "Ver programas de @\(provider.user)") {
                    if isOpen { expanded = nil } else { expanded = provider.user; query = "" }
                }
                IconButton(systemImage: "trash", help: "Remover a conta @\(provider.user)") {
                    providers.remove(provider.user)
                    if expanded == provider.user { expanded = nil }
                }
            }

            if isOpen { programList(provider) }
        }
    }

    @ViewBuilder
    private func programList(_ provider: TapProvider) -> some View {
        if provider.programs.isEmpty {
            Text("Nenhum programa compatível encontrado nesta conta.")
                .font(.callout).foregroundStyle(.secondary).padding(.leading, 12)
        } else {
            let matches = filtered(provider.programs)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Buscar programa desta conta…", text: $query).textFieldStyle(.plain)
                Text("\(matches.count) de \(provider.programCount)").font(.caption).foregroundStyle(.secondary)
            }
            .padding(8).cardBackground().padding(.leading, 12)

            ForEach(matches) { program in programRow(program) }

            if matches.isEmpty {
                Text("Nenhum programa com esse nome nesta conta.")
                    .font(.callout).foregroundStyle(.secondary).padding(.leading, 12)
            }
        }
    }

    private func programRow(_ program: TapProgram) -> some View {
        CardRow {
            HStack(spacing: 10) {
                Image(systemName: program.isCask ? "macwindow" : "terminal").foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(program.name)
                        KindTag(isCask: program.isCask)
                    }
                    Text(program.tap).font(.caption2).foregroundStyle(.secondary)
                }
            }
        } trailing: {
            FavoriteButton(name: program.name, tap: program.tap, isCask: program.isCask)
            if brew.isInstalledToken(program.name, isCask: program.isCask) {
                Label("Instalado", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green).labelStyle(.iconOnly)
                    .help("Instalado").frame(width: 24, height: 24)
            } else {
                Button {
                    Task { await brew.installFromTap(tap: program.tap, formula: program.name) }
                } label: { Label("Instalar", systemImage: "arrow.down.circle") }
                .disabled(brew.runningBusy)
            }
        }
        .padding(.leading, 12)
    }

    private func filtered(_ programs: [TapProgram]) -> [TapProgram] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return programs }
        return programs.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    // MARK: Ações

    private func discover() {
        let login = user.trimmingCharacters(in: .whitespaces)
        guard InputValidator.isValidGitHubUser(login) else { return }
        Task {
            if let provider = await github.discoverProvider(user: login) {
                providers.upsert(provider)
                user = ""
                expanded = provider.user
                query = ""
            }
        }
    }

    private func refresh(_ login: String) async {
        if let provider = await github.discoverProvider(user: login) {
            providers.upsert(provider)
        }
    }
}
