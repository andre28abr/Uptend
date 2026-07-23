import Testing
import Foundation
@testable import UptendCore

/// Dataset CSV para BI (Metabase/Power BI).
struct AuditDatasetTests {

    private func loadFixture() throws -> ExternalAudit {
        let url = try #require(Bundle.module.url(forResource: "lab-audit", withExtension: "json", subdirectory: "Fixtures"))
        return try ExternalAuditParser.parse(Data(contentsOf: url))
    }

    @Test func summaryCSVHasHeaderAndOneRowPerAudit() throws {
        let audit = try loadFixture()
        let csv = AuditDataset.summaryCSV([audit, audit])
        let lines = csv.split(separator: "\n")
        #expect(lines.first?.hasPrefix("host,coletado_em,modo,nota") == true)
        #expect(lines.count == 3)                      // cabeçalho + 2 auditorias
        #expect(csv.contains("uptend-lab"))
    }

    @Test func findingsCSVHasOneRowPerFinding() throws {
        let audit = try loadFixture()
        let csv = AuditDataset.findingsCSV([audit])
        let lines = csv.split(separator: "\n")
        #expect(lines.first?.hasPrefix("host,coletado_em,nota,achado_id") == true)
        #expect(lines.count == audit.findings.count + 1)   // cabeçalho + achados
    }

    @Test func csvEscapesCommasAndQuotes() {
        let audit = ExternalAudit(
            schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "user"),
            collectedAt: "2026-07-17T00:00:00Z", host: .init(hostname: "srv", machineId: nil),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: [.init(id: "x", title: "porta 80, 443 e \"outras\"", severity: .high, category: "Rede")],
            lynis: nil)
        let csv = AuditDataset.findingsCSV([audit])
        // Título com vírgula/aspas fica entre aspas e com aspas duplicadas.
        #expect(csv.contains("\"porta 80, 443 e \"\"outras\"\"\""))
    }

    @Test func handlesEmptyList() {
        let csv = AuditDataset.summaryCSV([])
        #expect(csv.split(separator: "\n").count == 1)   // só o cabeçalho
    }
}
