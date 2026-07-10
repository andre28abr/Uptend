import SwiftUI

// MARK: - Instalar

struct AppItem: Identifiable, Hashable {
    var id: String { token.isEmpty ? name : token }
    let name: String
    let tagline: String
    let token: String   // token do Homebrew ("" = o próprio Homebrew)
    let isCask: Bool
}

// MARK: - Atualizar

struct UpdatePackage: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let current: String
    let latest: String
}

// MARK: - Git

enum GitStatus: Hashable {
    case synced
    case ahead(Int)
    case behind(Int)
    case dirty

    var label: String {
        switch self {
        case .synced: "Sincronizado"
        case .ahead(let n): "\(n) à frente"
        case .behind(let n): "\(n) atrás"
        case .dirty: "Alterações locais"
        }
    }

    var systemImage: String {
        switch self {
        case .synced: "checkmark.circle.fill"
        case .ahead: "arrow.up.circle.fill"
        case .behind: "arrow.down.circle.fill"
        case .dirty: "pencil.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .synced: .green
        case .ahead: .blue
        case .behind: .orange
        case .dirty: .yellow
        }
    }
}

// MARK: - Segurança

enum CheckStatus {
    case ok, warning

    var systemImage: String {
        switch self {
        case .ok: "checkmark.shield.fill"
        case .warning: "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .ok: .green
        case .warning: .orange
        }
    }
}

struct SecurityCheck: Identifiable, Hashable {
    static func == (l: SecurityCheck, r: SecurityCheck) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id = UUID()
    let name: String
    let detail: String
    let status: CheckStatus
}

