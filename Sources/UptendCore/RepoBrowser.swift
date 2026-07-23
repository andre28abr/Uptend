import Foundation

/// Um nó (arquivo ou pasta) na árvore de um repositório sendo visualizado.
public struct FileNode: Identifiable, Hashable {
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    /// `nil` para arquivos (folhas); array (possivelmente vazio) para pastas.
    public var children: [FileNode]?

    public init(url: URL, name: String, isDirectory: Bool, children: [FileNode]?) {
        self.url = url; self.name = name; self.isDirectory = isDirectory; self.children = children
    }
    public var id: String { url.path }
}

/// Tipo de arquivo, para decidir como exibir (só leitura).
public enum FileKind: Equatable {
    case markdown
    case image
    case code(String)   // id de linguagem para o realce de sintaxe
    case text
    case binary

    /// Detecta o tipo pelo nome/extensão (heurística, sem abrir o arquivo).
    public static func detect(name: String) -> FileKind {
        let lower = name.lowercased()
        let ext = (lower as NSString).pathExtension

        // Arquivos sem extensão, reconhecidos pelo nome.
        let byName: [String: FileKind] = [
            "dockerfile": .code("shell"),
            "makefile": .code("shell"),
            "brewfile": .code("shell"),
            "podfile": .code("ruby"),
            "gemfile": .code("ruby"),
            "rakefile": .code("ruby"),
            "license": .text,
            "readme": .markdown,
        ]
        if ext.isEmpty, let kind = byName[lower] { return kind }

        if ["md", "markdown", "mdown", "mkd", "mdx"].contains(ext) { return .markdown }
        if ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "heic", "webp", "icns"].contains(ext) { return .image }

        if let lang = Self.language(forExtension: ext) { return .code(lang) }

        if ["txt", "text", "log", "csv", "tsv", "ini", "cfg", "conf", "env", "gitignore",
            "gitattributes", "editorconfig", "lock", "resolved"].contains(ext) { return .text }
        // Dotfiles comuns de shell (sem extensão real): .zshrc, .bash_profile, etc.
        if lower.hasPrefix(".") && (lower.contains("rc") || lower.contains("profile") || lower.contains("env")) {
            return .code("shell")
        }
        if ext.isEmpty { return .text }
        return .binary
    }

    /// Mapeia extensão → família de linguagem usada pelo realce de sintaxe.
    public static func language(forExtension ext: String) -> String? {
        switch ext {
        case "swift": return "swift"
        case "js", "mjs", "cjs", "jsx", "ts", "tsx", "c", "h", "cpp", "cc", "cxx", "hpp",
             "cs", "java", "kt", "kts", "go", "rs", "php", "scala", "dart", "m", "mm":
            return "cfamily"
        case "py", "pyw": return "python"
        case "rb": return "ruby"
        case "sh", "bash", "zsh", "fish", "command": return "shell"
        case "json", "json5", "geojson": return "json"
        case "yaml", "yml": return "yaml"
        case "toml": return "yaml"
        case "css", "scss", "sass", "less": return "css"
        case "html", "htm", "xml", "svg", "vue", "plist", "storyboard", "xib": return "markup"
        case "sql": return "sql"
        default: return nil
        }
    }
}

public enum RepoBrowser {
    /// Pastas que não fazem sentido navegar (ruído / gigantes) — puladas na árvore.
    static let skippedDirs: Set<String> = [
        ".git", "node_modules", ".build", "build", "DerivedData", "Pods", ".swiftpm",
        "dist", "out", "target", "vendor", ".next", ".nuxt", ".venv", "venv", "env",
        "__pycache__", ".gradle", ".idea", "Carthage", ".terraform", "coverage",
    ]

    /// Monta a árvore de arquivos de um repositório, pulando pastas de ruído e
    /// limitando o total de nós (defensivo, para repositórios enormes).
    public static func buildTree(at rootPath: String, nodeLimit: Int = 8000) -> [FileNode] {
        var count = 0
        func build(_ dir: URL) -> [FileNode] {
            guard count < nodeLimit else { return [] }
            let fm = FileManager.default
            guard let entries = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: []) else { return [] }

            var nodes: [FileNode] = []
            for url in entries {
                if count >= nodeLimit { break }
                let name = url.lastPathComponent
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if isDir && skippedDirs.contains(name) { continue }
                count += 1
                if isDir {
                    nodes.append(FileNode(url: url, name: name, isDirectory: true, children: build(url)))
                } else {
                    nodes.append(FileNode(url: url, name: name, isDirectory: false, children: nil))
                }
            }
            return sort(nodes)
        }
        return build(URL(fileURLWithPath: rootPath))
    }

    /// Ordena: pastas primeiro, depois arquivos; alfabético sem diferenciar maiúsculas.
    public static func sort(_ nodes: [FileNode]) -> [FileNode] {
        nodes.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory && !b.isDirectory }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    public struct TextContent {
        public let text: String
        public let truncated: Bool
        public init(text: String, truncated: Bool) { self.text = text; self.truncated = truncated }
    }

    /// Lê um arquivo de texto com limite de tamanho; devolve `nil` se parecer binário.
    public static func readText(_ url: URL, maxBytes: Int = 1_000_000) -> TextContent? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: maxBytes + 1)) ?? Data()
        let truncated = data.count > maxBytes
        let slice = truncated ? data.prefix(maxBytes) : data
        // Heurística de binário: presença de byte NUL nos primeiros KB.
        if slice.prefix(8000).contains(0) { return nil }
        guard let text = String(data: slice, encoding: .utf8) ?? String(data: slice, encoding: .isoLatin1) else {
            return nil
        }
        return TextContent(text: text, truncated: truncated)
    }
}
