import Foundation
import SwiftUI

enum AppOrigin: Hashable, Sendable {
    case appStore
    case other

    var label: String {
        switch self {
        case .appStore: "App Store"
        case .other: "Manual / Homebrew"
        }
    }

    var systemImage: String {
        switch self {
        case .appStore: "bag"
        case .other: "shippingbox"
        }
    }

    var color: Color {
        switch self {
        case .appStore: .blue
        case .other: .secondary
        }
    }
}

struct MacApp: Identifiable, Hashable, Sendable {
    var id: String { path.path }
    let name: String
    let path: URL
    let bundleID: String?
    let sizeBytes: Int64
    let origin: AppOrigin
    var version: String?
    /// App pertencente ao root (instalado com admin, via .pkg) — mover para a Lixeira
    /// exige autenticação de administrador.
    var ownerIsRoot: Bool = false

    var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

/// Lista os apps em /Applications e permite desinstalá-los movendo para a Lixeira
/// (reversível — Privacy/Security by Design: nada é apagado de forma permanente aqui).
@MainActor
final class AppsService: ObservableObject {
    @Published var apps: [MacApp] = []
    @Published var scanning = false
    @Published var lastError: String?

    func scan() async {
        scanning = true
        let urls = await Task.detached { AppsService.appURLs() }.value
        // Dimensiona os bundles em PARALELO (antes era sequencial — dezenas de apps,
        // cada um somando recursivamente o tamanho, levava vários segundos).
        let found = await withTaskGroup(of: MacApp.self) { group in
            for url in urls { group.addTask { AppsService.makeApp(url) } }
            var r: [MacApp] = []
            for await app in group { r.append(app) }
            return r.sorted { $0.name.lowercased() < $1.name.lowercased() }
        }
        apps = found
        scanning = false
    }

    /// Arquivos residuais (configs/caches) associados ao bundle id. Conservador:
    /// só caminhos que casam exatamente com o identificador do app.
    ///
    /// Segurança: o bundle id vem do Info.plist do app (não confiável) — validamos
    /// contra reverse-DNS e confirmamos que cada caminho resolvido fica DENTRO de
    /// `~/Library`, para impedir path traversal (ex.: id malicioso com `../`).
    func residualURLs(for app: MacApp) -> [URL] {
        guard let id = app.bundleID, InputValidator.isValidBundleID(id) else { return [] }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let libraryPrefix = home.appendingPathComponent("Library").standardizedFileURL.path + "/"
        let relative = [
            "Library/Preferences/\(id).plist",
            "Library/Caches/\(id)",
            "Library/Containers/\(id)",
            "Library/Application Support/\(id)",
            "Library/Logs/\(id)",
            "Library/Saved Application State/\(id).savedState",
            "Library/HTTPStorages/\(id)",
        ]
        return relative
            .map { home.appendingPathComponent($0).standardizedFileURL }
            .filter { $0.path.hasPrefix(libraryPrefix) && FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Move o app (e, opcionalmente, os residuais) para a Lixeira. Reversível.
    ///
    /// Apps do sistema (root, instalados via .pkg) não podem ir para a Lixeira sem
    /// autenticação — nesses casos usamos o Finder, que pede a senha de administrador.
    /// Erros deixam de ser silenciosos: viram `lastError` para a interface mostrar.
    func uninstall(_ app: MacApp, includeResiduals: Bool) async {
        lastError = nil
        var failed = false

        if app.ownerIsRoot {
            let result = await moveToTrashAuthenticated(app.path)
            if !result.ok {
                failed = true
                lastError = result.cancelled
                    ? "Remoção cancelada — mover \"\(app.name)\" para a Lixeira exige a senha de administrador."
                    : "Não foi possível mover \"\(app.name)\" para a Lixeira. Ele pertence ao sistema; tente pelo Finder ou pelo instalador do próprio app."
            }
        } else {
            do {
                try FileManager.default.trashItem(at: app.path, resultingItemURL: nil)
            } catch {
                failed = true
                lastError = "Não foi possível mover \"\(app.name)\" para a Lixeira: \(error.localizedDescription)"
            }
        }

        // Residuais ficam em ~/Library (do usuário) — best-effort, não bloqueiam.
        if includeResiduals {
            for url in residualURLs(for: app) {
                try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
            }
        }

        if !failed { ActionLog.shared.record("App desinstalado: \(app.name)") }
        await scan()
    }

    /// Move um item para a Lixeira via Finder — o macOS pede a senha de administrador
    /// para itens protegidos (root). Continua reversível (vai para a Lixeira, não apaga).
    private func moveToTrashAuthenticated(_ path: URL) async -> (ok: Bool, cancelled: Bool) {
        guard InputValidator.isSafeAppleScriptText(path.path) else { return (false, false) }
        let script = "tell application \"Finder\" to delete (POSIX file \"\(path.path)\" as alias)"
        let result = await Shell.capture("/usr/bin/osascript", ["-e", script])
        if result.ok { return (true, false) }
        let err = result.stderr.lowercased()
        let cancelled = err.contains("-128") || err.contains("cancel")
        return (false, cancelled)
    }

    // MARK: - Leitura (fora da main actor)

    /// Lista os bundles `.app` em /Applications (rápido — sem dimensionar).
    nonisolated static func appURLs() -> [URL] {
        let dir = URL(fileURLWithPath: "/Applications")
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { return [] }
        return entries.filter { $0.pathExtension == "app" }
    }

    /// Monta um `MacApp` (inclui o dimensionamento recursivo — parte lenta, roda em paralelo).
    nonisolated static func makeApp(_ url: URL) -> MacApp {
        let fm = FileManager.default
        let name = url.deletingPathExtension().lastPathComponent
        let bundle = Bundle(url: url)
        let bundleID = bundle?.bundleIdentifier
        let size = FileUtils.size(of: url)
        let hasReceipt = fm.fileExists(atPath: url.appendingPathComponent("Contents/_MASReceipt/receipt").path)
        let ownerID = (try? fm.attributesOfItem(atPath: url.path))?[.ownerAccountID] as? NSNumber
        let version = bundle?.infoDictionary?["CFBundleShortVersionString"] as? String
        return MacApp(name: name, path: url, bundleID: bundleID, sizeBytes: size,
                      origin: hasReceipt ? .appStore : .other, version: version,
                      ownerIsRoot: ownerID?.intValue == 0)
    }
}
