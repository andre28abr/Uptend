import SwiftUI
import AppKit

struct ClamAVView: View {
    @EnvironmentObject var clam: ClamAVService
    @EnvironmentObject var brew: BrewService

    @State private var quarantineInfected = true
    @State private var toDelete: URL?
    @State private var showFullScanConfirm = false

    private var threadsHelp: String {
        "Use com cautela conforme o seu Mac. Ele tem \(clam.coreCount) núcleos. "
        + "Mais núcleos deixam o scan mais rápido, porém esquentam mais e podem deixar o Mac lento durante a varredura. "
        + "Recomendado: \(clam.autoThreads) (Auto). Deixe folga de núcleos se for usar o Mac ao mesmo tempo."
    }

    private var scanSummary: String? {
        guard clam.log.hasPrefix("$ clamscan") else { return nil }
        let result = ClamAVService.parseScan(clam.log)
        return "\(result.infected) ameaça(s) encontrada(s)"
    }

    var body: some View {
        Group {
            if clam.installed {
                content
            } else {
                notInstalled
            }
        }
        .task { await clam.detect() }
    }

    // MARK: Não instalado

    private var notInstalled: some View {
        ContentUnavailableView {
            Label("ClamAV não instalado", systemImage: "shield.slash")
        } description: {
            Text("O ClamAV é um antivírus open-source. Instale via Homebrew para escanear e gerenciar por aqui.")
        } actions: {
            Button("Instalar ClamAV via Homebrew") {
                Task { await brew.installToken("clamav", isCask: false) }
            }
            Button("Verificar novamente") { Task { await clam.detect() } }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Instalado

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Antivírus (ClamAV)", subtitle: clam.dbInfo) {
                    if clam.running { ProgressView().controlSize(.small) }
                    IconButton(systemImage: "arrow.clockwise", help: "Atualizar estado") { Task { await clam.detect() } }
                }

                // Atualizar definições
                Button {
                    Task { await clam.updateDefinitions() }
                } label: {
                    Label("Atualizar definições", systemImage: "arrow.down.circle")
                }
                .disabled(clam.running)

                // Modo turbo (daemon)
                if clam.daemonAvailable {
                    CardRow {
                        HStack(spacing: 10) {
                            Image(systemName: clam.daemonRunning ? "bolt.fill" : "bolt.slash")
                                .foregroundStyle(clam.daemonRunning ? .green : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(clam.daemonRunning ? "Modo turbo ativo" : "Modo turbo (daemon)").fontWeight(.medium)
                                Text(clam.daemonRunning
                                     ? "Escaneia usando todos os núcleos, com as definições já na memória."
                                     : "Usa todos os núcleos e mantém as definições na RAM (~1,5 GB). Ótimo para o scan completo.")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    } trailing: {
                        if clam.daemonBusy {
                            ProgressView().controlSize(.small).frame(width: 24, height: 24)
                        } else if clam.daemonRunning {
                            Button("Parar", role: .destructive) { Task { await clam.stopDaemon() } }
                        } else {
                            Button("Iniciar") { Task { await clam.startDaemon() } }.disabled(clam.running)
                        }
                    }

                    Text("Performance").font(.headline).padding(.top, 2)
                    HStack(spacing: 12) {
                        Stepper(value: Binding(get: { clam.effectiveThreads }, set: { clam.threadOverride = $0 }),
                                in: 2...max(2, clam.coreCount)) {
                            Text(clam.usingAutoThreads
                                 ? "Núcleos: \(clam.effectiveThreads) (auto)"
                                 : "Núcleos: \(clam.effectiveThreads) de \(clam.coreCount)")
                                .monospacedDigit()
                        }
                        .frame(maxWidth: 240)
                        .help(threadsHelp)
                        if !clam.usingAutoThreads {
                            Button("Auto") { clam.threadOverride = nil }
                        }
                    }
                    if clam.effectiveThreads > clam.autoThreads {
                        Label("Acima do recomendado para o seu Mac — pode esquentar e deixar o sistema mais lento durante o scan.",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Auto usa ~3/4 dos núcleos (\(clam.autoThreads) no seu Mac) e escala sozinho. A mudança vale ao (re)iniciar o Modo turbo.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                // Escanear
                Text("Escanear").font(.headline).padding(.top, 4)
                HStack(spacing: 8) {
                    Button {
                        Task { await clam.scan(paths: clam.quickScanPaths(), quarantineInfected: quarantineInfected) }
                    } label: {
                        Label("Rápido", systemImage: "bolt")
                    }
                    .tip("Escaneia Downloads, Mesa e arquivos temporários — poucos segundos.")
                    Button {
                        Task { await clam.scan(paths: clam.curatedScanPaths(), quarantineInfected: quarantineInfected) }
                    } label: {
                        Label("Completo", systemImage: "externaldrive")
                    }
                    .tip("Aplicativos, Downloads, Mesa, Documentos e itens de inicialização — rápido e de alto valor contra malware.")
                    Button {
                        showFullScanConfirm = true
                    } label: {
                        Label("Agressivo", systemImage: "flame")
                    }
                    .tip("Pasta pessoal inteira, incluindo caches e dados de apps/navegadores — demorado e esquenta mais.")
                    Button {
                        pickAndScan()
                    } label: {
                        Label("Pasta…", systemImage: "folder")
                    }
                    .tip("Escolher uma pasta específica para escanear.")
                }
                .disabled(clam.running)

                Text("Rápido: Downloads, Mesa e temporários. Completo: Aplicativos, Downloads, Mesa, Documentos e itens de inicialização (rápido, alto valor). Agressivo: pasta pessoal inteira, incluindo caches, dados de apps e navegadores — demorado e esquenta mais.")
                    .font(.caption).foregroundStyle(.secondary)

                Toggle("Mover arquivos infectados para a quarentena", isOn: $quarantineInfected)

                if clam.running {
                    CardRow {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Escaneando… \(ClamAVService.formatDuration(clam.scanElapsed))")
                                    .fontWeight(.medium).monospacedDigit()
                                Text("Só as ameaças aparecem no log; o resumo e o tempo total vêm no fim.")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    } trailing: {
                        Button("Parar", role: .destructive) { clam.cancelScan() }
                    }
                }

                if !clam.configReady {
                    CardRow {
                        HStack(spacing: 10) {
                            Image(systemName: "gearshape").foregroundStyle(.orange)
                            Text("Configuração inicial pendente (freshclam.conf).").font(.callout)
                        }
                    } trailing: {
                        Button("Configurar") { Task { await clam.setupConfig() } }
                    }
                }

                // Resultado da atualização
                if let status = clam.updateStatus {
                    let ok = status.contains("sucesso")
                    CardRow {
                        HStack(spacing: 10) {
                            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(ok ? .green : .orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(status).fontWeight(.medium)
                                if clam.hasHarmlessX509Warning {
                                    Text("Os avisos \"NULL X509 store\" são conhecidos e inofensivos no macOS — o download foi concluído.")
                                        .font(.caption).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    } trailing: { EmptyView() }
                }

                // Log ao vivo
                if !clam.log.isEmpty {
                    if let summary = scanSummary {
                        Text(summary).font(.headline)
                    }
                    Text(clam.log)
                        .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
                }

                // Quarentena
                Text("Quarentena · \(clam.quarantine.count)").font(.headline).padding(.top, 4)
                if clam.quarantine.isEmpty {
                    Text("Nenhum arquivo em quarentena.").font(.callout).foregroundStyle(.secondary)
                } else {
                    ForEach(clam.quarantine, id: \.self) { url in
                        CardRow {
                            HStack(spacing: 10) {
                                Image(systemName: "ant.circle").foregroundStyle(.red)
                                Text(url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                            }
                        } trailing: {
                            IconButton(systemImage: "folder", help: "Mostrar no Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            }
                            IconButton(systemImage: "trash", help: "Excluir permanentemente") { toDelete = url }
                        }
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
        .confirmationDialog(
            "Excluir \(toDelete?.lastPathComponent ?? "") permanentemente?",
            isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }),
            titleVisibility: .visible
        ) {
            if let url = toDelete {
                Button("Excluir", role: .destructive) { clam.deleteQuarantined(url); toDelete = nil }
            }
            Button("Cancelar", role: .cancel) { toDelete = nil }
        } message: {
            Text("Arquivos em quarentena são maliciosos — a exclusão é permanente.")
        }
        .confirmationDialog(
            "Escaneamento agressivo?",
            isPresented: $showFullScanConfirm,
            titleVisibility: .visible
        ) {
            Button("Escanear tudo") {
                Task { await clam.scan(paths: clam.aggressiveScanPaths(), quarantineInfected: quarantineInfected) }
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Verifica os Aplicativos e a pasta pessoal INTEIRA, sem exclusões (inclui caches e dados de dev). Pode levar bastante tempo e esquentar o Mac. Para cobrir pastas protegidas, talvez seja preciso conceder Acesso Total ao Disco ao Uptend nos Ajustes.")
        }
    }

    private func pickAndScan() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Escanear"
        panel.message = "Escolha uma pasta ou arquivo para verificar"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await clam.scan(paths: [url.path], quarantineInfected: quarantineInfected) }
    }
}
