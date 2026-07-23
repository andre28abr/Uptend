import Foundation

// =============================================================================
// MARCA DO RELATÓRIO (white-label) — FASE A1
// Dados de marca/engajamento para a capa dos relatórios: empresa auditora,
// auditor, cliente, nº do relatório, aviso de confidencialidade e logo (data-URI,
// autocontido). Struct pura → guardada pelo app e injetada nos relatórios.
// =============================================================================

public struct ReportBranding: Codable, Equatable, Sendable {
    public var company: String          // empresa/consultoria auditora
    public var auditor: String          // nome do auditor
    public var auditorTitle: String     // cargo/credencial (ex.: "CISSP · Analista de Segurança")
    public var contact: String          // e-mail/telefone
    public var client: String           // empresa/cliente auditado
    public var reportNumber: String     // nº/versão do relatório
    public var confidentiality: String  // aviso de confidencialidade (editável)
    public var logoDataURI: String?     // "data:image/png;base64,…"

    public init(company: String = "", auditor: String = "", auditorTitle: String = "",
                contact: String = "", client: String = "", reportNumber: String = "",
                confidentiality: String = "", logoDataURI: String? = nil) {
        self.company = company; self.auditor = auditor; self.auditorTitle = auditorTitle
        self.contact = contact; self.client = client; self.reportNumber = reportNumber
        self.confidentiality = confidentiality; self.logoDataURI = logoDataURI
    }

    /// Tem informação suficiente para valer a pena renderizar a capa/marca?
    public var isConfigured: Bool {
        !company.isEmpty || !auditor.isEmpty || !client.isEmpty || logoDataURI != nil
    }
}
