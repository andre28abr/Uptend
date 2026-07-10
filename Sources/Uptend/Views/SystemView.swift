import SwiftUI
import AppKit

struct SystemView: View {
    let sub: SubSection?
    @EnvironmentObject var system: SystemService
    @State private var pendingLoginRemoval: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch sub?.id {
                case "login": loginContent
                case "toggles": togglesContent
                default: infoContent
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
        .task(id: sub?.id) {
            switch sub?.id {
            case "login": await system.loadLoginItems()
            case "toggles": await system.loadToggleStates()
            default: await system.loadInfo()
            }
        }
        .confirmationDialog(
            "Remover \(pendingLoginRemoval ?? "") da inicialização?",
            isPresented: Binding(get: { pendingLoginRemoval != nil }, set: { if !$0 { pendingLoginRemoval = nil } }),
            titleVisibility: .visible
        ) {
            if let name = pendingLoginRemoval {
                Button("Remover", role: .destructive) {
                    Task { await system.removeLoginItem(name) }
                    pendingLoginRemoval = nil
                }
            }
            Button("Cancelar", role: .cancel) { pendingLoginRemoval = nil }
        } message: {
            Text("O app deixa de abrir automaticamente no login. Você pode adicioná-lo de novo depois.")
        }
    }

    // MARK: Informações

    private var infoContent: some View {
        Group {
            ScreenHeader(title: "Informações", subtitle: "Sobre este Mac") {
                if system.loadingInfo { ProgressView().controlSize(.small) }
                IconButton(systemImage: "arrow.clockwise", help: "Atualizar") {
                    Task { await system.loadInfo() }
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                infoCard("Chip", system.info.chip, "cpu")
                infoCard("Memória", system.info.memory, "memorychip")
                infoCard("Núcleos", "\(system.info.cores)", "square.grid.3x3")
                infoCard("Sistema", system.info.osVersion, "apple.logo")
                infoCard("Disco livre", "\(system.info.diskFree) de \(system.info.diskTotal)", "internaldrive")
                infoCard("Ativo há", system.info.uptime, "clock")
                infoCard("Ciclos da bateria", system.info.batteryCycles, "battery.100")
                infoCard("Modelo", system.info.model, "desktopcomputer")
            }
        }
    }

    private func infoCard(_ title: String, _ value: String, _ systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage).font(.title3).foregroundStyle(.secondary)
            Text(value).font(.system(size: 17, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.callout).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    // MARK: Itens de inicialização

    private var loginContent: some View {
        Group {
            ScreenHeader(title: "Itens de inicialização", subtitle: "Apps que abrem ao ligar o Mac") {
                if system.loadingLogin { ProgressView().controlSize(.small) }
                IconButton(systemImage: "gearshape", help: "Abrir nos Ajustes do Sistema") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
                IconButton(systemImage: "arrow.clockwise", help: "Recarregar") {
                    Task { await system.loadLoginItems() }
                }
            }

            if let error = system.loginItemsError {
                CardRow {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(error).font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } trailing: { EmptyView() }
            } else if system.loginItems.isEmpty {
                ContentUnavailableView("Nenhum item de inicialização", systemImage: "power")
                    .padding(.top, 40)
            } else {
                VStack(spacing: 8) {
                    ForEach(system.loginItems, id: \.self) { name in
                        CardRow {
                            HStack(spacing: 12) {
                                Image(systemName: "power").foregroundStyle(.secondary)
                                Text(name).fontWeight(.medium)
                            }
                        } trailing: {
                            IconButton(systemImage: "minus.circle", help: "Remover \(name) da inicialização") {
                                pendingLoginRemoval = name
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Ajustes rápidos

    private var togglesContent: some View {
        Group {
            ScreenHeader(title: "Ajustes rápidos", subtitle: "Preferências do Mac em um clique") {
                IconButton(systemImage: "arrow.clockwise", help: "Recarregar estados") {
                    Task { await system.loadToggleStates() }
                }
            }

            ForEach(SystemService.toggleSections, id: \.self) { section in
                Text(section).font(.headline).padding(.top, 4)
                VStack(spacing: 8) {
                    ForEach(SystemService.toggles.filter { $0.section == section }) { toggle in
                        CardRow {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(toggle.title).fontWeight(.medium)
                                Text(toggle.help).font(.callout).foregroundStyle(.secondary)
                            }
                        } trailing: {
                            Toggle("", isOn: Binding(
                                get: { system.toggleStates[toggle.id] ?? false },
                                set: { newValue in Task { await system.setToggle(toggle, on: newValue) } }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .help(toggle.help)
                        }
                    }
                }
            }
        }
    }
}
