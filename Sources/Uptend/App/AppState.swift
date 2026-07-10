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

    init() {
        subID = category.subsections.first?.id
    }

    /// Subseção atualmente selecionada (com fallback para a primeira).
    var currentSubsection: SubSection? {
        category.subsections.first { $0.id == subID } ?? category.subsections.first
    }
}
