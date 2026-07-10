import Foundation

/// Um alvo de limpeza. `kind` define o comportamento e, principalmente, se é reversível.
struct CleanupTarget: Identifiable, Sendable {
    let id: String
    let name: String
    let detail: String
    let kind: Kind
    var sizeBytes: Int64 = 0
    var count: Int? = nil   // usado pela Lixeira (contagem via Finder), no lugar de bytes

    enum Kind: Sendable {
        case emptyTrash              // esvazia a Lixeira via Finder (contorna a proteção TCC)
        case trashContents(URL)      // move o CONTEÚDO da pasta para a Lixeira (reversível)
        case trashPaths([URL])       // move caminhos específicos para a Lixeira (reversível)
        case brewCleanup             // roda `brew cleanup` (tratado via BrewService)
    }

    /// Ir para a Lixeira é reversível; esvaziar a Lixeira e o brew cleanup, não.
    var isReversible: Bool {
        switch kind {
        case .trashContents, .trashPaths: return true
        case .emptyTrash, .brewCleanup: return false
        }
    }

    var isBrewCleanup: Bool {
        if case .brewCleanup = kind { return true }
        return false
    }

    var isEmptyTrash: Bool {
        if case .emptyTrash = kind { return true }
        return false
    }

    /// Nada a fazer? (Lixeira vazia ou pasta com 0 bytes.)
    var isEmpty: Bool {
        if let count { return count == 0 }
        return sizeBytes == 0
    }
}

/// Calcula tamanhos reais e executa a limpeza (reversível via Lixeira sempre que possível).
@MainActor
final class CleanupService: ObservableObject {
    @Published var targets: [CleanupTarget] = []
    @Published var scanning = false
    @Published var currentSubID: String?

    func scan(_ subID: String) async {
        currentSubID = subID
        scanning = true
        defer { scanning = false }

        var base = Self.targets(for: subID)

        // A Lixeira é lida via Finder (a pasta ~/.Trash é protegida por TCC).
        for index in base.indices where base[index].isEmptyTrash {
            base[index].count = await finderTrashCount()
        }

        let byteTargets = base
        let sized = await Task.detached {
            byteTargets.map { target -> CleanupTarget in
                var copy = target
                copy.sizeBytes = CleanupService.computeSize(target.kind)
                return copy
            }
        }.value

        // Evita sobrescrever caso o usuário já tenha trocado de subseção.
        if currentSubID == subID { targets = sized }
    }

    private func finderTrashCount() async -> Int {
        let out = await Shell.capture("/usr/bin/osascript",
                                      ["-e", "tell application \"Finder\" to count items of trash"])
        return Int(out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    func clean(_ target: CleanupTarget) async {
        let fm = FileManager.default
        switch target.kind {
        case .emptyTrash:
            _ = await Shell.capture("/usr/bin/osascript",
                                    ["-e", "tell application \"Finder\" to empty the trash"])
        case .trashContents(let dir):
            for item in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] {
                try? fm.trashItem(at: item, resultingItemURL: nil)
            }
        case .trashPaths(let urls):
            for url in urls where fm.fileExists(atPath: url.path) {
                try? fm.trashItem(at: url, resultingItemURL: nil)
            }
        case .brewCleanup:
            break // executado pela BrewService a partir da view
        }
        ActionLog.shared.record("Limpeza: \(target.name)")
        if let subID = currentSubID { await scan(subID) }
    }

    // MARK: - Definição dos alvos (puro, testável)

    nonisolated static func targets(for subID: String) -> [CleanupTarget] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        func path(_ p: String) -> URL { home.appendingPathComponent(p) }

        switch subID {
        case "trash":
            return [CleanupTarget(id: "trash", name: "Esvaziar Lixeira",
                                  detail: "Remove os itens da Lixeira permanentemente",
                                  kind: .emptyTrash)]
        case "caches":
            return [CleanupTarget(id: "user-caches", name: "Caches de usuário",
                                  detail: "~/Library/Caches",
                                  kind: .trashContents(path("Library/Caches")))]
        case "logs":
            return [CleanupTarget(id: "user-logs", name: "Logs de usuário",
                                  detail: "~/Library/Logs",
                                  kind: .trashContents(path("Library/Logs")))]
        case "downloads":
            return [CleanupTarget(id: "old-downloads", name: "Downloads antigos",
                                  detail: "Arquivos com mais de 30 dias",
                                  kind: .trashPaths(oldFiles(in: path("Downloads"), olderThanDays: 30)))]
        case "dev":
            return [
                CleanupTarget(id: "deriveddata", name: "Xcode DerivedData",
                              detail: "Builds intermediários (recriados sozinhos)",
                              kind: .trashPaths([path("Library/Developer/Xcode/DerivedData")])),
                CleanupTarget(id: "npm", name: "Cache do npm",
                              detail: "~/.npm",
                              kind: .trashPaths([path(".npm/_cacache")])),
                CleanupTarget(id: "cocoapods", name: "Cache do CocoaPods",
                              detail: "~/Library/Caches/CocoaPods",
                              kind: .trashPaths([path("Library/Caches/CocoaPods")])),
                CleanupTarget(id: "brew", name: "Homebrew cleanup",
                              detail: "Versões antigas de fórmulas",
                              kind: .brewCleanup),
            ]
        default:
            return []
        }
    }

    /// Arquivos/pastas diretos de `dir` com data de modificação anterior a N dias.
    nonisolated static func oldFiles(in dir: URL, olderThanDays days: Int) -> [URL] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]
        ) else { return [] }

        let cutoff = Date(timeIntervalSinceNow: -Double(days) * 86400)
        return items.filter { url in
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            guard let modified = values?.contentModificationDate else { return false }
            return modified < cutoff
        }
    }

    nonisolated static func computeSize(_ kind: CleanupTarget.Kind) -> Int64 {
        switch kind {
        case .trashContents(let dir):
            return FileUtils.size(of: dir)
        case .trashPaths(let urls):
            return urls.reduce(0) { $0 + FileUtils.size(of: $1) }
        case .emptyTrash, .brewCleanup:
            return 0
        }
    }
}
