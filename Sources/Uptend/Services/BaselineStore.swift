import SwiftUI
import AppKit
import Foundation
import UptendCore

// =============================================================================
// BASELINE COMO CÓDIGO — armazenamento no app (FASE B4)
// Guarda o baseline "ativo" (o padrão da consultoria) em UserDefaults e permite
// carregar/salvar como arquivo JSON versionável, para reusar entre clientes.
// =============================================================================

@MainActor
final class BaselineStore: ObservableObject {
    @Published private(set) var baseline: Baseline? { didSet { save() } }

    private let key = "uptend.baseline"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let b = try? JSONDecoder().decode(Baseline.self, from: data) {
            baseline = b
        }
    }

    var isConfigured: Bool { baseline != nil }

    func set(_ b: Baseline) { baseline = b }
    func clear() { baseline = nil }

    /// Gera o baseline a partir da auditoria de referência (todos os controles avaliados).
    func generate(from audit: ExternalAudit, name: String, today: String) {
        baseline = BaselineEngine.generate(from: audit, name: name, today: today)
    }

    /// Carrega um baseline de um arquivo JSON escolhido pelo usuário. Retorna erro (nil = ok).
    func loadFromFile() -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }   // cancelou
        do {
            let data = try Data(contentsOf: url)
            baseline = try JSONDecoder().decode(Baseline.self, from: data)
            return nil
        } catch {
            return "Arquivo de baseline inválido: \(error.localizedDescription)"
        }
    }

    /// Salva o baseline ativo como arquivo JSON.
    func saveToFile() {
        guard let b = baseline else { return }
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(b) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "baseline-\(b.name.replacingOccurrences(of: " ", with: "-")).json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url { try? data.write(to: url) }
    }

    private func save() {
        if let b = baseline, let data = try? JSONEncoder().encode(b) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
