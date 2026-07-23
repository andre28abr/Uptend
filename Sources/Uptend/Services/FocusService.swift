import Foundation
import AppKit

/// Modo foco: limpa a mesa (oculta os ícones da Mesa) e oculta o Dock automaticamente.
/// Tudo reversível via `defaults`. O silêncio de notificações (Foco do macOS) é aberto
/// nos Ajustes, pois o macOS não permite alterná-lo por linha de comando de forma confiável.
@MainActor
final class FocusService: ObservableObject {
    @Published var enabled: Bool

    private let key = "uptend.focusEnabled"

    init() {
        enabled = UserDefaults.standard.bool(forKey: key)
    }

    func setEnabled(_ on: Bool) async {
        // Ícones da Mesa (CreateDesktop = false esconde).
        _ = await Shell.capture("/usr/bin/defaults", ["write", "com.apple.finder", "CreateDesktop", "-bool", on ? "false" : "true"])
        _ = await Shell.capture("/usr/bin/killall", ["Finder"])
        // Dock automático.
        _ = await Shell.capture("/usr/bin/defaults", ["write", "com.apple.dock", "autohide", "-bool", on ? "true" : "false"])
        _ = await Shell.capture("/usr/bin/killall", ["Dock"])

        enabled = on
        UserDefaults.standard.set(on, forKey: key)
        ActionLog.shared.record(on ? "Modo foco ativado" : "Modo foco desativado")
    }

    func openFocusSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
