import SwiftUI
import AppKit

struct ApplicationsView: View {
    let sub: SubSection?
    @EnvironmentObject var apps: AppsService

    @State private var filter = ""
    @State private var sortBySize = false
    @State private var toUninstall: MacApp?
    @State private var includeResiduals = true

    private var list: [MacApp] {
        let filtered = apps.apps.filter {
            filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter)
        }
        return sortBySize ? filtered.sorted { $0.sizeBytes > $1.sizeBytes } : filtered
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(
                    title: "Aplicativos",
                    subtitle: apps.scanning ? "Analisando…" : "\(apps.apps.count) apps em /Applications"
                ) {
                    if apps.scanning { ProgressView().controlSize(.small) }
                    IconButton(systemImage: sortBySize ? "textformat" : "arrow.up.arrow.down",
                               help: sortBySize ? "Ordenar por nome" : "Ordenar por tamanho") {
                        sortBySize.toggle()
                    }
                    IconButton(systemImage: "arrow.clockwise", help: "Reanalisar") {
                        Task { await apps.scan() }
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Filtrar apps…", text: $filter).textFieldStyle(.plain)
                }
                .padding(10)
                .cardBackground()

                if apps.apps.isEmpty && !apps.scanning {
                    ContentUnavailableView("Nenhum app encontrado", systemImage: "macwindow")
                        .padding(.top, 40)
                } else {
                    VStack(spacing: 8) {
                        ForEach(list) { app in
                            row(app)
                        }
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
        .task {
            if apps.apps.isEmpty { await apps.scan() }
        }
        .confirmationDialog(
            "Desinstalar \(toUninstall?.name ?? "")?",
            isPresented: Binding(get: { toUninstall != nil }, set: { if !$0 { toUninstall = nil } }),
            titleVisibility: .visible
        ) {
            if let app = toUninstall {
                Button("Mover para a Lixeira", role: .destructive) {
                    Task { await apps.uninstall(app, includeResiduals: includeResiduals) }
                    toUninstall = nil
                }
            }
            Button("Cancelar", role: .cancel) { toUninstall = nil }
        } message: {
            if let app = toUninstall {
                let extras = apps.residualURLs(for: app).count
                Text("O app vai para a Lixeira (reversível)."
                     + (includeResiduals && extras > 0 ? " Junto com \(extras) arquivo(s) de configuração/cache." : ""))
            }
        }
    }

    private func row(_ app: MacApp) -> some View {
        CardRow {
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path.path))
                    .resizable().frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).fontWeight(.medium)
                    HStack(spacing: 6) {
                        Image(systemName: app.origin.systemImage).font(.caption2)
                        Text(app.origin.label)
                        Text("·")
                        Text(app.sizeLabel)
                    }
                    .font(.callout).foregroundStyle(.secondary)
                }
            }
        } trailing: {
            IconButton(systemImage: "arrow.up.right.square", help: "Abrir \(app.name)") {
                NSWorkspace.shared.open(app.path)
            }
            IconButton(systemImage: "trash", help: "Desinstalar \(app.name)") {
                toUninstall = app
            }
        }
    }
}
