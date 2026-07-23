import SwiftUI
import AppKit
import UptendCore

// =============================================================================
// MARCA DO RELATÓRIO (white-label) — armazenamento no app (FASE A1)
// Guarda a ReportBranding em UserDefaults e injeta nos relatórios. O logo é
// reduzido (máx. 400px) e embutido como data-URI PNG (relatório autocontido).
// =============================================================================

@MainActor
final class BrandingStore: ObservableObject {
    @Published var branding: ReportBranding { didSet { save() } }

    private let key = "uptend.reportBranding"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let b = try? JSONDecoder().decode(ReportBranding.self, from: data) {
            branding = b
        } else {
            branding = ReportBranding()
        }
    }

    /// A marca para injetar nos relatórios (nil quando não configurada → layout padrão).
    var forReports: ReportBranding? { branding.isConfigured ? branding : nil }

    private func save() {
        if let data = try? JSONEncoder().encode(branding) { defaults.set(data, forKey: key) }
    }

    /// Define o logo a partir de um arquivo de imagem (reduz e embute como PNG data-URI).
    @discardableResult
    func setLogo(from url: URL) -> Bool {
        guard let img = NSImage(contentsOf: url) else { return false }
        let maxW: CGFloat = 400
        let scale = min(1, maxW / max(img.size.width, 1))
        let target = NSSize(width: max(1, img.size.width * scale), height: max(1, img.size.height * scale))
        let resized = NSImage(size: target)
        resized.lockFocus()
        img.draw(in: NSRect(origin: .zero, size: target),
                 from: NSRect(origin: .zero, size: img.size), operation: .copy, fraction: 1)
        resized.unlockFocus()
        guard let tiff = resized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return false }
        branding.logoDataURI = "data:image/png;base64,\(png.base64EncodedString())"
        return true
    }

    func clearLogo() { branding.logoDataURI = nil }
}
