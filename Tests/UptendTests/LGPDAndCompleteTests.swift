import Testing
import Foundation
@testable import UptendCore

struct LGPDLensTests {
    private func f(_ id: String, _ sev: AuditSeverity, _ cat: String) -> AuditFinding {
        AuditFinding(id: id, title: id, severity: sev, category: cat, recommendation: "x")
    }
    private func audit(_ fs: [AuditFinding]) -> ExternalAudit {
        ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "admin"),
            collectedAt: "2026-07-22T00:00:00Z", host: .init(hostname: "h", machineId: nil),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: fs, lynis: nil)
    }

    @Test func mapsRelevantFindingsAndIgnoresOthers() {
        let a = audit([
            f("db-pii-strong-clientes-cpf", .high, "Banco de dados"),
            f("firewall-inactive", .high, "Segurança / Rede"),
            f("logs-persistent", .low, "Segurança / Logs"),
            f("disk-smart", .high, "Discos & resiliência"),   // NÃO é LGPD
        ])
        let items = LGPDLens.items(a)
        let ids = Set(items.map { $0.finding.id })
        #expect(ids.contains("db-pii-strong-clientes-cpf"))
        #expect(ids.contains("firewall-inactive"))
        #expect(ids.contains("logs-persistent"))
        #expect(ids.contains("disk-smart") == false)         // disco fora do escopo LGPD
        // banco de PII → artigo de segurança de dados pessoais
        #expect(items.first { $0.finding.id.contains("cpf") }?.article.code.contains("46") == true)
    }

    @Test func reportIsSelfContained() {
        let a = audit([f("db-password-plaintext-u-senha", .high, "Banco de dados")])
        let html = AuditReport.lgpdHTML(a)
        #expect(html.contains("Relatório LGPD"))
        #expect(html.contains("não é parecer jurídico"))
        #expect(html.contains("http://") == false && html.contains("https://") == false)
    }
}

struct DatabaseCompleteModeTests {
    private func col(_ n: String, _ t: String) -> DBColumn { DBColumn(name: n, type: t) }

    @Test func hashDetection() {
        #expect(DatabaseAudit.valuesLookHashed(["$2b$12$abcdefghijklmnopqrstuv", "$2y$10$zzzzzzzzzzzzzzzzzzzzzz"]))
        #expect(DatabaseAudit.valuesLookHashed(["5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8"]))  // sha256 hex
        #expect(DatabaseAudit.valuesLookHashed(["123456", "senha", "abc"]) == false)  // texto plano
    }

    @Test func completeModeClearsHashedPassword() {
        let schema = DatabaseSchema(engine: "SQLite", name: "d", tables: [
            DBTable(name: "usuarios", columns: [col("id", "INTEGER"), col("senha", "TEXT")])])
        // schema-only: sinaliza (possível texto plano)
        #expect(DatabaseAudit.findings(from: schema).contains { $0.id.hasPrefix("db-password-plaintext") })
        // completo + amostra com hash: NÃO sinaliza
        let hashed = ["usuarios.senha": ["$2b$12$abcdefghijklmnopqrstuv"]]
        #expect(DatabaseAudit.findings(from: schema, passwordSamples: hashed).contains { $0.id.hasPrefix("db-password-plaintext") } == false)
        // completo + amostra em texto plano: CONFIRMA
        let plain = ["usuarios.senha": ["123456", "abcdef"]]
        let f = DatabaseAudit.findings(from: schema, passwordSamples: plain).first { $0.id.hasPrefix("db-password-plaintext") }
        #expect(f?.title.contains("CONFIRMADA") == true)
    }
}
