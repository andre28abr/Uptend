import SwiftUI

struct GitView: View {
    let sub: SubSection?
    @EnvironmentObject var git: GitService

    private var items: [GitRepoInfo] {
        switch sub?.id {
        case "dirty":
            return git.repos.filter { $0.dirty }
        case "desync":
            return git.repos.filter { $0.ahead > 0 || $0.behind > 0 }
        default:
            return git.repos
        }
    }

    var body: some View {
        switch sub?.id {
        case "favorites": FavoritesView()
        case "account": GitHubAccountView()
        case "browse": GitHubReposView()
        case "publish": PublishRepoView()
        default: reposContent
        }
    }

    @State private var committing: GitRepoInfo?
    @State private var browseTarget: BrowseTarget?

    private var reposContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(
                    title: "Repositórios",
                    subtitle: git.scanning ? "Lendo status…" : "\(git.repos.count) monitorados"
                ) {
                    if git.scanning { ProgressView().controlSize(.small) }
                    IconButton(systemImage: "arrow.clockwise", help: "Verificar novidades do GitHub em todos os repositórios (não altera seus arquivos)") {
                        Task { await git.fetchAll(); await git.refreshAll() }
                    }
                    Button {
                        git.addFolder()
                    } label: {
                        Label("Adicionar pasta", systemImage: "folder.badge.plus")
                    }
                }

                if let error = git.lastError {
                    ErrorBanner(error) { git.lastError = nil }
                }

                if git.repos.isEmpty && !git.scanning {
                    ContentUnavailableView {
                        Label("Nenhuma pasta monitorada", systemImage: "arrow.triangle.branch")
                    } description: {
                        Text("Adicione pastas de repositórios Git para acompanhar o status e sincronizar.")
                    } actions: {
                        Button("Adicionar pasta") { git.addFolder() }
                    }
                    .padding(.top, 40)
                } else {
                    VStack(spacing: 8) {
                        ForEach(items) { repo in
                            row(repo)
                        }
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
        .task {
            if git.repos.isEmpty { await git.load() }
        }
        .sheet(item: $committing) { repo in
            CommitSheet(repo: repo)
        }
        .sheet(item: $browseTarget) { target in
            RepoBrowserView(rootPath: target.path, title: target.title)
        }
    }

    private func row(_ repo: GitRepoInfo) -> some View {
        CardRow {
            HStack(spacing: 12) {
                Image(systemName: repo.isRepo ? repo.status.systemImage : "questionmark.circle.fill")
                    .foregroundStyle(repo.isRepo ? repo.status.color : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(repo.name).fontWeight(.medium)
                        if repo.isRepo {
                            Text(repo.branch)
                                .font(.caption)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                    Text(repo.error ?? repo.path)
                        .font(.callout).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
        } trailing: {
            if git.busyPath == repo.path {
                ProgressView().controlSize(.small).frame(width: 24, height: 24)
            } else if repo.isRepo {
                Text(repo.status.label)
                    .font(.caption).foregroundStyle(.secondary).padding(.trailing, 4)
                IconButton(systemImage: "doc.text.magnifyingglass", help: "Ver os arquivos deste repositório (só leitura)") {
                    browseTarget = BrowseTarget(path: repo.path, title: repo.name)
                }
                if repo.dirty {
                    IconButton(systemImage: "paperplane", help: "Enviar alterações: salva um commit e sobe para o GitHub") {
                        committing = repo
                    }
                }
                IconButton(systemImage: "arrow.down", help: "Baixar (pull): traz as mudanças do GitHub para o seu Mac") { Task { await git.pull(repo.path) } }
                IconButton(systemImage: "arrow.up", help: "Enviar (push): sobe os seus commits para o GitHub") { Task { await git.push(repo.path) } }
            }
            IconButton(systemImage: "minus.circle", help: "Parar de monitorar esta pasta (não apaga nada do seu Mac)") { git.remove(repo.path) }
        }
    }
}

// MARK: - Folha de commit ("Enviar alterações")

/// Mostra os arquivos alterados e recebe a mensagem, faz commit + push num clique.
struct CommitSheet: View {
    let repo: GitRepoInfo
    @EnvironmentObject var git: GitService
    @Environment(\.dismiss) private var dismiss

    @State private var files: [GitFileChange] = []
    @State private var loading = true
    @State private var message = ""
    @State private var sending = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Enviar alterações").font(.title3).fontWeight(.medium)
                Text("\(repo.name) · \(repo.branch)").font(.callout).foregroundStyle(.secondary)
            }

            if loading {
                HStack { ProgressView().controlSize(.small); Text("Lendo alterações…").foregroundStyle(.secondary) }
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if files.isEmpty {
                Text("Nenhuma alteração para enviar.").foregroundStyle(.secondary)
            } else {
                Text("\(files.count) arquivo(s) alterado(s)").font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(files) { file in
                            HStack(spacing: 8) {
                                Image(systemName: file.systemImage).foregroundStyle(.secondary).font(.caption)
                                Text(file.path).font(.callout).lineLimit(1).truncationMode(.middle)
                                Spacer()
                                Text(file.label).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxHeight: 160)
                .padding(10)
                .cardBackground()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Mensagem").font(.caption).foregroundStyle(.secondary)
                TextField("Descreva o que mudou", text: $message)
                    .textFieldStyle(.plain).padding(10).cardBackground()
                Button("Usar mensagem automática") {
                    message = "Atualização via Uptend"
                }
                .buttonStyle(.link).font(.caption)
            }

            if let error = git.lastError {
                Text(error).font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }.keyboardShortcut(.cancelAction)
                Button {
                    Task {
                        sending = true
                        let ok = await git.commitAndPush(repo.path, message: message)
                        sending = false
                        if ok { dismiss() }
                    }
                } label: {
                    if sending {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Commit e enviar")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(sending || files.isEmpty || message.trimmed.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
        .task {
            git.lastError = nil
            files = await git.changedFiles(repo.path)
            loading = false
        }
    }
}
