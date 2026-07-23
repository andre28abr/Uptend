import SwiftUI
import Foundation
import UptendCore

// =============================================================================
// ACEITAÇÃO DE RISCO — armazenamento no app (FASE B2)
// Guarda as exceções por HOST (chave = machineId ?? hostname) em UserDefaults.
// Persistente e auditável: cada aceitação tem justificativa, responsável e prazo.
// =============================================================================

@MainActor
final class RiskExceptionStore: ObservableObject {
    /// hostKey → lista de exceções.
    @Published private var byHost: [String: [RiskException]] { didSet { save() } }

    private let key = "uptend.riskExceptions"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let m = try? JSONDecoder().decode([String: [RiskException]].self, from: data) {
            byHost = m
        } else {
            byHost = [:]
        }
    }

    /// Chave estável do host (prefere o machineId; cai para hostname).
    static func hostKey(_ audit: ExternalAudit) -> String {
        let mid = audit.host.machineId ?? ""
        return mid.isEmpty ? audit.host.hostname : mid
    }

    func exceptions(for audit: ExternalAudit) -> [RiskException] {
        byHost[Self.hostKey(audit)] ?? []
    }

    /// Data de hoje em "yyyy-MM-dd" (para avaliar a vigência das exceções por prazo).
    static func todayString() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// A auditoria com os riscos formalmente aceitos (vigentes) descontados.
    func effective(_ audit: ExternalAudit) -> ExternalAudit {
        RiskExceptions.effective(audit, exceptions: exceptions(for: audit), today: Self.todayString())
    }

    /// Nota do host DEPOIS de descontar os riscos aceitos — a MESMA dos relatórios,
    /// para o painel/cartões/histórico não mostrarem uma nota divergente (M3).
    func effectiveScore(_ audit: ExternalAudit) -> AuditScore {
        AuditScoring.evaluate(effective(audit))
    }

    func isAccepted(_ findingId: String, in audit: ExternalAudit) -> Bool {
        exceptions(for: audit).contains { $0.findingId == findingId }
    }

    /// Adiciona/atualiza a exceção de um achado (substitui se já existir).
    func accept(_ exception: RiskException, in audit: ExternalAudit) {
        let k = Self.hostKey(audit)
        var list = byHost[k] ?? []
        list.removeAll { $0.findingId == exception.findingId }
        list.append(exception)
        byHost[k] = list
    }

    /// Revoga a aceitação de um achado (o risco volta a contar imediatamente).
    func revoke(_ findingId: String, in audit: ExternalAudit) {
        let k = Self.hostKey(audit)
        byHost[k]?.removeAll { $0.findingId == findingId }
        if byHost[k]?.isEmpty == true { byHost[k] = nil }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(byHost) { defaults.set(data, forKey: key) }
    }
}
