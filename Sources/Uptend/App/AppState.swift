import SwiftUI

/// Aparência escolhida pelo usuário. `system` acompanha o macOS.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Sistema"
        case .light: "Claro"
        case .dark: "Escuro"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Estado global da interface: categoria e subseção selecionadas + preferências.
@MainActor
final class AppState: ObservableObject {
    @Published var category: Category = .dashboard {
        didSet {
            if oldValue != category {
                subID = category.subsections.first?.id
            }
        }
    }

    @Published var subID: String?
    @Published var appearance: Appearance = .system
    @Published var showNotifications = false

    // MARK: - Host ativo (abas: Este Mac / HomeLab / Servidor) — gerenciados via SSH.

    @Published var activeHost: HostContext = .thisMac
    /// Tipo que a folha "Adicionar host" vai criar.
    @Published var addHostKind: HostKind = .homelab
    @Published var homelabSection: HomeLabSection = .overview {
        didSet {
            if oldValue != homelabSection {
                homelabSubID = homelabSection.subsections.first?.id
            }
        }
    }
    @Published var homelabSubID: String?
    @Published var showAddHost = false

    // MARK: - Auditoria Externa (aba própria)

    @Published var auditoriaSection: AuditoriaSection = .painel {
        didSet {
            if oldValue != auditoriaSection {
                auditoriaSubID = auditoriaSection.subsections.first?.id
            }
        }
    }
    @Published var auditoriaSubID: String?

    init() {
        subID = category.subsections.first?.id
        homelabSubID = homelabSection.subsections.first?.id
        auditoriaSubID = auditoriaSection.subsections.first?.id
    }

    /// Subseção atualmente selecionada (com fallback para a primeira).
    var currentSubsection: SubSection? {
        category.subsections.first { $0.id == subID } ?? category.subsections.first
    }

    /// Subseção do HomeLab atualmente selecionada (com fallback para a primeira).
    var homelabSubsection: SubSection? {
        homelabSection.subsections.first { $0.id == homelabSubID } ?? homelabSection.subsections.first
    }

    /// Subseção da Auditoria Externa atualmente selecionada (com fallback para a primeira).
    var auditoriaSubsection: SubSection? {
        auditoriaSection.subsections.first { $0.id == auditoriaSubID } ?? auditoriaSection.subsections.first
    }
}

/// Tipo de host remoto: um HomeLab (Proxmox etc.) ou um servidor Linux comum.
enum HostKind: String, Codable, Hashable {
    case homelab, server
    var label: String { self == .homelab ? "HomeLab" : "Servidor" }
    var systemImage: String { self == .homelab ? "server.rack" : "desktopcomputer" }
}

/// Qual área está em foco na barra de abas de topo.
enum HostContext: Hashable {
    case thisMac
    case remote(HostKind, UUID)   // tipo + id do host no HostStore
    case auditoria                // Auditoria Externa (aba própria, com suas ferramentas)

    var isRemote: Bool { if case .remote = self { return true }; return false }
    var isAuditoria: Bool { if case .auditoria = self { return true }; return false }
    var remoteKind: HostKind? { if case let .remote(k, _) = self { return k }; return nil }
    var remoteID: UUID? { if case let .remote(_, id) = self { return id }; return nil }
}
