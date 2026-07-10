import Foundation

/// Lê o estado de segurança do Mac (somente leitura, sem sudo).
@MainActor
final class SecurityService: ObservableObject {
    @Published var checks: [SecurityCheck] = []
    @Published var loading = false

    @Published var updates: SecurityCheck?
    @Published var checkingUpdates = false

    func refresh() async {
        loading = true
        defer { loading = false }

        var result: [SecurityCheck] = []

        let fv = await Shell.capture("/usr/bin/fdesetup", ["status"])
        result.append(make("FileVault", Self.interpretFileVault(fv.stdout)))

        let fw = await Shell.capture("/usr/libexec/ApplicationFirewall/socketfilterfw", ["--getglobalstate"])
        result.append(make("Firewall", Self.interpretFirewall(fw.stdout)))

        let gk = await Shell.capture("/usr/sbin/spctl", ["--status"])
        result.append(make("Gatekeeper", Self.interpretGatekeeper(gk.stdout + gk.stderr)))

        let sip = await Shell.capture("/usr/bin/csrutil", ["status"])
        result.append(make("Proteção de integridade (SIP)", Self.interpretSIP(sip.stdout)))

        checks = result
    }

    /// Checagem de atualizações do sistema — lenta (consulta a Apple), então é sob demanda.
    func checkUpdates() async {
        checkingUpdates = true
        defer { checkingUpdates = false }
        let out = await Shell.capture("/usr/sbin/softwareupdate", ["-l"])
        updates = Self.interpretUpdates(out.stdout + out.stderr)
    }

    private func make(_ name: String, _ pair: (String, CheckStatus)) -> SecurityCheck {
        SecurityCheck(name: name, detail: pair.0, status: pair.1)
    }

    // MARK: - Interpretação (pura, testável)

    nonisolated static func interpretFileVault(_ output: String) -> (String, CheckStatus) {
        output.localizedCaseInsensitiveContains("On")
            ? ("Criptografia de disco ativa", .ok)
            : ("Desativado — recomendado ativar", .warning)
    }

    nonisolated static func interpretFirewall(_ output: String) -> (String, CheckStatus) {
        let disabled = output.contains("State = 0") || output.localizedCaseInsensitiveContains("disabled")
        return disabled ? ("Desativado — recomendado ativar", .warning) : ("Ativo", .ok)
    }

    nonisolated static func interpretGatekeeper(_ output: String) -> (String, CheckStatus) {
        output.localizedCaseInsensitiveContains("assessments enabled")
            ? ("Apps verificados", .ok)
            : ("Desativado — recomendado ativar", .warning)
    }

    nonisolated static func interpretSIP(_ output: String) -> (String, CheckStatus) {
        output.localizedCaseInsensitiveContains("enabled")
            ? ("Ativa", .ok)
            : ("Desativada — recomendado ativar", .warning)
    }

    nonisolated static func interpretUpdates(_ output: String) -> SecurityCheck {
        if output.localizedCaseInsensitiveContains("No new software") {
            return SecurityCheck(name: "Atualizações do sistema", detail: "Nenhuma pendente", status: .ok)
        }
        let count = output.split(whereSeparator: \.isNewline).filter { $0.contains("* Label:") }.count
        if count > 0 {
            return SecurityCheck(name: "Atualizações do sistema", detail: "\(count) pendente(s)", status: .warning)
        }
        return SecurityCheck(name: "Atualizações do sistema", detail: "Verifique nos Ajustes do Sistema", status: .warning)
    }
}
