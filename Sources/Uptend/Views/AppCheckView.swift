import SwiftUI
import AppKit

/// "Posso abrir isso com segurança?" — verifica assinatura, notarização,
/// Gatekeeper e quarentena de um app escolhido. Só leitura, sem sudo.
struct AppCheckView: View {
    @StateObject private var checker = AppCheckService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Verificar app",
                             subtitle: "Confira se um app é assinado, notarizado e confiável") {
                    if checker.checking { ProgressView().controlSize(.small) }
                    Button { pick() } label: { Label("Escolher app…", systemImage: "app.badge.checkmark") }
                        .disabled(checker.checking)
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle").foregroundStyle(.blue)
                    Text("Escolha um app (em Aplicativos ou um download). O Uptend consulta o Gatekeeper e a assinatura da Apple para dizer se ele é confiável — sem abrir o app.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()

                if let error = checker.lastError {
                    ErrorBanner(error)
                }

                if let v = checker.verdict {
                    verdictCard(v)

                    if let note = v.note {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "person.badge.shield.checkmark").foregroundStyle(.blue)
                            Text(note).font(.callout).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
                    }

                    detailRows(v)

                    if v.quarantined, let path = checker.lastPath {
                        Button {
                            Task { await checker.trustLocally(path: path) }
                        } label: {
                            Label("Confiar localmente (remover quarentena)", systemImage: "hand.raised.slash")
                        }
                        .disabled(checker.checking)
                        Text("Remove o selo de \"baixado da internet\" para que o macOS pare de bloquear. Faça isso só com apps de origem que você conhece.")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
    }

    private func verdictCard(_ v: AppVerdict) -> some View {
        CardRow {
            HStack(spacing: 12) {
                Image(systemName: icon(v.level)).font(.title).foregroundStyle(color(v.level))
                VStack(alignment: .leading, spacing: 2) {
                    Text(v.name).fontWeight(.medium)
                    Text(v.headline).font(.callout).foregroundStyle(color(v.level))
                }
            }
        } trailing: { EmptyView() }
    }

    private func detailRows(_ v: AppVerdict) -> some View {
        VStack(spacing: 8) {
            row("Assinatura", v.signed ? (v.valid ? "Válida" : "Presente, mas inválida") : "Ausente",
                ok: v.signed && v.valid)
            if !v.authority.isEmpty { row("Assinado por", v.authority, ok: true) }
            if !v.teamID.isEmpty { row("Team ID", v.teamID, ok: true) }
            row("Notarizado pela Apple", v.notarized ? "Sim" : (v.appleSigned ? "É app da Apple" : "Não"),
                ok: v.notarized || v.appleSigned)
            row("Gatekeeper", v.gatekeeperAccepted ? "Aceita abrir" : "Bloqueia",
                ok: v.gatekeeperAccepted, detail: v.gatekeeperSource)
            row("Quarentena", v.quarantined ? "Sim (baixado, não aprovado)" : "Não",
                ok: !v.quarantined)
        }
    }

    private func row(_ title: String, _ value: String, ok: Bool, detail: String = "") -> some View {
        CardRow {
            HStack(spacing: 10) {
                Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(ok ? .green : .orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).fontWeight(.medium)
                    if !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                Text(value).font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        } trailing: { EmptyView() }
    }

    private func icon(_ l: TrustLevel) -> String {
        switch l { case .trusted: "checkmark.seal.fill"; case .caution: "exclamationmark.triangle.fill"; case .danger: "xmark.seal.fill" }
    }
    private func color(_ l: TrustLevel) -> Color {
        switch l { case .trusted: .green; case .caution: .orange; case .danger: .red }
    }

    private func pick() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Verificar"
        panel.message = "Escolha um app para verificar"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await checker.check(path: url.path) }
    }
}
