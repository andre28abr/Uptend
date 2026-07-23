import Testing
import Foundation
@testable import UptendCore

struct BrandingTests {

    private func loadFixture() throws -> ExternalAudit {
        let url = try #require(Bundle.module.url(forResource: "lab-audit", withExtension: "json", subdirectory: "Fixtures"))
        return try ExternalAuditParser.parse(Data(contentsOf: url))
    }

    @Test func brandingAppearsInReports() throws {
        let audit = try loadFixture()
        let b = ReportBranding(company: "Acme Security", auditor: "André Souza",
                               auditorTitle: "CISSP", contact: "andre@acme.com",
                               client: "Contoso Ltda", reportNumber: "AUD-2026-014",
                               confidentiality: "CONFIDENCIAL — Contoso", logoDataURI: nil)
        for html in [AuditReport.executiveHTML(audit, branding: b),
                     AuditReport.socHTML(audit, branding: b),
                     AuditReport.html(audit, branding: b)] {
            #expect(html.contains("Acme Security"))
            #expect(html.contains("Contoso Ltda"))
            #expect(html.contains("AUD-2026-014"))
            #expect(html.contains("CONFIDENCIAL — Contoso"))   // aviso customizado
        }
        let md = AuditReport.markdown(audit, branding: b)
        #expect(md.contains("Cliente:** Contoso Ltda"))
    }

    @Test func noBrandingKeepsDefaultLayout() throws {
        let audit = try loadFixture()
        let html = AuditReport.executiveHTML(audit)   // sem marca
        #expect(html.contains("class='cover'") == false)                       // sem capa de marca
        #expect(html.contains("CONFIDENCIAL · Uso interno"))                   // aviso padrão
    }

    @Test func brandingConfiguredFlag() {
        #expect(ReportBranding().isConfigured == false)
        #expect(ReportBranding(company: "X").isConfigured == true)
        #expect(ReportBranding(client: "Y").isConfigured == true)
    }

    @Test func escapesBrandingText() throws {
        let audit = try loadFixture()
        let b = ReportBranding(company: "<b>Evil</b>", client: "\"aspas\"")
        let html = AuditReport.executiveHTML(audit, branding: b)
        #expect(html.contains("<b>Evil</b>") == false)
        #expect(html.contains("&lt;b&gt;Evil&lt;/b&gt;"))
    }
}
