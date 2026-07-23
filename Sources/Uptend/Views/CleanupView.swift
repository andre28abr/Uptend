import SwiftUI

struct CleanupView: View {
    let sub: SubSection?
    @EnvironmentObject var cleanup: CleanupService
    @EnvironmentObject var brew: BrewService

    @State private var pending: CleanupTarget?

    private var totalBytes: Int64 {
        cleanup.targets.reduce(0) { $0 + $1.sizeBytes }
    }

    private var subtitleText: String {
        if cleanup.scanning { return "Analisando…" }
        if let trash = cleanup.targets.first(where: { $0.isEmptyTrash }) {
            let count = trash.count ?? 0
            return count == 0 ? "Lixeira vazia" : "\(count) item(ns) na Lixeira"
        }
        return "Até \(FileUtils.label(totalBytes)) podem ser liberados"
    }

    var body: some View {
        if sub?.id == "space" {
            SpaceAnalyzerView()
        } else {
            cleanupContent
        }
    }

    private var cleanupContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(
                    title: sub?.title ?? "Limpeza",
                    subtitle: subtitleText
                ) {
                    if cleanup.scanning { ProgressView().controlSize(.small) }
                    IconButton(systemImage: "arrow.clockwise", help: "Recalcular tamanhos") {
                        Task { await cleanup.scan(sub?.id ?? "") }
                    }
                }

                VStack(spacing: 8) {
                    ForEach(cleanup.targets) { target in
                        row(target)
                    }
                }

                if !cleanup.targets.isEmpty {
                    Label(
                        "Itens marcados como reversíveis vão para a Lixeira e podem ser recuperados. Esvaziar a Lixeira é permanente.",
                        systemImage: "info.circle"
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
        .task(id: sub?.id) {
            await cleanup.scan(sub?.id ?? "")
        }
        .confirmationDialog(
            pending?.name ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible
        ) {
            if let target = pending {
                Button(target.isReversible ? "Mover para a Lixeira" : "Limpar agora", role: .destructive) {
                    Task { await cleanup.clean(target) }
                    pending = nil
                }
            }
            Button("Cancelar", role: .cancel) { pending = nil }
        } message: {
            if let target = pending {
                Text(target.isReversible
                     ? "Os arquivos vão para a Lixeira (reversível)."
                     : "Esta ação é permanente e não pode ser desfeita.")
            }
        }
    }

    private func row(_ target: CleanupTarget) -> some View {
        CardRow {
            HStack(spacing: 12) {
                Image(systemName: target.isReversible ? "arrow.up.bin" : "trash")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(target.name).fontWeight(.medium)
                    Text(target.detail).font(.callout).foregroundStyle(.secondary)
                }
            }
        } trailing: {
            if !target.isBrewCleanup {
                Text(sizeText(target))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 4)
            }
            if target.isBrewCleanup {
                IconButton(systemImage: "play.fill", help: "Rodar brew cleanup") {
                    Task { await brew.brewCleanup() }
                }
            } else {
                IconButton(systemImage: "trash", help: "Limpar \(target.name)") {
                    pending = target
                }
                .disabled(target.isEmpty)
            }
        }
    }

    private func sizeText(_ target: CleanupTarget) -> String {
        if let count = target.count {
            return "\(count) item(ns)"
        }
        return FileUtils.label(target.sizeBytes)
    }
}
