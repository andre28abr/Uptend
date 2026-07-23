import Foundation
import SQLite3

// =============================================================================
// UPTEND VAULT — banco central do app (SQLite)
// Store único para os dados/varreduras de TODAS as abas (Auditoria Externa hoje;
// inventário do Mac, scans etc. depois). Cada registro tem tipo, origem, data/hora
// de coleta, tamanho e o conteúdo (JSON). Permite listar, apagar por tipo, limpar
// tudo, ver quanto ocupa e podar por retenção.
//
// Usa a libsqlite3 do próprio sistema (sem dependência externa).
// =============================================================================

/// Metadados de um registro guardado (sem o payload, para listagens rápidas).
struct VaultRecord: Identifiable, Equatable {
    let id: String          // hash do conteúdo (dedup + cadeia de custódia)
    let kind: String        // tipo do dado (ex.: VaultKind.externalAudit)
    let source: String      // origem (hostname, "Este Mac"…)
    let title: String
    let createdAt: Date     // quando o dado foi coletado/gerado
    let importedAt: Date    // quando entrou no banco
    let sizeBytes: Int
}

/// Tipos de dado guardados no Vault (crescerá conforme outras abas forem plugadas).
enum VaultKind {
    static let externalAudit = "external_audit"
    static let macReport = "mac_report"

    /// Nome amigável do tipo (para a tela "Dados do app").
    static func label(_ kind: String) -> String {
        switch kind {
        case externalAudit: "Auditorias de servidores"
        case macReport: "Inventários do Mac"
        default: kind
        }
    }

    static func icon(_ kind: String) -> String {
        switch kind {
        case externalAudit: "chart.bar.doc.horizontal"
        case macReport: "desktopcomputer"
        default: "doc"
        }
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

@MainActor
final class UptendVault: ObservableObject {
    /// Instância padrão do app (banco em Application Support/Uptend/uptend.sqlite).
    static let shared = UptendVault()

    /// Muda a cada escrita — telas que observam o banco se atualizam.
    @Published private(set) var revision = 0

    private var db: OpaquePointer?
    let fileURL: URL
    private let dbPath: String

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            let dir = base.appendingPathComponent("Uptend", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("uptend.sqlite")
        }
        self.dbPath = self.fileURL.path
        open()
    }

    private init(memoryPath: String) {
        self.fileURL = URL(fileURLWithPath: memoryPath)
        self.dbPath = memoryPath
        open()
    }

    /// Banco em memória (isolado, para testes).
    static func inMemory() -> UptendVault { UptendVault(memoryPath: ":memory:") }

    deinit { if let db { sqlite3_close(db) } }

    private func open() {
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else { db = nil; return }
        exec("PRAGMA journal_mode=WAL;")
        exec("""
        CREATE TABLE IF NOT EXISTS records (
            id TEXT PRIMARY KEY,
            kind TEXT NOT NULL,
            source TEXT NOT NULL,
            title TEXT NOT NULL,
            created_at REAL NOT NULL,
            imported_at REAL NOT NULL,
            size_bytes INTEGER NOT NULL,
            payload BLOB NOT NULL
        );
        """)
        exec("CREATE INDEX IF NOT EXISTS idx_records_kind ON records(kind);")
    }

    @discardableResult
    private func exec(_ sql: String) -> Bool {
        sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }

    // MARK: Escrita

    /// Insere um registro. Retorna false se já existe um com o mesmo id (dedup) ou erro.
    @discardableResult
    func insert(id: String, kind: String, source: String, title: String,
                createdAt: Date, payload: Data, importedAt: Date = Date()) -> Bool {
        let sql = "INSERT OR IGNORE INTO records (id, kind, source, title, created_at, imported_at, size_bytes, payload) VALUES (?,?,?,?,?,?,?,?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, id)
        bindText(stmt, 2, kind)
        bindText(stmt, 3, source)
        bindText(stmt, 4, title)
        sqlite3_bind_double(stmt, 5, createdAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 6, importedAt.timeIntervalSince1970)
        sqlite3_bind_int64(stmt, 7, Int64(payload.count))
        payload.withUnsafeBytes { raw in
            sqlite3_bind_blob(stmt, 8, raw.baseAddress, Int32(payload.count), SQLITE_TRANSIENT)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else { return false }
        let inserted = sqlite3_changes(db) > 0
        if inserted { revision += 1 }
        return inserted
    }

    func delete(id: String) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "DELETE FROM records WHERE id=?;", -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, id)
        if sqlite3_step(stmt) == SQLITE_DONE { revision += 1 }
    }

    /// Apaga todos os registros de um tipo (nil = tudo). Retorna quantos foram removidos.
    @discardableResult
    func clear(kind: String? = nil) -> Int {
        let sql = kind == nil ? "DELETE FROM records;" : "DELETE FROM records WHERE kind=?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        if let kind { bindText(stmt, 1, kind) }
        guard sqlite3_step(stmt) == SQLITE_DONE else { return 0 }
        let n = Int(sqlite3_changes(db))
        if n > 0 { revision += 1 }
        return n
    }

    /// Remove registros mais antigos que `days` (por data de importação). Retorna quantos.
    @discardableResult
    func pruneOlderThan(days: Int, kind: String? = nil) -> Int {
        guard days > 0 else { return 0 }
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400).timeIntervalSince1970
        let sql = kind == nil
            ? "DELETE FROM records WHERE imported_at < ?;"
            : "DELETE FROM records WHERE imported_at < ? AND kind=?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, cutoff)
        if let kind { bindText(stmt, 2, kind) }
        guard sqlite3_step(stmt) == SQLITE_DONE else { return 0 }
        let n = Int(sqlite3_changes(db))
        if n > 0 { revision += 1 }
        return n
    }

    // MARK: Leitura

    /// Lista os metadados dos registros (mais recentes primeiro). `kind` nil = todos.
    func records(kind: String? = nil) -> [VaultRecord] {
        let sql = (kind == nil
            ? "SELECT id, kind, source, title, created_at, imported_at, size_bytes FROM records ORDER BY imported_at DESC;"
            : "SELECT id, kind, source, title, created_at, imported_at, size_bytes FROM records WHERE kind=? ORDER BY imported_at DESC;")
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        if let kind { bindText(stmt, 1, kind) }
        var out: [VaultRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append(VaultRecord(
                id: text(stmt, 0), kind: text(stmt, 1), source: text(stmt, 2), title: text(stmt, 3),
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4)),
                importedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5)),
                sizeBytes: Int(sqlite3_column_int64(stmt, 6))))
        }
        return out
    }

    /// Conteúdo (JSON) de um registro.
    func payload(id: String) -> Data? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT payload FROM records WHERE id=?;", -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, id)
        guard sqlite3_step(stmt) == SQLITE_ROW, let blob = sqlite3_column_blob(stmt, 0) else { return nil }
        let n = Int(sqlite3_column_bytes(stmt, 0))
        return Data(bytes: blob, count: n)
    }

    /// Espaço ocupado (soma de size_bytes). `kind` nil = tudo.
    func totalBytes(kind: String? = nil) -> Int64 {
        let sql = kind == nil ? "SELECT COALESCE(SUM(size_bytes),0) FROM records;"
                              : "SELECT COALESCE(SUM(size_bytes),0) FROM records WHERE kind=?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        if let kind { bindText(stmt, 1, kind) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return sqlite3_column_int64(stmt, 0)
    }

    /// Resumo por tipo (para uma futura tela "Dados do app": tipo, quantos, tamanho).
    func summary() -> [(kind: String, count: Int, bytes: Int64)] {
        let sql = "SELECT kind, COUNT(*), COALESCE(SUM(size_bytes),0) FROM records GROUP BY kind ORDER BY kind;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var out: [(String, Int, Int64)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append((text(stmt, 0), Int(sqlite3_column_int64(stmt, 1)), sqlite3_column_int64(stmt, 2)))
        }
        return out
    }

    // MARK: Helpers de binding/leitura

    private func bindText(_ stmt: OpaquePointer?, _ idx: Int32, _ value: String) {
        sqlite3_bind_text(stmt, idx, value, -1, SQLITE_TRANSIENT)
    }
    private func text(_ stmt: OpaquePointer?, _ idx: Int32) -> String {
        guard let c = sqlite3_column_text(stmt, idx) else { return "" }
        return String(cString: c)
    }
}
