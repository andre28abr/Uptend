import Foundation

// =============================================================================
// AUDITORIA DE BANCO DE DADOS — modelo de schema (E4)
// Representa APENAS a ESTRUTURA de um banco (tabelas, colunas, tipos, chaves,
// índices) — nunca dados. Preenchido pelo leitor de schema (SQLite/Postgres, só
// metadados). Base para os achados. Puro/Codable/testável.
// =============================================================================

public struct DBColumn: Codable, Equatable, Sendable, Identifiable {
    public let name: String
    public let type: String        // tipo declarado ("VARCHAR(255)", "TEXT", "INTEGER"…)
    public let notNull: Bool
    public let primaryKey: Bool
    public var id: String { name }

    public init(name: String, type: String, notNull: Bool = false, primaryKey: Bool = false) {
        self.name = name; self.type = type; self.notNull = notNull; self.primaryKey = primaryKey
    }

    /// Tipo de texto (onde caberia dado em claro): TEXT/VARCHAR/CHAR/CLOB, ou sem tipo (SQLite).
    public var isTextType: Bool {
        let t = type.uppercased()
        if t.isEmpty { return true }   // SQLite sem tipo declarado guarda texto
        return t.contains("CHAR") || t.contains("TEXT") || t.contains("CLOB") || t.contains("STRING")
    }
}

public struct DBTable: Codable, Equatable, Sendable, Identifiable {
    public let name: String
    public let columns: [DBColumn]
    public let foreignKeyColumns: [String]   // colunas que são FK
    public let indexedColumns: [String]      // colunas cobertas por algum índice
    public var id: String { name }

    public init(name: String, columns: [DBColumn],
                foreignKeyColumns: [String] = [], indexedColumns: [String] = []) {
        self.name = name; self.columns = columns
        self.foreignKeyColumns = foreignKeyColumns; self.indexedColumns = indexedColumns
    }

    public var hasPrimaryKey: Bool { columns.contains { $0.primaryKey } }
}

public struct DatabaseSchema: Codable, Equatable, Sendable {
    public let engine: String      // "SQLite", "PostgreSQL"…
    public let name: String        // nome do banco / arquivo
    public let tables: [DBTable]

    public init(engine: String, name: String, tables: [DBTable]) {
        self.engine = engine; self.name = name; self.tables = tables
    }

    public var columnCount: Int { tables.reduce(0) { $0 + $1.columns.count } }
}
