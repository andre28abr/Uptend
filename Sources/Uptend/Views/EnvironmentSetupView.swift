import SwiftUI

// =============================================================================
// PREPARAR AMBIENTE — detecta as ferramentas que o Uptend usa e instala sob
// demanda (1 clique) via o Homebrew que o app já gerencia. Nada é instalado
// silenciosamente: o usuário vê o que falta e aprova.
// =============================================================================

/// Uma ferramenta que o Uptend pode usar, com como detectar e como instalar.
struct EnvTool: Identifiable {
    let id: String          // token do brew
    let name: String
    let purpose: String
    let command: String     // binário para checar presença
    let isCask: Bool
    var installed: Bool { Shell.binaryPath(command) != nil }
}

struct EnvironmentSetupView: View {
    @EnvironmentObject var brew: BrewService
    @State private var refresh = 0     // força re-detecção após instalar

    private let tools: [EnvTool] = [
        EnvTool(id: "git", name: "Git", purpose: "Sincronizar e visualizar repositórios (aba Git)", command: "git", isCask: false),
        EnvTool(id: "docker", name: "Docker", purpose: "Containers e o dashboard BI (Metabase)", command: "docker", isCask: true),
        EnvTool(id: "lynis", name: "Lynis", purpose: "Auditoria de segurança do Mac", command: "lynis", isCask: false),
        EnvTool(id: "clamav", name: "ClamAV", purpose: "Antivírus (aba Segurança)", command: "clamscan", isCask: false),
    ]

    private var brewInstalled: Bool { Shell.binaryPath("brew") != nil }
    private var missing: [EnvTool] { tools.filter { !$0.installed } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Preparar ambiente",
                             subtitle: "Ferramentas que o Uptend usa neste Mac") {
                    IconButton(systemImage: "arrow.clockwise", help: "Verificar de novo") { refresh += 1 }
                    if brewInstalled && !missing.isEmpty {
                        Button { installAll() } label: { Label("Instalar tudo que falta", systemImage: "square.and.arrow.down.on.square") }
                            .disabled(brew.runningBusy)
                    }
                }

                Text("Nada é instalado sem você mandar. As instalações usam o Homebrew, e o Uptend nunca instala em segundo plano.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

                if !brewInstalled {
                    brewMissingBanner
                }

                // Homebrew (base)
                toolRow(name: "Homebrew", purpose: "Gerenciador de pacotes (base para instalar o resto)",
                        installed: brewInstalled, action: nil)

                ForEach(tools) { tool in
                    let _ = refresh   // re-avalia ao mudar
                    toolRow(name: tool.name, purpose: tool.purpose, installed: tool.installed) {
                        install(tool)
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 820, alignment: .leading)
        }
        .onChange(of: brew.runningTitle) { _, now in
            if now == nil { refresh += 1 }   // terminou uma instalação → re-detecta
        }
    }

    private var brewMissingBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Homebrew não encontrado").font(.subheadline).fontWeight(.medium)
                Text("Ele é a base para instalar as demais ferramentas. Instale-o pelo site oficial (o comando abre no Terminal, com sua autorização).")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button { AuditExport.copy("/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"") } label: {
                    Label("Copiar comando de instalação", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private func toolRow(name: String, purpose: String, installed: Bool, action: (() -> Void)?) -> some View {
        CardRow {
            HStack(spacing: 12) {
                Image(systemName: installed ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(installed ? .green : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).fontWeight(.medium)
                    Text(purpose).font(.caption).foregroundStyle(.secondary)
                }
            }
        } trailing: {
            if installed {
                Text("Instalado").font(.caption).foregroundStyle(.green)
            } else if let action {
                Button("Instalar") { action() }
                    .buttonStyle(.borderless)
                    .disabled(!brewInstalled || brew.runningBusy)
            }
        }
    }

    private func install(_ tool: EnvTool) {
        Task { await brew.installToken(tool.id, isCask: tool.isCask) }
    }
    private func installAll() {
        let toInstall = missing
        Task {
            for tool in toInstall { await brew.installToken(tool.id, isCask: tool.isCask) }
        }
    }
}
