import SwiftUI
import AppKit

/// Painel do relatório/inventário da máquina: escolhe escopo, formato e nível de
/// detalhe, pré-visualiza e exporta. Reutilizado no menu da toolbar (sheet) e na
/// seção Configurações › Relatório (inline).
struct ReportPanel: View {
    let asSheet: Bool

    @EnvironmentObject var system: SystemService
    @EnvironmentObject var apps: AppsService
    @EnvironmentObject var brew: BrewService
    @EnvironmentObject var security: SecurityService
    @EnvironmentObject var vault: UptendVault
    @Environment(\.dismiss) private var dismiss

    @State private var data: ReportData?
    @State private var loading = true
    @State private var scope: ReportScope
    @State private var format: ReportFormat = .markdown
    @State private var detail: ReportDetail = .summary

    init(initialScope: ReportScope = .complete, asSheet: Bool = false) {
        self.asSheet = asSheet
        _scope = State(initialValue: initialScope)
    }

    private var rendered: String {
        guard let data else { return "" }
        return SystemReport.render(data, scope: scope, format: format, detail: detail)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Inventário do Mac").font(.title3).fontWeight(.medium)
                    Text(loading ? "Coletando dados da máquina…" : "Pronto para exportar")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                if loading { ProgressView().controlSize(.small) }
                if asSheet { Button("Fechar") { dismiss() }.keyboardShortcut(.cancelAction) }
            }

            // Opções
            VStack(alignment: .leading, spacing: 10) {
                Picker("Conteúdo", selection: $scope) {
                    ForEach(ReportScope.allCases) { Text($0.title).tag($0) }
                }
                .help("Quanto do inventário incluir: tudo (completo) ou só uma categoria.")
                Picker("Formato", selection: $format) {
                    ForEach(ReportFormat.allCases) { Text($0.title).tag($0) }
                }
                .help("Como exportar: Markdown, HTML (bonito/imprimível), JSON (dados) ou texto simples.")
                Picker("Detalhe", selection: $detail) {
                    ForEach(ReportDetail.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
                .help("Resumido mostra os destaques; Detalhado lista tudo (ex.: todos os apps).")
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()

            // Pré-visualização
            ScrollView {
                Text(rendered.isEmpty ? "…" : rendered)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
            }
            .frame(minHeight: 240)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))

            // Ações
            HStack {
                Button { Clipboard.copy(rendered) } label: { Label("Copiar", systemImage: "doc.on.doc") }
                    .disabled(data == nil)
                Button(action: save) { Label("Salvar…", systemImage: "square.and.arrow.down") }
                    .disabled(data == nil)
                Button(action: saveToHistory) { Label("Guardar no histórico", systemImage: "clock.badge.checkmark") }
                    .disabled(data == nil)
                    .help("Guarda este inventário no banco do app (aba Configurações › Dados) para comparar no tempo.")
                if format == .html {
                    Button(action: openInBrowser) { Label("Abrir no navegador", systemImage: "safari") }
                        .disabled(data == nil)
                }
                Spacer()
                Text("Tudo local — nada é enviado para fora.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(asSheet ? 20 : 0)
        .frame(minWidth: asSheet ? 620 : nil, minHeight: asSheet ? 560 : nil)
        .task(id: scope) {
            loading = true
            data = await ReportBuilder.gather(scope: scope, system: system, apps: apps,
                                              brew: brew, security: security)
            loading = false
        }
    }

    private func save() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "inventario-uptend.\(format.fileExtension)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? rendered.write(to: url, atomically: true, encoding: .utf8)
        ToastCenter.shared.show("Relatório salvo")
    }

    /// Guarda o inventário atual (ReportData) no banco central, para histórico/comparação.
    private func saveToHistory() {
        guard let data, let json = try? JSONEncoder().encode(data) else { return }
        let id = HashUtil.sha256(data: json)
        let created = ISO8601DateFormatter().date(from: data.generatedAt) ?? Date()
        let name = data.computerName.isEmpty ? "Este Mac" : data.computerName
        let ok = vault.insert(id: id, kind: VaultKind.macReport, source: name,
                              title: "Inventário do Mac", createdAt: created, payload: json)
        ToastCenter.shared.show(ok ? "Inventário guardado no histórico" : "Este inventário já estava guardado")
    }

    private func openInBrowser() {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("inventario-uptend.html")
        do {
            try rendered.write(to: tmp, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(tmp)
        } catch {
            ToastCenter.shared.show("Não foi possível abrir no navegador")
        }
    }
}
