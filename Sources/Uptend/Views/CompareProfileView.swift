import SwiftUI

struct CompareProfileView: View {
    @StateObject private var profiles = ProfilesService()
    @EnvironmentObject var brew: BrewService

    @State private var selected: BrewProfile?
    @State private var missingBrews: [String] = []
    @State private var missingCasks: [String] = []
    @State private var extra: [(String, Bool)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScreenHeader(title: "Comparar perfil", subtitle: "O que falta ou sobra em relação a um perfil salvo") {
                IconButton(systemImage: "arrow.clockwise", help: "Recarregar") { profiles.load() }
            }

            if profiles.profiles.isEmpty {
                ContentUnavailableView("Nenhum perfil salvo", systemImage: "doc.on.doc").padding(.top, 30)
            } else {
                Picker("Perfil", selection: Binding(get: { selected?.id ?? "" }, set: { id in
                    selected = profiles.profiles.first { $0.id == id }
                    compare()
                })) {
                    Text("Escolha um perfil").tag("")
                    ForEach(profiles.profiles) { Text($0.name).tag($0.id) }
                }
                .frame(maxWidth: 320)

                if selected != nil {
                    section("Faltando — no perfil, mas não instalado", items: missingBrews.map { ($0, false) } + missingCasks.map { ($0, true) },
                            empty: "Nada faltando", installable: true)
                    section("Sobrando — instalado, mas fora do perfil", items: extra,
                            empty: "Nada sobrando", installable: false)
                }
            }
        }
        .task { profiles.load() }
    }

    private func section(_ title: String, items: [(String, Bool)], empty: String, installable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) · \(items.count)").font(.headline).padding(.top, 6)
            if items.isEmpty {
                Text(empty).font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(items, id: \.0) { item in
                    CardRow {
                        HStack(spacing: 10) {
                            Image(systemName: item.1 ? "macwindow" : "terminal").foregroundStyle(.secondary)
                            Text(item.0).fontWeight(.medium)
                        }
                    } trailing: {
                        if installable {
                            IconButton(systemImage: "arrow.down.circle", help: "Instalar \(item.0)") {
                                Task { await brew.installToken(item.0, isCask: item.1) }
                            }
                        } else {
                            IconButton(systemImage: "trash", help: "Desinstalar \(item.0)") {
                                Task { await brew.uninstallToken(item.0, isCask: item.1) }
                            }
                        }
                    }
                }
            }
        }
    }

    private func compare() {
        guard let selected, let content = try? String(contentsOf: selected.url, encoding: .utf8) else {
            missingBrews = []; missingCasks = []; extra = []
            return
        }
        let parsed = ProfilesService.parseBrewfile(content)
        missingBrews = parsed.brews.subtracting(brew.installedFormulae).sorted()
        missingCasks = parsed.casks.subtracting(brew.installedCasks).sorted()
        let extraBrews = brew.installedFormulae.subtracting(parsed.brews).map { ($0, false) }
        let extraCasks = brew.installedCasks.subtracting(parsed.casks).map { ($0, true) }
        extra = (extraBrews + extraCasks).sorted { $0.0 < $1.0 }
    }
}
