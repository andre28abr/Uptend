import Testing
import Foundation
@testable import Uptend
@testable import UptendCore

/// Serviço de ingestão da Auditoria Externa — agora sobre o banco central (UptendVault).
/// Usa um banco em memória/temporário (não toca no banco real do app).
@MainActor
struct ExternalAuditServiceTests {

    private func tempDBURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("uptend-vault-test-\(UUID().uuidString).sqlite")
    }

    private var sampleJSON: Data {
        Data("""
        {
          "schema_version": 1,
          "collector": {"name": "uptend-audit", "version": "1.0.0", "mode": "user"},
          "collected_at": "2026-07-17T03:00:00Z",
          "host": {"hostname": "srv-teste", "machine_id": "abc"},
          "machine": null, "os": null, "disks": [],
          "findings": [
            {"id": "firewall-inactive", "title": "Firewall inativo", "severity": "high",
             "category": "Rede", "cis": null, "evidence": null, "recommendation": null, "business_impact": null}
          ],
          "lynis": null
        }
        """.utf8)
    }

    @Test func ingestStoresAndSelects() {
        let svc = ExternalAuditService(vault: .inMemory())
        #expect(svc.audits.isEmpty)
        #expect(svc.ingest(sampleJSON, suggestedName: "x"))
        #expect(svc.audits.count == 1)
        #expect(svc.selected?.hostname == "srv-teste")
        #expect(svc.selected?.score.score == 90)      // 100 − high(10)
    }

    @Test func ingestDeduplicatesByContent() {
        let svc = ExternalAuditService(vault: .inMemory())
        #expect(svc.ingest(sampleJSON, suggestedName: "x"))
        #expect(svc.ingest(sampleJSON, suggestedName: "x"))   // mesmo conteúdo
        #expect(svc.audits.count == 1)                        // não duplica
    }

    @Test func ingestRejectsGarbage() {
        let svc = ExternalAuditService(vault: .inMemory())
        #expect(svc.ingest(Data("lixo".utf8), suggestedName: "x") == false)
        #expect(svc.lastError != nil)
        #expect(svc.audits.isEmpty)
    }

    @Test func ingestRejectsNewerSchema() {
        let svc = ExternalAuditService(vault: .inMemory())
        let newer = String(decoding: sampleJSON, as: UTF8.self)
            .replacingOccurrences(of: "\"schema_version\": 1", with: "\"schema_version\": 999")
        #expect(svc.ingest(Data(newer.utf8), suggestedName: "x") == false)
        #expect(svc.lastError?.contains("mais nova") == true)
    }

    @Test func persistsAcrossReload() {
        // Mesmo arquivo de banco → outra instância recupera o histórico.
        let url = tempDBURL()
        let svc = ExternalAuditService(vault: UptendVault(fileURL: url))
        #expect(svc.ingest(sampleJSON, suggestedName: "x"))
        let svc2 = ExternalAuditService(vault: UptendVault(fileURL: url))
        #expect(svc2.audits.count == 1)
        #expect(svc2.selected?.hostname == "srv-teste")
    }

    @Test func removeDeletesFromVault() {
        let vault = UptendVault.inMemory()
        let svc = ExternalAuditService(vault: vault)
        #expect(svc.ingest(sampleJSON, suggestedName: "x"))
        let item = svc.audits[0]
        svc.remove(item)
        #expect(svc.audits.isEmpty)
        #expect(vault.payload(id: item.id) == nil)
    }

    @Test func clearAllEmptiesStore() {
        let url = tempDBURL()
        let svc = ExternalAuditService(vault: UptendVault(fileURL: url))
        #expect(svc.ingest(sampleJSON, suggestedName: "x"))
        svc.clearAll()
        #expect(svc.audits.isEmpty)
        #expect(svc.selectedID == nil)
        #expect(ExternalAuditService(vault: UptendVault(fileURL: url)).audits.isEmpty)
    }

    @Test func retentionPrunesOldRecords() {
        // Insere um registro "antigo" direto no banco; o serviço poda na abertura.
        let vault = UptendVault.inMemory()
        let past = Date().addingTimeInterval(-120 * 86400)   // 120 dias atrás
        vault.insert(id: "velha", kind: VaultKind.externalAudit, source: "srv", title: "srv",
                     createdAt: past, payload: sampleJSON, importedAt: past)
        #expect(vault.records(kind: VaultKind.externalAudit).count == 1)
        let svc = ExternalAuditService(vault: vault, retentionDays: 90)
        #expect(svc.audits.isEmpty)
        #expect(vault.payload(id: "velha") == nil)
    }

    @Test func retentionKeepsRecentRecords() {
        let svc = ExternalAuditService(vault: .inMemory(), retentionDays: 90)
        #expect(svc.ingest(sampleJSON, suggestedName: "x"))   // recém-criada
        #expect(svc.pruneOld() == 0)                          // nada a remover
        #expect(svc.audits.count == 1)
    }

    @Test func storageBytesReflectsContent() {
        let svc = ExternalAuditService(vault: .inMemory())
        #expect(svc.storageBytes() == 0)
        #expect(svc.ingest(sampleJSON, suggestedName: "x"))
        #expect(svc.storageBytes() == Int64(sampleJSON.count))
    }

    // MARK: A2 — senha do banco JAMAIS no comando remoto (só via stdin)

    @Test func collectorPasswordGoesToStdinNotArgv() {
        let db = DBCredential(kind: "postgres", user: "auditor", host: "localhost", port: 5432, database: "loja")
        let secret = "p@ss w0rd!'; echo x"   // com metacaractere e espaço, de propósito
        let inv = ExternalAuditService.collectorInvocation(
            scriptB64: "QUJD", runLynis: false, auditDB: true, db: db, password: secret)
        // O VALOR da senha NÃO pode aparecer na linha de comando (world-readable em
        // /proc/cmdline). O `export ..._PASSWORD="$__UPTEND_DBPW"` referencia a
        // variável, nunca o valor — por isso checamos o valor secreto em si.
        #expect(inv.remote.contains(secret) == false)
        #expect(inv.remote.contains("p@ss") == false)
        // Ela vem por stdin, terminada em newline (para o `read`).
        #expect(inv.stdin == secret + "\n")
        // O prelúdio lê o stdin e exporta a senha para o ambiente do coletor.
        #expect(inv.remote.contains("read -r __UPTEND_DBPW"))
        #expect(inv.remote.contains("export UPTEND_PG_PASSWORD="))
        // Campos NÃO secretos seguem inline (aceitável).
        #expect(inv.remote.contains("UPTEND_PG_USER="))
        #expect(inv.remote.contains("UPTEND_DB_AUDIT=1"))
    }

    @Test func dbCredentialRejectsDangerousDatabaseName() {
        // M1: nome de banco com metacaractere deve invalidar a credencial.
        func cred(_ dbName: String) -> DBCredential {
            DBCredential(kind: "mysql", user: "auditor", host: "localhost", port: 3306, database: dbName)
        }
        #expect(cred("loja").isValid)
        #expect(cred("").isValid)                       // vazio = todos os bancos
        #expect(cred("x'; DROP DATABASE y; --").isValid == false)
        #expect(cred("a b").isValid == false)
        #expect(cred("`evil`").isValid == false)
    }

    @Test func collectorMySQLSchemaSQLisStaticNoInjection() {
        // M1: o SQL do MySQL não pode interpolar o nome do banco (usa DATABASE()).
        let data = ExternalAuditService.collectorScript()
        #expect(data != nil)
        let script = String(data: data ?? Data(), encoding: .utf8) ?? ""
        #expect(script.contains("TABLE_SCHEMA=DATABASE()"))
        #expect(script.contains("TABLE_SCHEMA='$MDB'") == false)
    }

    @Test func effectiveScoreDiscountsAcceptedRisk() {
        // M3: a nota do painel (via store.effectiveScore) desconta os riscos aceitos,
        // ficando igual à dos relatórios.
        let audit = ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "admin"),
            collectedAt: "2026-07-20T00:00:00Z", host: .init(hostname: "srv", machineId: "m1"),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: [.init(id: "ssh-root-login", title: "SSH root", severity: .high, category: "Segurança / SSH")],
            lynis: nil)
        let store = RiskExceptionStore(defaults: UserDefaults(suiteName: "uptend-test-\(UUID().uuidString)")!)
        let raw = AuditScoring.evaluate(audit).score
        #expect(store.effectiveScore(audit).score == raw)          // sem exceção: igual à crua
        store.accept(RiskException(findingId: "ssh-root-login", title: "SSH root",
                                   justification: "aceito formalmente", responsible: "gestor",
                                   acceptedAt: "2020-01-01", expiresAt: "2099-12-31"), in: audit)
        #expect(store.effectiveScore(audit).score > raw)           // aceito: nota sobe
    }

    @Test func collectorWithoutPasswordHasNoStdinNorPrelude() {
        let db = DBCredential(kind: "mysql", user: "auditor", host: "localhost", port: 3306, database: "")
        let inv = ExternalAuditService.collectorInvocation(
            scriptB64: "QUJD", runLynis: false, auditDB: true, db: db, password: nil)
        #expect(inv.stdin == nil)                               // peer auth: sem stdin
        #expect(inv.remote.contains("read -r __UPTEND_DBPW") == false)
        #expect(inv.remote.contains("UPTEND_MY_USER="))        // demais campos presentes
    }
}
