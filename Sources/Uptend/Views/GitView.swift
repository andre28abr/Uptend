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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(
                    title: "Repositórios",
                    subtitle: git.scanning ? "Lendo status…" : "\(git.repos.count) monitorados"
                ) {
                    if git.scanning { ProgressView().controlSize(.small) }
                    IconButton(systemImage: "arrow.clockwise", help: "Buscar status (fetch em todos)") {
                        Task { await git.fetchAll(); await git.refreshAll() }
                    }
                    Button {
                        git.addFolder()
                    } label: {
                        Label("Adicionar pasta", systemImage: "folder.badge.plus")
                    }
                }

                if let error = git.lastError {
                    CardRow {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text(error).font(.callout).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    } trailing: {
                        IconButton(systemImage: "xmark", help: "Dispensar") { git.lastError = nil }
                    }
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
                IconButton(systemImage: "arrow.down", help: "Pull") { Task { await git.pull(repo.path) } }
                IconButton(systemImage: "arrow.up", help: "Push") { Task { await git.push(repo.path) } }
            }
            IconButton(systemImage: "minus.circle", help: "Parar de monitorar") { git.remove(repo.path) }
        }
    }
}
