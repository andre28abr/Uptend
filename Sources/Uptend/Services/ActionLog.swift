import Foundation

struct ActionEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    let date: Date
    let text: String
}

/// Registro das ações relevantes (instalar, remover, limpar, sincronizar).
/// Persistido localmente em UserDefaults — Privacy by Design (nada sai da máquina).
@MainActor
final class ActionLog: ObservableObject {
    static let shared = ActionLog()

    @Published private(set) var entries: [ActionEntry] = []

    private let key = "uptend.actionLog"
    private let maxEntries = 200

    init() { load() }

    func record(_ text: String) {
        entries.insert(ActionEntry(date: Date(), text: text), at: 0)
        if entries.count > maxEntries { entries.removeLast(entries.count - maxEntries) }
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ActionEntry].self, from: data) else { return }
        entries = decoded
    }
}
