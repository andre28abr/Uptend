import Foundation
import AppKit

struct DotfileItem: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let inSource: Bool
    let inHome: Bool
}

/// Restaura arquivos de configuração ("dotfiles") de uma pasta de backup escolhida
/// pelo usuário. Só mexe numa lista fixa de arquivos conhecidos (sem path traversal)
/// e SEMPRE faz backup do arquivo atual antes de sobrescrever (reversível).
@MainActor
final class DotfilesService: ObservableObject {
    @Published var sourcePath: String?
    @Published var items: [DotfileItem] = []
    @Published var message: String?

    /// Lista fixa de dotfiles suportados (nomes simples, sem separador de caminho).
    static let known = [
        ".zshrc", ".zprofile", ".zshenv", ".bashrc", ".bash_profile", ".profile",
        ".gitconfig", ".gitignore_global", ".vimrc", ".tmux.conf", ".aliases", ".editorconfig",
    ]

    private let defaultsKey = "uptend.dotfilesSource"

    init() {
        sourcePath = UserDefaults.standard.string(forKey: defaultsKey)
        if sourcePath != nil { scan() }
    }

    func pickSource() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Escolher"
        panel.message = "Escolha a pasta com seus dotfiles (backup)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        sourcePath = url.path
        UserDefaults.standard.set(url.path, forKey: defaultsKey)
        scan()
    }

    func scan() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let source = sourcePath.map { URL(fileURLWithPath: $0) }

        items = Self.known.compactMap { name in
            let inHome = fm.fileExists(atPath: home.appendingPathComponent(name).path)
            let inSource = source.map { fm.fileExists(atPath: $0.appendingPathComponent(name).path) } ?? false
            guard inSource || inHome else { return nil }
            return DotfileItem(name: name, inSource: inSource, inHome: inHome)
        }
    }

    /// Copia o dotfile da origem para o home, guardando o atual como `<nome>.uptend.bak`.
    func restore(_ item: DotfileItem) {
        guard Self.known.contains(item.name), let sourcePath else { return }
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let src = URL(fileURLWithPath: sourcePath).appendingPathComponent(item.name)
        let dest = home.appendingPathComponent(item.name)

        guard fm.fileExists(atPath: src.path) else { message = "Arquivo não encontrado na origem."; return }

        var backedUp = false
        if fm.fileExists(atPath: dest.path) {
            let backup = home.appendingPathComponent(item.name + ".uptend.bak")
            try? fm.removeItem(at: backup)
            do { try fm.moveItem(at: dest, to: backup); backedUp = true } catch {}
        }
        do {
            try fm.copyItem(at: src, to: dest)
            message = "\(item.name) restaurado (backup em \(item.name).uptend.bak)."
            ActionLog.shared.record("Dotfile restaurado: \(item.name)")
        } catch {
            // Se já movemos o original para .bak, avisamos como recuperá-lo.
            message = backedUp
                ? "Falha ao restaurar \(item.name). Seu arquivo original está salvo como \(item.name).uptend.bak — renomeie de volta para recuperá-lo."
                : "Falha ao restaurar \(item.name)."
        }
        scan()
    }
}
