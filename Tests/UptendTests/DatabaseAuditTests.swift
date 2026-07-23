import Testing
import Foundation
@testable import UptendCore

struct DatabaseAuditTests {

    private func col(_ n: String, _ t: String, pk: Bool = false) -> DBColumn {
        DBColumn(name: n, type: t, notNull: false, primaryKey: pk)
    }

    @Test func passwordPlaintextIsHigh() {
        let schema = DatabaseSchema(engine: "SQLite", name: "app.db", tables: [
            DBTable(name: "usuarios", columns: [col("id", "INTEGER", pk: true), col("senha", "VARCHAR(255)")])
        ])
        let f = DatabaseAudit.findings(from: schema)
        let pw = f.first { $0.id.hasPrefix("db-password-plaintext") }
        #expect(pw?.severity == .high)
        #expect(pw?.category == "Banco de dados")
    }

    @Test func hashedPasswordNotFlagged() {
        let schema = DatabaseSchema(engine: "SQLite", name: "app.db", tables: [
            DBTable(name: "usuarios", columns: [col("id", "INTEGER", pk: true), col("senha_hash", "TEXT")])
        ])
        let f = DatabaseAudit.findings(from: schema)
        #expect(f.contains { $0.id.hasPrefix("db-password-plaintext") } == false)
    }

    @Test func strongPIIInTextIsHigh_numericIsNot() {
        let s1 = DatabaseSchema(engine: "SQLite", name: "d", tables: [
            DBTable(name: "clientes", columns: [col("id", "INTEGER", pk: true), col("cpf", "TEXT")])])
        #expect(DatabaseAudit.findings(from: s1).contains { $0.id.hasPrefix("db-pii-strong") && $0.severity == .high })
        // cpf como BLOB (não texto) não dispara "texto plano"
        let s2 = DatabaseSchema(engine: "SQLite", name: "d", tables: [
            DBTable(name: "clientes", columns: [col("id", "INTEGER", pk: true), col("cpf", "BLOB")])])
        #expect(DatabaseAudit.findings(from: s2).contains { $0.id.hasPrefix("db-pii") } == false)
    }

    @Test func commonPIIIsMedium() {
        let schema = DatabaseSchema(engine: "SQLite", name: "d", tables: [
            DBTable(name: "clientes", columns: [col("id", "INTEGER", pk: true), col("email", "VARCHAR(255)")])])
        #expect(DatabaseAudit.findings(from: schema).contains { $0.id.hasPrefix("db-pii-") && $0.severity == .medium })
    }

    @Test func noPrimaryKeyFlagged() {
        let schema = DatabaseSchema(engine: "SQLite", name: "d", tables: [
            DBTable(name: "logs", columns: [col("msg", "TEXT")])])
        #expect(DatabaseAudit.findings(from: schema).contains { $0.id == "db-no-pk-logs" })
    }

    @Test func fkWithoutIndexFlagged() {
        let schema = DatabaseSchema(engine: "SQLite", name: "d", tables: [
            DBTable(name: "pedidos", columns: [col("id", "INTEGER", pk: true), col("cliente_id", "INTEGER")],
                    foreignKeyColumns: ["cliente_id"], indexedColumns: [])])
        #expect(DatabaseAudit.findings(from: schema).contains { $0.id == "db-fk-no-index-pedidos-cliente_id" })
    }

    @Test func cleanSchemaGivesOk() {
        let schema = DatabaseSchema(engine: "SQLite", name: "d", tables: [
            DBTable(name: "config", columns: [col("chave", "TEXT", pk: true), col("valor", "TEXT")])])
        let f = DatabaseAudit.findings(from: schema)
        #expect(f.count == 1 && f.first?.severity == .ok)
    }

    @Test func enrichAppendsDatabaseFindingsFromCollector() {
        // Auditoria de servidor que trouxe schema de banco (via coletor) — sem achados de BD ainda.
        let schema = DatabaseSchema(engine: "PostgreSQL", name: "loja", tables: [
            DBTable(name: "usuarios", columns: [col("id", "integer", pk: true), col("senha", "text"), col("cpf", "text")])])
        let base = ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "admin"),
            collectedAt: "2026-07-22T00:00:00Z", host: .init(hostname: "srv", machineId: "m1"),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: [AuditFinding(id: "firewall-inactive", title: "fw", severity: .high, category: "Rede")], lynis: nil, databases: [schema])
        let e = base.enrichedWithDatabaseFindings()
        #expect(e.findings.contains { $0.id.hasPrefix("db-password-plaintext") })
        #expect(e.findings.contains { $0.id.hasPrefix("db-pii-strong") })
        #expect(e.findings.contains { $0.id == "firewall-inactive" })   // preserva os do sistema
        // idempotente — não duplica
        #expect(e.enrichedWithDatabaseFindings().findings.count == e.findings.count)
    }

    @Test func makeAuditBecomesScorableTarget() {
        let schema = DatabaseSchema(engine: "SQLite", name: "app.db", tables: [
            DBTable(name: "usuarios", columns: [col("senha", "TEXT")])])
        let audit = DatabaseAudit.makeAudit(from: schema, collectedAt: "2026-07-22T00:00:00Z")
        #expect(audit.host.hostname == "BD: app.db")
        let score = AuditScoring.evaluate(audit)
        #expect(score.score < 100)   // achado alto derruba a nota
        #expect(AuditDomains.scores(audit).contains { $0.name == "Banco de dados" })
    }
}
