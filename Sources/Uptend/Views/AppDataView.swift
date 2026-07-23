import SwiftUI

// =============================================================================
// DADOS DO APP — visão do banco central (UptendVault)
// Mostra o que o Uptend guarda neste Mac (por tipo): quantos registros, quanto
// ocupam, com opção de limpar por tipo ou tudo, e a lista com data/hora.
// =============================================================================

struct AppDataView: View {
    @EnvironmentObject var vault: UptendVault
    @State private var confirmClearAll = false
    @State private var pendingClearKind: String?

    var body: some View {
        // Observa `vault.revision` para atualizar após limpezas/inserções.
        let _ = vault.revision
        let summary = vault.summary()
        let records = vault.records()

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Dados e histórico",
                             subtitle: "Tudo que o Uptend guarda neste Mac · \(sizeLabel(vault.totalBytes()))") {
                    if !records.isEmpty {
                        Button(role: .destructive) { confirmClearAll = true } label: {
                            Label("Limpar tudo", systemImage: "trash")
                        }
                    }
                }

                Text("Os dados ficam só neste Mac, num banco local (SQLite). Nada é enviado para fora.")
                    .font(.callout).foregroundStyle(.secondary)

                if summary.isEmpty {
                    ContentUnavailableView("Nada guardado ainda", systemImage: "cylinder.split.1x2",
                                           description: Text("Auditorias de servidores e inventários do Mac guardados aparecem aqui."))
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    // Resumo por tipo
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 10)], spacing: 10) {
                        ForEach(summary, id: \.kind) { item in
                            typeCard(item.kind, count: item.count, bytes: item.bytes)
                        }
                    }

                    // Lista detalhada (data/hora)
                    Label("Registros", systemImage: "list.bullet").font(.headline).padding(.top, 4)
                    ForEach(records) { rec in recordRow(rec) }
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
        .confirmationDialog("Limpar todos os dados guardados?",
                            isPresented: $confirmClearAll, titleVisibility: .visible) {
            Button("Limpar tudo", role: .destructive) { vault.clear() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Isto apaga todo o histórico do app neste Mac (auditorias e inventários). Não afeta os servidores.")
        }
        .confirmationDialog(pendingClearKind.map { "Limpar \(VaultKind.label($0).lowercased())?" } ?? "",
                            isPresented: Binding(get: { pendingClearKind != nil }, set: { if !$0 { pendingClearKind = nil } }),
                            titleVisibility: .visible) {
            if let k = pendingClearKind {
                Button("Limpar", role: .destructive) { vault.clear(kind: k) }
            }
            Button("Cancelar", role: .cancel) { pendingClearKind = nil }
        }
    }

    private func typeCard(_ kind: String, count: Int, bytes: Int64) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(VaultKind.label(kind), systemImage: VaultKind.icon(kind))
                .font(.callout).fontWeight(.medium)
            HStack {
                Text("\(count) registro\(count == 1 ? "" : "s")").font(.callout).foregroundStyle(.secondary)
                Spacer()
                Text(sizeLabel(bytes)).font(.callout).foregroundStyle(.secondary)
            }
            Button(role: .destructive) { pendingClearKind = kind } label: {
                Label("Limpar", systemImage: "trash").font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private func recordRow(_ rec: VaultRecord) -> some View {
        CardRow {
            HStack(spacing: 10) {
                Image(systemName: VaultKind.icon(rec.kind)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(rec.source).fontWeight(.medium)
                    Text("\(VaultKind.label(rec.kind)) · \(AuditFormat.dateTime(rec.importedAt)) · \(sizeLabel(Int64(rec.sizeBytes)))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } trailing: {
            IconButton(systemImage: "trash", help: "Remover", role: .destructive) { vault.delete(id: rec.id) }
        }
    }

    private func sizeLabel(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
