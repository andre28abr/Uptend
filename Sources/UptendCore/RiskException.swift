import Foundation

// =============================================================================
// ACEITAÇÃO DE RISCO / EXCEÇÕES (risk acceptance) — FASE B2
// Permite marcar um achado como "risco aceito" (com justificativa, responsável e
// data de validade). Enquanto a exceção está válida, o achado SAI da nota e da
// matriz — mas fica REGISTRADO e auditável, e VOLTA a contar quando a validade
// expira. Mecanismo padrão de GRC (exceção formal com dono e prazo).
// Lógica pura → testável. Datas em ISO "yyyy-MM-dd" (comparação lexicográfica =
// cronológica), sem depender de fuso/locale.
// =============================================================================

public struct RiskException: Codable, Equatable, Sendable, Identifiable {
    public let findingId: String       // id do achado aceito (chave)
    public let title: String           // título do achado no momento da aceitação (registro)
    public let justification: String   // por que o risco é aceito
    public let responsible: String     // quem aceitou (dono do risco)
    public let acceptedAt: String      // "yyyy-MM-dd" — quando foi aceito
    public let expiresAt: String       // "yyyy-MM-dd" — até quando vale (revisão obrigatória)
    public let reference: String       // opcional: ticket/chamado/documento ("" se vazio)

    public var id: String { findingId }

    public init(findingId: String, title: String, justification: String, responsible: String,
                acceptedAt: String, expiresAt: String, reference: String = "") {
        self.findingId = findingId
        self.title = title
        self.justification = justification
        self.responsible = responsible
        self.acceptedAt = acceptedAt
        self.expiresAt = expiresAt
        self.reference = reference
    }

    /// Válida se HOJE está na janela [aceitação, expiração] — inclusive os limites.
    /// Normaliza para "yyyy-MM-dd" (prefixo) para que um `today` com hora (timestamp
    /// ISO completo) não faça a exceção parecer expirar um dia antes; e considera o
    /// `acceptedAt` (uma aceitação com início futuro só passa a valer na data marcada).
    public func isActive(asOf today: String) -> Bool {
        let t = String(today.prefix(10))
        return String(acceptedAt.prefix(10)) <= t && t <= String(expiresAt.prefix(10))
    }

    /// Dias restantes até expirar (negativo se já expirou); nil se datas inválidas.
    public func daysRemaining(asOf today: String) -> Int? {
        guard let a = RiskException.day(today), let b = RiskException.day(expiresAt) else { return nil }
        return Calendar(identifier: .gregorian).dateComponents([.day], from: a, to: b).day
    }

    private static func day(_ s: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(s.prefix(10)))
    }
}

public enum RiskExceptions {

    /// Ids dos achados com exceção VÁLIDA na data informada.
    public static func activeIDs(_ exceptions: [RiskException], today: String) -> Set<String> {
        Set(exceptions.filter { $0.isActive(asOf: today) }.map(\.findingId))
    }

    /// Auditoria "efetiva": remove os achados com exceção válida (saem da nota e da matriz).
    /// Exceções expiradas NÃO removem nada — o achado volta a contar automaticamente.
    public static func effective(_ audit: ExternalAudit, exceptions: [RiskException], today: String) -> ExternalAudit {
        let ids = activeIDs(exceptions, today: today)
        guard !ids.isEmpty else { return audit }
        return audit.replacingFindings(audit.findings.filter { !ids.contains($0.id) })
    }

    /// Exceções válidas que correspondem a um achado ainda existente (para exibir/registrar),
    /// ordenadas por validade mais próxima primeiro.
    public static func accepted(_ audit: ExternalAudit, exceptions: [RiskException], today: String) -> [RiskException] {
        let existing = Set(audit.findings.map(\.id))
        return exceptions
            .filter { $0.isActive(asOf: today) && existing.contains($0.findingId) }
            .sorted { $0.expiresAt < $1.expiresAt }
    }

    /// Exceções que já expiraram mas ainda correspondem a um achado aberto (precisam de revisão).
    public static func expired(_ audit: ExternalAudit, exceptions: [RiskException], today: String) -> [RiskException] {
        let openIDs = Set(audit.findings.filter { $0.severity > .ok }.map(\.id))
        return exceptions
            .filter { !$0.isActive(asOf: today) && openIDs.contains($0.findingId) }
            .sorted { $0.expiresAt < $1.expiresAt }
    }
}
