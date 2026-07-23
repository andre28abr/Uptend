import SwiftUI
import AppKit

// MARK: - Conta GitHub

/// Conectar/desconectar a conta do GitHub via token pessoal (guardado no Keychain).
struct GitHubAccountView: View {
    @EnvironmentObject var github: GitHubService
    @State private var token = ""

    private let createTokenURL = "https://github.com/settings/personal-access-tokens/new"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Conta GitHub",
                             subtitle: github.isConnected ? "Conectado"
                                 : (github.hasToken ? "Reconectando…" : "Conecte para clonar e enviar em repositórios privados"))

                if github.isConnected {
                    connectedCard
                } else if github.hasToken {
                    tokenPresentCard
                } else {
                    connectForm
                }

                if let error = github.lastError {
                    CardRow {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text(error).font(.callout).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                        }
                    } trailing: {
                        IconButton(systemImage: "xmark", help: "Dispensar") { github.lastError = nil }
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 720, alignment: .leading)
        }
        .task { await github.restoreIdentityIfNeeded() }
    }

    /// Há um token no Keychain, mas a identidade ainda não foi carregada
    /// (ex.: conectado antes do cache existir). Recarrega ao abrir a tela.
    private var tokenPresentCard: some View {
        CardRow {
            HStack(spacing: 12) {
                if github.restoring {
                    ProgressView().controlSize(.small).frame(width: 24)
                } else {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.title2).foregroundStyle(.orange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Token salvo").fontWeight(.medium)
                    Text(github.restoring ? "Carregando os dados da sua conta…"
                         : "Sua conexão está guardada. Toque em Atualizar para recarregar a conta.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        } trailing: {
            Button("Atualizar") { Task { await github.restoreIdentityIfNeeded() } }
                .disabled(github.restoring)
            Button("Desconectar", role: .destructive) { github.disconnect() }
        }
    }

    private var connectedCard: some View {
        CardRow {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.title2).foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(github.account?.name ?? github.account?.login ?? "—").fontWeight(.medium)
                    Text("@\(github.account?.login ?? "")").font(.callout).foregroundStyle(.secondary)
                }
            }
        } trailing: {
            IconButton(systemImage: "safari", help: "Abrir perfil no GitHub") {
                if let s = github.account?.htmlURL, let url = URL(string: s) { NSWorkspace.shared.open(url) }
            }
            Button("Desconectar", role: .destructive) { github.disconnect() }
        }
    }

    private var connectForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Como conectar").fontWeight(.medium)
                stepRow(1, "Gere um token fine-grained no GitHub", "Repository access: só os repositórios que quiser.")
                stepRow(2, "Dê as permissões mínimas", "Contents: Read and write · Metadata: Read-only.")
                stepRow(3, "Cole o token abaixo", "Ele fica guardado no Keychain do macOS, cifrado.")
                Button {
                    if let url = URL(string: createTokenURL) { NSWorkspace.shared.open(url) }
                } label: {
                    Label("Criar token no GitHub", systemImage: "arrow.up.forward.app")
                }
                .padding(.top, 2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardBackground()

            VStack(alignment: .leading, spacing: 6) {
                Text("Token de acesso").font(.caption).foregroundStyle(.secondary)
                HStack {
                    SecureField("github_pat_… ou ghp_…", text: $token)
                        .textFieldStyle(.plain).padding(10).cardBackground()
                    Button {
                        Task { await github.connect(token: token); if github.isConnected { token = "" } }
                    } label: {
                        if github.connecting { ProgressView().controlSize(.small) } else { Text("Conectar") }
                    }
                    .disabled(github.connecting || token.trimmed.isEmpty)
                }
                Text("Nada é enviado sem você pedir. O token nunca aparece em comandos nem no .git/config.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func stepRow(_ n: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)").font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .background(.quaternary, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Publicar pasta (criar repo + push)

struct PublishRepoView: View {
    @EnvironmentObject var github: GitHubService
    @EnvironmentObject var git: GitService
    @State private var folderPath: String?
    @State private var name = ""
    @State private var isPrivate = true
    @State private var description = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Publicar pasta",
                             subtitle: "Envie um projeto local para um novo repositório no GitHub")

                if !github.isConnected {
                    ContentUnavailableView {
                        Label("Conecte sua conta", systemImage: "person.crop.circle.badge.exclamationmark")
                    } description: {
                        Text("Vá em \"Conta GitHub\" e conecte para poder criar repositórios.")
                    }
                    .padding(.top, 40)
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle").foregroundStyle(.blue)
                        Text("Escolha uma pasta do seu Mac. O Uptend cria um repositório novo no GitHub e envia tudo — sem terminal. Se a pasta ainda não for um repositório Git, ele inicializa e faz o primeiro commit.")
                            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()

                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.prompt = "Escolher"
                            if panel.runModal() == .OK, let url = panel.url {
                                folderPath = url.path
                                if name.isEmpty { name = url.lastPathComponent }
                            }
                        } label: {
                            Label(folderPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Escolher pasta…",
                                  systemImage: "folder.badge.plus")
                        }
                        if let folderPath {
                            Text(folderPath).font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.middle)
                        }

                        Text("Nome do repositório").font(.caption).foregroundStyle(.secondary)
                        TextField("meu-projeto", text: $name)
                            .textFieldStyle(.plain).padding(9).cardBackground()

                        Text("Descrição (opcional)").font(.caption).foregroundStyle(.secondary)
                        TextField("O que é este projeto", text: $description)
                            .textFieldStyle(.plain).padding(9).cardBackground()

                        Toggle(isOn: $isPrivate) {
                            Text(isPrivate ? "Privado (só você vê)" : "Público (qualquer um vê)")
                        }

                        HStack {
                            Button {
                                if let folderPath {
                                    Task {
                                        await github.publish(folderPath: folderPath, name: name,
                                                             isPrivate: isPrivate, description: description)
                                        if github.publishedURL != nil { git.addPath(folderPath) }
                                    }
                                }
                            } label: {
                                if github.publishing { ProgressView().controlSize(.small) }
                                else { Label("Publicar no GitHub", systemImage: "square.and.arrow.up") }
                            }
                            .keyboardShortcut(.defaultAction)
                            .disabled(github.publishing || folderPath == nil || name.trimmed.isEmpty)
                        }
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()

                    if let error = github.lastError {
                        ErrorBanner(error) { github.lastError = nil }
                    }
                    if let url = github.publishedURL {
                        CardRow {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Publicado!").fontWeight(.medium)
                                    Text(url).font(.caption).foregroundStyle(.secondary)
                                        .lineLimit(1).truncationMode(.middle)
                                }
                            }
                        } trailing: {
                            IconButton(systemImage: "safari", help: "Abrir no GitHub") {
                                if let u = URL(string: url) { NSWorkspace.shared.open(u) }
                            }
                        }
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 720, alignment: .leading)
        }
    }
}

// MARK: - Configurações do repositório

struct RepoSettingsSheet: View {
    let repo: GitHubRepo
    @EnvironmentObject var github: GitHubService
    @Environment(\.dismiss) private var dismiss
    @State private var isPrivate: Bool
    @State private var description: String
    @State private var confirmPublic = false
    @State private var saving = false

    init(repo: GitHubRepo) {
        self.repo = repo
        _isPrivate = State(initialValue: repo.isPrivate)
        _description = State(initialValue: repo.description ?? "")
    }

    private var goingPublic: Bool { repo.isPrivate && !isPrivate }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Configurações — \(repo.name)").font(.title3).fontWeight(.medium)

            VStack(alignment: .leading, spacing: 6) {
                Text("Descrição").font(.caption).foregroundStyle(.secondary)
                TextField("Descrição do repositório", text: $description)
                    .textFieldStyle(.plain).padding(9).cardBackground()
            }
            Picker("Visibilidade", selection: $isPrivate) {
                Text("Privado (só você)").tag(true)
                Text("Público (qualquer um)").tag(false)
            }.pickerStyle(.segmented)

            if goingPublic {
                Label("Tornar público expõe o código para sempre — qualquer pessoa poderá ver e clonar.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            Text("Alterar a visibilidade/descrição exige a permissão \"Administration: Read and write\" no seu token.")
                .font(.caption).foregroundStyle(.secondary)

            if let error = github.lastError { ErrorBanner(error) { github.lastError = nil } }

            Spacer()
            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }.keyboardShortcut(.cancelAction)
                Button {
                    if goingPublic { confirmPublic = true } else { save() }
                } label: {
                    if saving { ProgressView().controlSize(.small) } else { Text("Salvar") }
                }
                .keyboardShortcut(.defaultAction).disabled(saving)
            }
        }
        .padding(20).frame(width: 470, height: 360)
        .confirmationDialog("Tornar \"\(repo.name)\" público?", isPresented: $confirmPublic, titleVisibility: .visible) {
            Button("Tornar público", role: .destructive) { save() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("O código ficará visível para qualquer pessoa na internet. Difícil de desfazer.")
        }
    }

    private func save() {
        saving = true
        Task {
            let ok = await github.updateRepo(fullName: repo.fullName, isPrivate: isPrivate, description: description)
            saving = false
            if ok { dismiss() }
        }
    }
}

// MARK: - Meus repositórios (listar + clonar)

struct GitHubReposView: View {
    @EnvironmentObject var github: GitHubService
    @EnvironmentObject var git: GitService
    @State private var query = ""
    @State private var browseTarget: BrowseTarget?
    @State private var settingsTarget: GitHubRepo?

    private var filtered: [GitHubRepo] {
        let q = query.trimmed.lowercased()
        guard !q.isEmpty else { return github.repos }
        return github.repos.filter {
            $0.name.lowercased().contains(q) || ($0.description?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Meus repositórios",
                             subtitle: github.repos.isEmpty ? "Da sua conta do GitHub" : "\(github.repos.count) repositórios") {
                    if github.loadingRepos { ProgressView().controlSize(.small) }
                    IconButton(systemImage: "arrow.clockwise", help: "Atualizar lista") {
                        Task { await github.loadRepos() }
                    }
                }

                if !github.isConnected {
                    ContentUnavailableView {
                        Label("Conecte sua conta", systemImage: "person.crop.circle.badge.exclamationmark")
                    } description: {
                        Text("Vá em \"Conta GitHub\" e conecte para listar e clonar seus repositórios (inclusive privados).")
                    }
                    .padding(.top, 40)
                } else {
                    if !github.repos.isEmpty {
                        TextField("Filtrar", text: $query)
                            .textFieldStyle(.plain).padding(9).cardBackground()
                    }

                    if github.repos.isEmpty && !github.loadingRepos {
                        ContentUnavailableView {
                            Label("Nenhum repositório carregado", systemImage: "square.grid.2x2")
                        } description: {
                            Text("Toque em atualizar para buscar os repositórios da sua conta.")
                        } actions: {
                            Button("Carregar repositórios") { Task { await github.loadRepos() } }
                        }
                        .padding(.top, 30)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(filtered) { repo in row(repo) }
                        }
                    }
                }

                if let error = github.lastError {
                    Text(error).font(.callout).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
        .sheet(item: $browseTarget) { target in
            RepoBrowserView(rootPath: target.path, title: target.title)
        }
        .sheet(item: $settingsTarget) { repo in
            RepoSettingsSheet(repo: repo)
        }
    }

    private func localPath(_ repo: GitHubRepo) -> String? {
        git.repos.first { $0.name == repo.name }?.path
    }
    private func alreadyCloned(_ repo: GitHubRepo) -> Bool {
        localPath(repo) != nil
    }

    private func row(_ repo: GitHubRepo) -> some View {
        CardRow {
            HStack(spacing: 12) {
                Image(systemName: repo.isPrivate ? "lock.fill" : "book.closed")
                    .foregroundStyle(repo.isPrivate ? .orange : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(repo.name).fontWeight(.medium)
                        Text(repo.isPrivate ? "privado" : "público")
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                        if repo.fork {
                            Image(systemName: "tuningfork").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Text(repo.description ?? repo.fullName)
                        .font(.callout).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.tail)
                }
            }
        } trailing: {
            IconButton(systemImage: "gearshape", help: "Configurações do repositório (visibilidade, descrição)") {
                settingsTarget = repo
            }
            IconButton(systemImage: "safari", help: "Abrir no GitHub") {
                if let url = URL(string: repo.htmlURL) { NSWorkspace.shared.open(url) }
            }
            if let path = localPath(repo) {
                IconButton(systemImage: "doc.text.magnifyingglass", help: "Ver arquivos") {
                    browseTarget = BrowseTarget(path: path, title: repo.name)
                }
                Text("clonado").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
            } else {
                IconButton(systemImage: "arrow.down.circle", help: "Clonar…") { clone(repo) }
            }
        }
    }

    private func clone(_ repo: GitHubRepo) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Clonar aqui"
        panel.message = "Escolha onde criar a pasta \"\(repo.name)\""
        guard panel.runModal() == .OK, let parent = panel.url else { return }
        Task {
            if let path = await github.clone(repo, into: parent) {
                git.addPath(path)
            }
        }
    }
}
