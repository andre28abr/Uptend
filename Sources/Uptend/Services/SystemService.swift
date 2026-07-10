import Foundation
import SwiftUI

struct MacInfo {
    var model = "—"
    var chip = "—"
    var cores = 0
    var memory = "—"
    var osVersion = "—"
    var uptime = "—"
    var diskFree = "—"
    var diskTotal = "—"
    var batteryCycles = "—"
}

/// Um ajuste rápido do sistema baseado em `defaults` (sem sudo, por usuário).
struct SystemToggle: Identifiable {
    let id: String
    let section: String
    let title: String
    let help: String
    let domain: String   // "com.apple.finder", "NSGlobalDomain", ...
    let key: String
    var restart: Restart = .none
    /// Alguns ajustes começam ligados por padrão no macOS mesmo sem a chave existir.
    var defaultOn: Bool = false
    /// Quando true, "ligado" na UI grava `false` na chave (ex.: sombra vs. `disable-shadow`).
    var inverted: Bool = false

    /// Processo a reiniciar para o ajuste ter efeito imediato.
    enum Restart: String {
        case none = ""
        case finder = "Finder"
        case dock = "Dock"
        case systemUIServer = "SystemUIServer"
    }
}

/// Informações do Mac, itens de inicialização e ajustes rápidos.
@MainActor
final class SystemService: ObservableObject {
    @Published var info = MacInfo()
    @Published var loadingInfo = false

    @Published var loginItems: [String] = []
    @Published var loginItemsError: String?
    @Published var loadingLogin = false

    @Published var toggleStates: [String: Bool] = [:]

    static let toggles: [SystemToggle] = [
        // Finder
        SystemToggle(id: "hidden", section: "Finder", title: "Mostrar arquivos ocultos",
                     help: "Exibe arquivos e pastas ocultos no Finder",
                     domain: "com.apple.finder", key: "AppleShowAllFiles", restart: .finder),
        SystemToggle(id: "extensions", section: "Finder", title: "Mostrar todas as extensões",
                     help: "Exibe a extensão de todos os arquivos",
                     domain: "NSGlobalDomain", key: "AppleShowAllExtensions", restart: .finder),
        SystemToggle(id: "pathbar", section: "Finder", title: "Mostrar barra de caminho",
                     help: "Exibe o caminho completo na base das janelas do Finder",
                     domain: "com.apple.finder", key: "ShowPathbar", restart: .finder),
        SystemToggle(id: "statusbar", section: "Finder", title: "Mostrar barra de status",
                     help: "Exibe itens e espaço livre na base das janelas do Finder",
                     domain: "com.apple.finder", key: "ShowStatusBar", restart: .finder),
        SystemToggle(id: "foldersfirst", section: "Finder", title: "Pastas sempre no topo",
                     help: "Ao ordenar por nome, mostra as pastas antes dos arquivos",
                     domain: "com.apple.finder", key: "_FXSortFoldersFirst", restart: .finder),
        SystemToggle(id: "posixtitle", section: "Finder", title: "Caminho completo no título",
                     help: "Mostra o caminho POSIX completo na barra de título da janela",
                     domain: "com.apple.finder", key: "_FXShowPosixPathInTitle", restart: .finder),

        // Dock
        SystemToggle(id: "autohide", section: "Dock", title: "Ocultar o Dock automaticamente",
                     help: "O Dock some quando não está em uso",
                     domain: "com.apple.dock", key: "autohide", restart: .dock),
        SystemToggle(id: "recents", section: "Dock", title: "Mostrar apps recentes no Dock",
                     help: "Exibe a seção de aplicativos usados recentemente",
                     domain: "com.apple.dock", key: "show-recents", restart: .dock, defaultOn: true),
        SystemToggle(id: "minimizetoapp", section: "Dock", title: "Minimizar janelas no ícone do app",
                     help: "Janelas minimizadas voltam para o ícone do próprio app",
                     domain: "com.apple.dock", key: "minimize-to-application", restart: .dock),
        SystemToggle(id: "autospaces", section: "Dock", title: "Reorganizar Espaços por uso",
                     help: "O macOS reordena as áreas de trabalho pelo uso mais recente",
                     domain: "com.apple.dock", key: "mru-spaces", restart: .dock, defaultOn: true),

        // Teclado e texto
        SystemToggle(id: "autocorrect", section: "Teclado e texto", title: "Correção ortográfica automática",
                     help: "Corrige palavras automaticamente enquanto você digita",
                     domain: "NSGlobalDomain", key: "NSAutomaticSpellingCorrectionEnabled", defaultOn: true),
        SystemToggle(id: "smartquotes", section: "Teclado e texto", title: "Aspas curvas (inteligentes)",
                     help: "Substitui aspas retas por aspas tipográficas",
                     domain: "NSGlobalDomain", key: "NSAutomaticQuoteSubstitutionEnabled", defaultOn: true),
        SystemToggle(id: "smartdashes", section: "Teclado e texto", title: "Travessões inteligentes",
                     help: "Substitui dois hífens por travessão",
                     domain: "NSGlobalDomain", key: "NSAutomaticDashSubstitutionEnabled", defaultOn: true),

        // Capturas de tela
        SystemToggle(id: "screenshadow", section: "Capturas de tela", title: "Sombra em capturas de janela",
                     help: "Inclui a sombra ao capturar uma janela",
                     domain: "com.apple.screencapture", key: "disable-shadow",
                     restart: .systemUIServer, inverted: true),
        SystemToggle(id: "screendate", section: "Capturas de tela", title: "Incluir data no nome do arquivo",
                     help: "Adiciona data e hora ao nome das capturas",
                     domain: "com.apple.screencapture", key: "include-date",
                     restart: .systemUIServer, defaultOn: true),
    ]

    /// Seções na ordem em que aparecem.
    static var toggleSections: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for toggle in toggles where seen.insert(toggle.section).inserted {
            result.append(toggle.section)
        }
        return result
    }

    // MARK: Informações

    func loadInfo() async {
        loadingInfo = true
        defer { loadingInfo = false }

        var result = MacInfo()
        let pi = ProcessInfo.processInfo

        result.cores = pi.processorCount
        result.memory = ByteCountFormatter.string(fromByteCount: Int64(pi.physicalMemory), countStyle: .memory)
        result.osVersion = "macOS " + pi.operatingSystemVersionString
            .replacingOccurrences(of: "Version ", with: "")
        result.uptime = Self.formatUptime(pi.systemUptime)

        result.chip = await sysctl("machdep.cpu.brand_string")
        result.model = await sysctl("hw.model")

        let home = URL(fileURLWithPath: NSHomeDirectory())
        if let values = try? home.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey
        ]) {
            if let free = values.volumeAvailableCapacityForImportantUsage {
                result.diskFree = ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
            }
            if let total = values.volumeTotalCapacity {
                result.diskTotal = ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
            }
        }

        result.batteryCycles = await batteryCycles()
        info = result
    }

    private func sysctl(_ key: String) async -> String {
        let out = await Shell.capture("/usr/sbin/sysctl", ["-n", key])
        let trimmed = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    private func batteryCycles() async -> String {
        let out = await Shell.capture("/usr/sbin/ioreg", ["-r", "-c", "AppleSmartBattery"])
        for line in out.stdout.split(whereSeparator: \.isNewline) where line.contains("\"CycleCount\"") {
            if let value = line.split(separator: "=").last?.trimmingCharacters(in: .whitespaces) {
                return value
            }
        }
        return "—"  // Macs de mesa não têm bateria
    }

    // MARK: Itens de inicialização

    func loadLoginItems() async {
        loadingLogin = true
        defer { loadingLogin = false }
        loginItemsError = nil

        let script = "tell application \"System Events\" to get the name of every login item"
        let out = await Shell.capture("/usr/bin/osascript", ["-e", script])

        if !out.ok {
            loginItems = []
            loginItemsError = "Não foi possível ler os itens de inicialização. Pode ser necessário conceder permissão de Automação (Ajustes do Sistema > Privacidade e Segurança > Automação)."
            return
        }
        loginItems = out.stdout
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func removeLoginItem(_ name: String) async {
        guard InputValidator.isSafeAppleScriptText(name) else { return }
        let script = "tell application \"System Events\" to delete login item \"\(name)\""
        _ = await Shell.capture("/usr/bin/osascript", ["-e", script])
        await loadLoginItems()
    }

    // MARK: Ajustes rápidos

    func loadToggleStates() async {
        for toggle in Self.toggles {
            toggleStates[toggle.id] = await readState(toggle)
        }
    }

    /// Lê o estado exibido na UI (aplicando padrão do macOS quando a chave não existe e a inversão).
    private func readState(_ toggle: SystemToggle) async -> Bool {
        let out = await Shell.capture("/usr/bin/defaults", ["read", toggle.domain, toggle.key])
        let raw: Bool
        if !out.ok {
            raw = toggle.defaultOn          // chave ainda não definida
        } else {
            let value = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            raw = value == "1" || value == "true" || value == "yes"
        }
        return toggle.inverted ? !raw : raw
    }

    func setToggle(_ toggle: SystemToggle, on: Bool) async {
        let rawValue = toggle.inverted ? !on : on
        _ = await Shell.capture("/usr/bin/defaults",
                                ["write", toggle.domain, toggle.key, "-bool", rawValue ? "true" : "false"])
        if toggle.restart != .none {
            _ = await Shell.capture("/usr/bin/killall", [toggle.restart.rawValue])
        }
        toggleStates[toggle.id] = on
    }

    // MARK: Utilidades

    nonisolated static func formatUptime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)min" }
        return "\(minutes)min"
    }
}
