import Foundation
import SQLite3
import UptendCore

// =============================================================================
// LEITOR DE SCHEMA SQLite (E4 — modo estrutura, LGPD-safe)
// Abre um arquivo SQLite em SOMENTE-LEITURA e lê APENAS a estrutura: tabelas,
// colunas, tipos, chaves e índices — via `sqlite_master` e as funções `pragma_*`.
// NUNCA executa SELECT em dados de nenhuma tabela → é impossível ler dado pessoal.
// =============================================================================

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SQLiteSchemaReader {

    enum ReaderError: LocalizedError {
        case open(String)
        var errorDescription: String? {
            switch self { case .open(let m): return "Não consegui abrir como banco SQLite: \(m)." }
        }
    }

    static func read(fileURL: URL) throws -> DatabaseSchema {
        var db: OpaquePointer?
        guard sqlite3_open_v2(fileURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let handle = db else {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "arquivo inválido"
            sqlite3_close(db)
            throw ReaderError.open(msg)
        }
        defer { sqlite3_close(handle) }

        // Nomes de tabela (ignora as internas do SQLite). Se falhar, não é um SQLite válido.
        let names = queryStrings(handle,
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;")
        guard sqlite3_errcode(handle) == SQLITE_OK || !names.isEmpty || tableCountReadable(handle) else {
            throw ReaderError.open(String(cString: sqlite3_errmsg(handle)))
        }

        var tables: [DBTable] = []
        for t in names {
            tables.append(DBTable(name: t, columns: columns(handle, table: t),
                                  foreignKeyColumns: foreignKeys(handle, table: t),
                                  indexedColumns: indexedColumns(handle, table: t)))
        }
        return DatabaseSchema(engine: "SQLite", name: fileURL.lastPathComponent, tables: tables)
    }

    /// MODO COMPLETO: amostra valores APENAS das colunas de senha (para confirmar hash vs texto
    /// plano). Lê no máximo `limit` valores por coluna, EM MEMÓRIA — nada é armazenado.
    /// Só é chamado quando o usuário opta pelo modo completo (banco próprio).
    static func samplePasswordColumns(fileURL: URL, schema: DatabaseSchema, limit: Int = 10) -> [String: [String]] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(fileURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let handle = db else {
            sqlite3_close(db); return [:]
        }
        defer { sqlite3_close(handle) }
        var out: [String: [String]] = [:]
        let pw = ["senha", "password", "passwd", "pwd"]
        for table in schema.tables {
            for col in table.columns where col.isTextType {
                let n = col.name.lowercased()
                guard pw.contains(where: { n.contains($0) }), !n.contains("hash") else { continue }
                let sql = "SELECT \(quoteIdent(col.name)) FROM \(quoteIdent(table.name)) WHERE \(quoteIdent(col.name)) IS NOT NULL LIMIT \(limit);"
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK {
                    var vals: [String] = []
                    while sqlite3_step(stmt) == SQLITE_ROW { vals.append(text(stmt, 0)) }
                    if !vals.isEmpty { out["\(table.name).\(col.name)"] = vals }
                }
                sqlite3_finalize(stmt)
            }
        }
        return out
    }

    private static func quoteIdent(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: privados — só metadados

    private static func tableCountReadable(_ db: OpaquePointer) -> Bool {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        return sqlite3_prepare_v2(db, "SELECT count(*) FROM sqlite_master;", -1, &stmt, nil) == SQLITE_OK
            && sqlite3_step(stmt) == SQLITE_ROW
    }

    private static func columns(_ db: OpaquePointer, table: String) -> [DBColumn] {
        var out: [DBColumn] = []
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT name, type, \"notnull\", pk FROM pragma_table_info(?);", -1, &stmt, nil) == SQLITE_OK else { return out }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, table, -1, SQLITE_TRANSIENT)
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append(DBColumn(name: text(stmt, 0), type: text(stmt, 1),
                                notNull: sqlite3_column_int(stmt, 2) != 0,
                                primaryKey: sqlite3_column_int(stmt, 3) != 0))
        }
        return out
    }

    private static func foreignKeys(_ db: OpaquePointer, table: String) -> [String] {
        var out: [String] = []
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT \"from\" FROM pragma_foreign_key_list(?);", -1, &stmt, nil) == SQLITE_OK else { return out }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, table, -1, SQLITE_TRANSIENT)
        while sqlite3_step(stmt) == SQLITE_ROW { out.append(text(stmt, 0)) }
        return out
    }

    private static func indexedColumns(_ db: OpaquePointer, table: String) -> [String] {
        var cols = Set<String>()
        // colunas com PK também contam como indexadas
        for idx in queryStrings1(db, "SELECT name FROM pragma_index_list(?);", arg: table) {
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, "SELECT name FROM pragma_index_info(?);", -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, idx, -1, SQLITE_TRANSIENT)
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let n = text(stmt, 0); if !n.isEmpty { cols.insert(n) }
                }
            }
            sqlite3_finalize(stmt)
        }
        return Array(cols)
    }

    private static func text(_ stmt: OpaquePointer?, _ i: Int32) -> String {
        guard let c = sqlite3_column_text(stmt, i) else { return "" }
        return String(cString: c)
    }

    private static func queryStrings(_ db: OpaquePointer, _ sql: String) -> [String] {
        var out: [String] = []
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return out }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW { out.append(text(stmt, 0)) }
        return out
    }

    private static func queryStrings1(_ db: OpaquePointer, _ sql: String, arg: String) -> [String] {
        var out: [String] = []
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return out }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, arg, -1, SQLITE_TRANSIENT)
        while sqlite3_step(stmt) == SQLITE_ROW { out.append(text(stmt, 0)) }
        return out
    }
}
