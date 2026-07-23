import Testing
import Foundation
@testable import Uptend

/// Banco central do app (SQLite). Cobre inserção, dedup, leitura, limpeza, retenção,
/// tamanho e persistência entre reaberturas.
@MainActor
struct UptendVaultTests {

    private func payload(_ s: String) -> Data { Data(s.utf8) }

    @Test func insertReadAndPayload() {
        let v = UptendVault.inMemory()
        #expect(v.insert(id: "a", kind: "k1", source: "srv", title: "T", createdAt: Date(), payload: payload("hello")))
        let recs = v.records()
        #expect(recs.count == 1)
        #expect(recs[0].id == "a")
        #expect(recs[0].source == "srv")
        #expect(recs[0].sizeBytes == 5)
        #expect(v.payload(id: "a") == payload("hello"))
        #expect(v.payload(id: "inexistente") == nil)
    }

    @Test func sqlMetacharactersTreatedAsLiterals() {
        // Regressão: id/kind/title com sintaxe SQL entram por bind (parametrizado),
        // nunca concatenados — devem ser tratados como texto literal, sem injeção.
        let v = UptendVault.inMemory()
        let evilID = "a'; DROP TABLE records; --"
        #expect(v.insert(id: evilID, kind: "k'--", source: "s", title: "T'; --",
                         createdAt: Date(), payload: payload("x")))
        // A tabela sobreviveu e o id foi guardado LITERALMENTE.
        #expect(v.records().count == 1)
        #expect(v.records()[0].id == evilID)
        #expect(v.payload(id: evilID) == payload("x"))
    }

    @Test func binaryBlobRoundTrips() {
        // Payload binário (não-UTF8) preserva todos os bytes (SQLITE_TRANSIENT no bind_blob).
        let v = UptendVault.inMemory()
        let bytes = Data((0...255).map { UInt8($0) }) + Data([0, 0, 255, 254])
        #expect(v.insert(id: "bin", kind: "k", source: "s", title: "t", createdAt: Date(), payload: bytes))
        #expect(v.payload(id: "bin") == bytes)
    }

    @Test func deduplicatesById() {
        let v = UptendVault.inMemory()
        #expect(v.insert(id: "a", kind: "k", source: "s", title: "t", createdAt: Date(), payload: payload("1")))
        #expect(v.insert(id: "a", kind: "k", source: "s", title: "t", createdAt: Date(), payload: payload("2")) == false)
        #expect(v.records().count == 1)
        #expect(v.payload(id: "a") == payload("1"))   // manteve o primeiro
    }

    @Test func filtersAndClearsByKind() {
        let v = UptendVault.inMemory()
        v.insert(id: "a", kind: "audit", source: "s", title: "t", createdAt: Date(), payload: payload("x"))
        v.insert(id: "b", kind: "mac", source: "s", title: "t", createdAt: Date(), payload: payload("y"))
        #expect(v.records(kind: "audit").count == 1)
        #expect(v.records().count == 2)
        #expect(v.clear(kind: "audit") == 1)
        #expect(v.records(kind: "audit").isEmpty)
        #expect(v.records(kind: "mac").count == 1)   // outro tipo intacto
    }

    @Test func deleteRemovesOne() {
        let v = UptendVault.inMemory()
        v.insert(id: "a", kind: "k", source: "s", title: "t", createdAt: Date(), payload: payload("x"))
        v.delete(id: "a")
        #expect(v.records().isEmpty)
    }

    @Test func pruneRemovesOldByImportedAt() {
        let v = UptendVault.inMemory()
        let old = Date().addingTimeInterval(-100 * 86400)
        v.insert(id: "old", kind: "k", source: "s", title: "t", createdAt: old, payload: payload("x"), importedAt: old)
        v.insert(id: "new", kind: "k", source: "s", title: "t", createdAt: Date(), payload: payload("y"))
        #expect(v.pruneOlderThan(days: 90, kind: "k") == 1)
        #expect(v.records().map(\.id) == ["new"])
    }

    @Test func totalBytesAndSummary() {
        let v = UptendVault.inMemory()
        v.insert(id: "a", kind: "audit", source: "s", title: "t", createdAt: Date(), payload: payload("12345"))
        v.insert(id: "b", kind: "audit", source: "s", title: "t", createdAt: Date(), payload: payload("123"))
        v.insert(id: "c", kind: "mac", source: "s", title: "t", createdAt: Date(), payload: payload("1"))
        #expect(v.totalBytes() == 9)
        #expect(v.totalBytes(kind: "audit") == 8)
        let summary = v.summary()
        #expect(summary.first { $0.kind == "audit" }?.count == 2)
        #expect(summary.first { $0.kind == "audit" }?.bytes == 8)
    }

    @Test func persistsAcrossReopen() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vault-persist-\(UUID().uuidString).sqlite")
        do {
            let v = UptendVault(fileURL: url)
            v.insert(id: "a", kind: "k", source: "s", title: "t", createdAt: Date(), payload: payload("persist"))
        }
        let v2 = UptendVault(fileURL: url)
        #expect(v2.records().count == 1)
        #expect(v2.payload(id: "a") == payload("persist"))
    }
}
