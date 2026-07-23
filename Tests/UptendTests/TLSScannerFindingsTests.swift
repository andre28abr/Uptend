import Testing
import Foundation
@testable import Uptend
@testable import UptendCore

@MainActor
struct TLSScannerFindingsTests {

    private func probe(_ port: Int, reachable: Bool, tls: Bool, issues: [String] = [], legacy: Bool = false) -> TLSProbeResult {
        var r = TLSProbeResult(host: "h", port: port)
        r.reachable = reachable; r.speaksTLS = tls; r.issues = issues; r.acceptsLegacy = legacy
        if tls { r.tlsVersion = "TLS 1.2" }
        return r
    }

    @Test func convertsProbesToFindings() {
        let good = probe(443, reachable: true, tls: true)
        let weak = probe(8443, reachable: true, tls: true, issues: ["Aceita TLS 1.0/1.1 (obsoleto)"], legacy: true)
        let plainExpected = probe(993, reachable: true, tls: false)   // IMAPS deveria ter TLS
        let closed = probe(9999, reachable: false, tls: false)

        let f = TLSScanner.findings(from: [good, weak, plainExpected, closed])
        #expect(f.count == 3)   // porta fechada não vira achado
        #expect(f.first { $0.id == "tls-scan-443" }?.severity == .ok)
        #expect(f.first { $0.id == "tls-scan-8443" }?.severity == .high)   // aceita legado
        #expect(f.first { $0.id == "tls-scan-993" }?.severity == .medium)  // sem TLS onde se espera
        // Mapeia aos frameworks (tls-scan-* → tls-config).
        #expect(ComplianceMap.refs(for: f.first { $0.id == "tls-scan-8443" }!).owasp == "A02:2021")
    }

    @Test func mergeIntoAuditUpdatesScoreAndReplaces() {
        let svc = ExternalAuditService(vault: .inMemory())
        let json = Data("""
        {"schema_version":1,"collector":{"name":"x","version":"1","mode":"user"},
         "collected_at":"2026-07-21T00:00:00Z","host":{"hostname":"srv","machine_id":null},
         "machine":null,"os":null,"disks":[],
         "findings":[{"id":"firewall-inactive","title":"fw","severity":"high","category":"Rede","cis":null,"evidence":null,"recommendation":null,"business_impact":null}],
         "lynis":null}
        """.utf8)
        #expect(svc.ingest(json, suggestedName: "srv"))
        let before = svc.selected!.score.score   // 90
        let scan = [AuditFinding(id: "tls-scan-443", title: "weak", severity: .high, category: "Segurança / TLS")]
        #expect(svc.mergeScanFindings(scan, into: svc.selected!))
        #expect(svc.audits.count == 1)            // substituiu o registro, não duplicou
        #expect(svc.selected!.audit.findings.contains { $0.id == "tls-scan-443" })
        #expect(svc.selected!.score.score == before - 10)
        // re-scan não acumula
        #expect(svc.mergeScanFindings([AuditFinding(id: "tls-scan-443", title: "w2", severity: .medium, category: "Segurança / TLS")], into: svc.selected!))
        #expect(svc.selected!.audit.findings.filter { $0.id == "tls-scan-443" }.count == 1)
    }
}
