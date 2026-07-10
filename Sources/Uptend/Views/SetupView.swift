import SwiftUI
import AppKit

struct SetupView: View {
    let sub: SubSection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch sub?.id {
                case "profiles": ProfilesSetupView()
                case "dotfiles": DotfilesSetupView()
                default: FirstRunView()
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
    }
}

// MARK: - Primeira vez (wizard)

struct FirstRunView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var brew: BrewService

    var body: some View {
        Group {
            ScreenHeader(title: "Primeira vez", subtitle: "Um passo a passo para deixar seu Mac pronto")

            step(1, "Homebrew",
                 brew.detected ? "Instalado e pronto." : "Necessário para instalar apps.",
                 systemImage: brew.detected ? "checkmark.circle.fill" : "arrow.down.circle",
                 tint: brew.detected ? .green : .blue,
                 action: brew.detected ? nil : ("Abrir brew.sh", {
                     if let url = URL(string: "https://brew.sh") { NSWorkspace.shared.open(url) }
                 }))

            step(2, "Instalar essenciais",
                 "Escolha seus apps por categoria e instale de uma vez.",
                 systemImage: "star",
                 tint: .blue,
                 action: ("Ir para Essenciais", {
                     state.category = .homebrew
                     state.subID = "essentials"
                 }))

            step(3, "Restaurar um perfil",
                 "Já tem um Brewfile salvo? Reinstale tudo de uma vez.",
                 systemImage: "doc.on.doc",
                 tint: .blue,
                 action: ("Ir para Perfis", {
                     state.category = .setup
                     state.subID = "profiles"
                 }))

            step(4, "Restaurar configs (dotfiles)",
                 "Traga de volta .zshrc, .gitconfig e outras configurações.",
                 systemImage: "terminal",
                 tint: .blue,
                 action: ("Ir para Dotfiles", {
                     state.category = .setup
                     state.subID = "dotfiles"
                 }))

            step(5, "Ajustes do sistema",
                 "Aplique preferências do Finder, Dock e mais.",
                 systemImage: "switch.2",
                 tint: .blue,
                 action: ("Ir para Ajustes", {
                     state.category = .system
                     state.subID = "toggles"
                 }))
        }
    }

    private func step(_ number: Int, _ title: String, _ detail: String, systemImage: String, tint: Color,
                      action: (String, () -> Void)?) -> some View {
        CardRow {
            HStack(spacing: 12) {
                Text("\(number)")
                    .font(.headline).foregroundStyle(.secondary)
                    .frame(width: 24)
                Image(systemName: systemImage).foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).fontWeight(.medium)
                    Text(detail).font(.callout).foregroundStyle(.secondary)
                }
            }
        } trailing: {
            if let action {
                Button(action.0, action: action.1)
            } else {
                EmptyView()
            }
        }
    }
}

// MARK: - Perfis (Brewfile)

struct ProfilesSetupView: View {
    @StateObject private var profiles = ProfilesService()
    @EnvironmentObject var brew: BrewService
    @State private var newName = "meu-setup"

    var body: some View {
        Group {
            ScreenHeader(title: "Perfis (Brewfile)", subtitle: "Salve e restaure a lista de apps do Homebrew") {
                IconButton(systemImage: "arrow.clockwise", help: "Recarregar") { profiles.load() }
            }

            HStack {
                TextField("nome do perfil", text: $newName)
                    .textFieldStyle(.plain).padding(10).cardBackground()
                Button {
                    Task { await brew.dumpBundle(name: newName); profiles.load() }
                } label: {
                    Label("Exportar atual", systemImage: "square.and.arrow.down")
                }
                .disabled(!brew.detected)
            }
            Text("Exporta tudo que está instalado (fórmulas, casks e taps) para um Brewfile.")
                .font(.caption).foregroundStyle(.secondary)

            if profiles.profiles.isEmpty {
                ContentUnavailableView("Nenhum perfil salvo", systemImage: "doc.on.doc").padding(.top, 30)
            } else {
                ForEach(profiles.profiles) { profile in
                    CardRow {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text").foregroundStyle(.secondary)
                            Text(profile.name).fontWeight(.medium)
                        }
                    } trailing: {
                        IconButton(systemImage: "arrow.down.circle", help: "Restaurar (instalar tudo)") {
                            Task { await brew.installBundle(at: profile.url.path, profileName: profile.name) }
                        }
                        IconButton(systemImage: "folder", help: "Mostrar no Finder") { profiles.revealInFinder(profile) }
                        IconButton(systemImage: "trash", help: "Excluir perfil") { profiles.delete(profile) }
                    }
                }
            }
        }
        .task { profiles.load() }
    }
}

// MARK: - Dotfiles

struct DotfilesSetupView: View {
    @StateObject private var dotfiles = DotfilesService()
    @State private var pending: DotfileItem?

    var body: some View {
        Group {
            ScreenHeader(title: "Dotfiles", subtitle: "Restaure suas configurações de um backup") {
                Button("Escolher pasta…") { dotfiles.pickSource() }
            }

            if let source = dotfiles.sourcePath {
                Text("Origem: \(source)").font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            } else {
                Text("Escolha a pasta onde estão seus dotfiles (ex.: um repositório de backup).")
                    .font(.callout).foregroundStyle(.secondary)
            }

            if let message = dotfiles.message {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }

            ForEach(dotfiles.items) { item in
                CardRow {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text").foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).fontWeight(.medium)
                            Text(status(item)).font(.callout).foregroundStyle(.secondary)
                        }
                    }
                } trailing: {
                    if item.inSource {
                        IconButton(systemImage: "arrow.down.circle", help: "Restaurar \(item.name)") {
                            pending = item
                        }
                    } else {
                        EmptyView()
                    }
                }
            }

            if dotfiles.sourcePath != nil {
                Text("Ao restaurar, o arquivo atual é salvo como <nome>.uptend.bak (reversível).")
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
            }
        }
        .confirmationDialog(
            "Restaurar \(pending?.name ?? "")?",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible
        ) {
            if let item = pending {
                Button("Restaurar", role: .destructive) {
                    dotfiles.restore(item)
                    pending = nil
                }
            }
            Button("Cancelar", role: .cancel) { pending = nil }
        } message: {
            Text("O arquivo atual em ~/ vai para um backup .uptend.bak antes de ser substituído.")
        }
    }

    private func status(_ item: DotfileItem) -> String {
        switch (item.inSource, item.inHome) {
        case (true, true): "No backup e no Mac"
        case (true, false): "Só no backup — pode restaurar"
        case (false, true): "Só no Mac (sem backup)"
        default: "—"
        }
    }
}
