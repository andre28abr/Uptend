import SwiftUI
import AppKit
import UptendCore

// =============================================================================
// MARCA DO RELATÓRIO (white-label) — tela de configuração (FASE A1)
// =============================================================================

struct BrandingView: View {
    @EnvironmentObject var store: BrandingStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Marca do relatório",
                             subtitle: "Personalize a capa dos relatórios de auditoria (white-label)")

                Text("Estes dados aparecem na capa dos relatórios (executivo, técnico, SOC) — logo, empresa auditora, auditor e cliente. Deixe em branco para o layout padrão.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

                logoCard
                fieldsCard
            }
            .screenPadding()
            .frame(maxWidth: 720, alignment: .leading)
        }
    }

    private var logoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Logo", systemImage: "photo").font(.headline)
            HStack(spacing: 14) {
                if let uri = store.branding.logoDataURI, let img = image(from: uri) {
                    Image(nsImage: img).resizable().scaledToFit().frame(height: 60)
                        .padding(8).cardBackground()
                } else {
                    Text("nenhum logo").font(.callout).foregroundStyle(.secondary)
                        .frame(height: 60).frame(maxWidth: 160).cardBackground()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Button { pickLogo() } label: { Label("Escolher imagem…", systemImage: "folder") }
                    if store.branding.logoDataURI != nil {
                        Button(role: .destructive) { store.clearLogo() } label: { Label("Remover logo", systemImage: "trash") }
                            .buttonStyle(.borderless)
                    }
                    Text("PNG/JPG · reduzido para embutir no relatório").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private var fieldsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            field("Empresa auditora / consultoria", text: bind(\.company), placeholder: "ex.: Acme Security Consulting")
            field("Auditor (seu nome)", text: bind(\.auditor), placeholder: "ex.: André Souza")
            field("Cargo / credencial", text: bind(\.auditorTitle), placeholder: "ex.: CISSP · Analista de Segurança")
            field("Contato", text: bind(\.contact), placeholder: "ex.: andre@acme.com")
            field("Cliente auditado", text: bind(\.client), placeholder: "ex.: Contoso Ltda")
            field("Relatório nº / versão", text: bind(\.reportNumber), placeholder: "ex.: AUD-2026-014 v1")
            VStack(alignment: .leading, spacing: 4) {
                Text("Aviso de confidencialidade").font(.caption).foregroundStyle(.secondary)
                TextField("(padrão) CONFIDENCIAL · Uso interno / cliente…", text: bind(\.confidentiality), axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(2...4)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, text: text).textFieldStyle(.roundedBorder)
        }
    }

    private func bind(_ kp: WritableKeyPath<ReportBranding, String>) -> Binding<String> {
        Binding(get: { store.branding[keyPath: kp] }, set: { store.branding[keyPath: kp] = $0 })
    }

    private func pickLogo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { store.setLogo(from: url) }
    }

    private func image(from dataURI: String) -> NSImage? {
        guard let comma = dataURI.firstIndex(of: ","),
              let data = Data(base64Encoded: String(dataURI[dataURI.index(after: comma)...])) else { return nil }
        return NSImage(data: data)
    }
}
