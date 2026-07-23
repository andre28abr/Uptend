import SwiftUI
import UptendCore
import AppKit

/// Navegador de arquivos de um repositório local — só leitura. Árvore à esquerda,
/// conteúdo renderizado à direita (Markdown, código colorido, imagem ou texto).
struct RepoBrowserView: View {
    let rootPath: String
    let title: String
    @Environment(\.dismiss) private var dismiss

    @State private var tree: [FileNode] = []
    @State private var loadingTree = true
    @State private var selected: URL?
    @State private var content: LoadedContent = .none
    @State private var loadingFile = false

    private var rootURL: URL { URL(fileURLWithPath: rootPath) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                fileTree
                    .frame(minWidth: 220, idealWidth: 260, maxWidth: 380)
                contentPane
                    .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 860, minHeight: 560)
        .task {
            let path = rootPath
            tree = await Task.detached { RepoBrowser.buildTree(at: path) }.value
            loadingTree = false
        }
    }

    // MARK: Barra superior

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill").foregroundStyle(.blue)
            Text(title).fontWeight(.medium)
            if let selected {
                Text(relativePath(selected))
                    .font(.callout).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Button {
                NSWorkspace.shared.selectFile(selected?.path, inFileViewerRootedAtPath: rootPath)
            } label: {
                Label("Mostrar no Finder", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.borderless)
            .disabled(selected == nil)
            Button("Fechar") { dismiss() }.keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    // MARK: Árvore

    private var fileTree: some View {
        Group {
            if loadingTree {
                VStack { ProgressView().controlSize(.small); Text("Lendo arquivos…").font(.caption).foregroundStyle(.secondary) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tree.isEmpty {
                ContentUnavailableView("Pasta vazia", systemImage: "folder")
            } else {
                List {
                    OutlineGroup(tree, children: \.children) { node in
                        row(node)
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    private func row(_ node: FileNode) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon(for: node))
                .foregroundStyle(node.isDirectory ? .blue : .secondary)
                .frame(width: 16)
            Text(node.name)
                .lineLimit(1)
                .fontWeight(selected == node.url ? .semibold : .regular)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !node.isDirectory { select(node.url) }
        }
    }

    // MARK: Conteúdo

    @ViewBuilder
    private var contentPane: some View {
        if loadingFile {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch content {
            case .none:
                ContentUnavailableView("Selecione um arquivo", systemImage: "doc.text",
                    description: Text("Escolha um arquivo na árvore para visualizar."))
            case .markdown(let text, let baseDir):
                ScrollView { MarkdownView(text: text, baseDir: baseDir).padding(20) }
            case .code(let text, let language):
                CodeView(code: text, language: language)
            case .text(let text):
                CodeView(code: text, language: "plain")
            case .image(let image):
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image).padding(20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .binary:
                ContentUnavailableView("Arquivo binário", systemImage: "doc.badge.gearshape",
                    description: Text("Este arquivo não é texto — não dá para exibir aqui."))
            case .error:
                ContentUnavailableView("Não foi possível ler", systemImage: "exclamationmark.triangle",
                    description: Text("O arquivo pode ter sido movido ou não ter permissão de leitura."))
            }
        }
    }

    // MARK: Ações

    private func select(_ url: URL) {
        selected = url
        loadingFile = true
        Task {
            let loaded = await Self.load(url)
            await MainActor.run {
                content = loaded
                loadingFile = false
            }
        }
    }

    /// Carrega e classifica o arquivo (fora da main thread).
    private static func load(_ url: URL) async -> LoadedContent {
        let kind = FileKind.detect(name: url.lastPathComponent)
        switch kind {
        case .image:
            if let image = NSImage(contentsOf: url) { return .image(image) }
            return .error
        case .markdown:
            guard let c = RepoBrowser.readText(url) else { return .binary }
            return .markdown(c.text, url.deletingLastPathComponent())
        case .code(let lang):
            guard let c = RepoBrowser.readText(url) else { return .binary }
            return .code(c.text, lang)
        case .text:
            guard let c = RepoBrowser.readText(url) else { return .binary }
            return .text(c.text)
        case .binary:
            // Pode ser um texto sem extensão conhecida — tenta ler mesmo assim.
            if let c = RepoBrowser.readText(url) { return .text(c.text) }
            return .binary
        }
    }

    // MARK: Auxiliares

    private func relativePath(_ url: URL) -> String {
        let base = rootURL.path
        return url.path.hasPrefix(base) ? String(url.path.dropFirst(base.count)) : url.lastPathComponent
    }

    private func icon(for node: FileNode) -> String {
        if node.isDirectory { return "folder" }
        switch FileKind.detect(name: node.name) {
        case .markdown: return "doc.richtext"
        case .image: return "photo"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .text: return "doc.text"
        case .binary: return "doc"
        }
    }
}

/// Alvo para abrir o navegador de arquivos via `.sheet(item:)`.
struct BrowseTarget: Identifiable, Hashable {
    let path: String
    let title: String
    var id: String { path }
}

/// Conteúdo carregado de um arquivo selecionado.
enum LoadedContent {
    case none
    case markdown(String, URL)
    case code(String, String)
    case text(String)
    case image(NSImage)
    case binary
    case error
}
