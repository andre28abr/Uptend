import Foundation
import SwiftUI

enum AppOrigin: Hashable {
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

struct MacApp: Identifiable, Hashable {
    var id: String { path.path }
    let name: String
    let path: URL
    let bundleID: String?
    let sizeBytes: Int64
    let origin: AppOrigin

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

    func scan() async {
        scanning = true
        let found = await Task.detached { AppsService.scanApplications() }.value
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
    func uninstall(_ app: MacApp, includeResiduals: Bool) async {
        var targets = [app.path]
        if includeResiduals { targets += residualURLs(for: app) }
        for url in targets {
            try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
        ActionLog.shared.record("App desinstalado: \(app.name)")
        await scan()
    }

    // MARK: - Leitura (fora da main actor)

    nonisolated static func scanApplications() -> [MacApp] {
        let fm = FileManager.default
        let dir = URL(fileURLWithPath: "/Applications")
        guard let entries = try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { return [] }

        var result: [MacApp] = []
        for url in entries where url.pathExtension == "app" {
            let name = url.deletingPathExtension().lastPathComponent
            let bundle = Bundle(url: url)
            let bundleID = bundle?.bundleIdentifier
            let size = FileUtils.size(of: url)
            let hasReceipt = fm.fileExists(atPath: url.appendingPathComponent("Contents/_MASReceipt/receipt").path)
            result.append(MacApp(
                name: name,
                path: url,
                bundleID: bundleID,
                sizeBytes: size,
                origin: hasReceipt ? .appStore : .other
            ))
        }
        return result.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
}
