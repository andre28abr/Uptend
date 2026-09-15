import Testing
import Foundation
@testable import UptendCore

struct AuditDashboardTests {

    private func loadFixture() throws -> ExternalAudit {
        let url = try #require(Bundle.module.url(forResource: "lab-audit", withExtension: "json", subdirectory: "Fixtures"))
        return try ExternalAuditParser.parse(Data(contentsOf: url))
    }

    @Test func dashboardIsSelfContained() throws {
        let audit = try loadFixture()
        let html = AuditDashboard.html([audit, audit])
        #expect(html.hasPrefix("<!DOCTYPE html>"))
        #expect(html.contains("const DATA ="))
        #expect(html.contains("<svg") || html.contains("function lineChart"))
        #expect(html.contains("uptend-lab"))
        // Offline: sem recurso externo, sem CDN.
        #expect(html.contains("http://") == false)
        #expect(html.contains("https://") == false)
        #expect(html.contains("cdn") == false)
    }

    @Test func embedsValidJSONData() throws {
        let audit = try loadFixture()
        let html = AuditDashboard.html([audit])
        // Extrai o array embutido em `const DATA = [...]` e valida como JSON.
        guard let r = html.range(of: "const DATA = "),
              let end = html.range(of: ";\n", range: r.upperBound..<html.endIndex) else {
            Issue.record("não achei o bloco DATA"); return
        }
        let json = String(html[r.upperBound..<end.lowerBound])
        let obj = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]]
        #expect(obj?.count == 1)
        #expect(obj?.first?["host"] as? String == "uptend-lab")
        #expect(obj?.first?["score"] is Int)
    }

    @Test func escapesScriptCloserInData() {
        // Regressão: um dado contendo "</script>" encerrava o bloco <script> do
        // dashboard e injetava HTML/JS vivo na página (o esc() do JS roda tarde
        // demais — o parser de HTML age antes).
        let evil = ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "admin"),
            collectedAt: "2026-07-22T00:00:00Z",
            host: .init(hostname: "srv</script><script>alert(1)", machineId: nil),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: [], lynis: nil)
        let html = AuditDashboard.html([evil])
        #expect(html.contains("</script><script>alert(1)") == false)
    }

    @Test func handlesEmptyHistory() {
        let html = AuditDashboard.html([])
        #expect(html.contains("const DATA = []"))
        #expect(html.hasPrefix("<!DOCTYPE html>"))
    }
}
