import SwiftUI
import UptendCore
import AppKit

// MARK: - Card reutilizável: ferramenta não instalada

/// Aparece quando a ferramenta OSS não está instalada — oferece instalar via Homebrew.
struct ScannerMissingCard: View {
    let title: String
    let formula: String
    let explanation: String
    let onRecheck: () -> Void
    @EnvironmentObject var brew: BrewService

    var body: some View {
        ContentUnavailableView {
            Label("\(title) não instalado", systemImage: "shippingbox")
        } description: {
            Text(explanation)
        } actions: {
            Button("Instalar \(formula) via Homebrew") {
                Task { await brew.installToken(formula, isCask: false); onRecheck() }
            }
            .disabled(!brew.detected)
            Button("Verificar novamente", action: onRecheck)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Seletor de alvo comum aos scanners: escolher pasta ou um repositório monitorado.
private struct ScanTargetPicker: View {
    let running: Bool
    let onPick: (String) -> Void
    @EnvironmentObject var git: GitService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.prompt = "Escanear"
                if panel.runModal() == .OK, let url = panel.url { onPick(url.path) }
            } label: {
                Label("Escolher pasta…", systemImage: "folder.badge.magnifyingglass")
            }
            .disabled(running)

            if !git.repos.isEmpty {
                Text("Ou um repositório monitorado:").font(.caption).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(git.repos.filter { $0.isRepo }) { repo in
                            Button(repo.name) { onPick(repo.path) }
                                .buttonStyle(.bordered)
                                .disabled(running)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - gitleaks: segredos nos repositórios

struct SecretScanView: View {
    @StateObject private var scanner = SecretScanService()
    @State private var includeHistory = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Segredos nos repositórios",
                             subtitle: "Procura chaves e tokens commitados por engano (gitleaks)")

                if !scanner.installed {
                    ScannerMissingCard(
                        title: "gitleaks", formula: "gitleaks",
                        explanation: "Ferramenta open-source que varre repositórios em busca de segredos (chaves de API, tokens, chaves privadas). Local, sem rede.",
                        onRecheck: { scanner.detect() })
                        .frame(minHeight: 300)
                } else {
                    ScannerIntro(text: "Chaves e tokens deixados no código (mesmo em commits antigos) podem ser usados por qualquer um que veja o repositório. Escolha uma pasta e verifique. Os segredos aparecem redigidos — o Uptend nunca mostra o valor real.")

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Opções").font(.headline)
                        Toggle("Incluir histórico de commits (mais completo, um pouco mais lento)", isOn: $includeHistory)
                            .disabled(scanner.running)
                        ScanTargetPicker(running: scanner.running) { path in
                            Task { await scanner.scan(path: path, includeHistory: includeHistory) }
                        }
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()

                    if scanner.running {
                        HStack { ProgressView().controlSize(.small); Text("Escaneando \(name(scanner.scannedPath))…").foregroundStyle(.secondary) }
                    }
                    if let error = scanner.lastError {
                        Text(error).font(.callout).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                    }

                    if scanner.didScan && !scanner.running {
                        if scanner.findings.isEmpty && scanner.lastError == nil {
                            Label("Nenhum segredo encontrado em \(name(scanner.scannedPath)).", systemImage: "checkmark.shield.fill")
                                .foregroundStyle(.green)
                        } else if !scanner.findings.isEmpty {
                            Text("\(scanner.findings.count) possível(is) segredo(s) encontrado(s):")
                                .font(.callout).foregroundStyle(.orange)
                            VStack(spacing: 8) {
                                ForEach(scanner.findings) { f in
                                    CardRow {
                                        HStack(spacing: 10) {
                                            Image(systemName: "key.fill").foregroundStyle(.orange)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(ScannerHelp.gitleaksRule(f.ruleID)).fontWeight(.medium)
                                                Text("\(f.file) · linha \(f.startLine)")
                                                    .font(.caption).foregroundStyle(.secondary)
                                                    .lineLimit(1).truncationMode(.middle)
                                            }
                                        }
                                    } trailing: { EmptyView() }
                                }
                            }
                            Text(ScannerHelp.gitleaksFixHint)
                                .font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true).padding(.top, 2)
                        }
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
        .task { scanner.detect() }
    }

    private func name(_ path: String?) -> String {
        path.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "a pasta"
    }
}

/// Cartão de introdução amigável no topo de cada scanner.
private struct ScannerIntro: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle").foregroundStyle(.blue)
            Text(text).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }
}

// MARK: - Lynis: auditoria de endurecimento

struct AuditView: View {
    @StateObject private var audit = AuditService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Auditoria de segurança",
                             subtitle: "Checkup de endurecimento do sistema (Lynis)") {
                    if audit.installed {
                        Button {
                            Task { await audit.run() }
                        } label: {
                            if audit.running { ProgressView().controlSize(.small) } else { Label("Rodar auditoria", systemImage: "play.fill") }
                        }
                        .disabled(audit.running)
                    }
                }

                if !audit.installed {
                    ScannerMissingCard(
                        title: "Lynis", formula: "lynis",
                        explanation: "Ferramenta open-source de auditoria de segurança. Verifica dezenas de configurações e dá um índice de endurecimento com recomendações. Local, sem rede.",
                        onRecheck: { audit.detect() })
                        .frame(minHeight: 300)
                } else {
                    ScannerIntro(text: "O Lynis verifica dezenas de configurações de segurança do Mac e dá uma nota de 0 a 100. Rode a auditoria e veja os avisos (mais urgentes) e as sugestões de melhoria — cada um marcado com a área a que se refere.")

                    if audit.running {
                        HStack { ProgressView().controlSize(.small); Text("Auditando o sistema… (pode levar um minuto)").foregroundStyle(.secondary) }
                    }
                    if let error = audit.lastError {
                        Text(error).font(.callout).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                    }

                    if let index = audit.hardeningIndex {
                        CardRow {
                            HStack(spacing: 12) {
                                Image(systemName: "gauge.with.dots.needle.67percent")
                                    .font(.title2).foregroundStyle(color(for: index))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Índice de endurecimento: \(index)/100").fontWeight(.medium)
                                    Text(label(for: index)).font(.callout).foregroundStyle(.secondary)
                                }
                            }
                        } trailing: { EmptyView() }
                    }

                    if !audit.warnings.isEmpty {
                        section("Avisos", audit.warnings, icon: "exclamationmark.triangle.fill", tint: .orange)
                    }
                    if !audit.suggestions.isEmpty {
                        section("Sugestões", audit.suggestions, icon: "lightbulb", tint: .secondary)
                    }
                    if audit.didRun && !audit.running && audit.warnings.isEmpty && audit.suggestions.isEmpty && audit.lastError == nil {
                        Label("Sem avisos ou sugestões relevantes.", systemImage: "checkmark.shield.fill").foregroundStyle(.green)
                    }
                    if !audit.didRun && audit.lastError == nil {
                        Text("Rode a auditoria para ver o índice e as recomendações. Sem sudo, algumas verificações são limitadas — ainda assim é um bom retrato.")
                            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
        .task { audit.detect() }
    }

    private func section(_ title: String, _ items: [LynisFinding], icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title) (\(items.count))").font(.headline).padding(.top, 6)
            ForEach(items) { item in
                CardRow {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: icon).foregroundStyle(tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.category).font(.caption).fontWeight(.semibold).foregroundStyle(tint)
                            Text(item.text).font(.callout).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } trailing: { EmptyView() }
            }
        }
    }

    private func color(for index: Int) -> Color {
        switch index {
        case ..<50: .red
        case 50..<75: .orange
        default: .green
        }
    }
    private func label(for index: Int) -> String {
        switch index {
        case ..<50: "Vários pontos a reforçar"
        case 50..<75: "Razoável — dá para melhorar"
        default: "Bom nível de endurecimento"
        }
    }
}

// MARK: - osv-scanner: vulnerabilidades de dependências

struct DepsScanView: View {
    @StateObject private var scanner = DepsScanService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Vulnerabilidades de dependências",
                             subtitle: "CVEs conhecidas nas dependências do projeto (osv-scanner)")

                if !scanner.installed {
                    ScannerMissingCard(
                        title: "osv-scanner", formula: "osv-scanner",
                        explanation: "Ferramenta open-source do Google que checa as dependências do seu projeto (npm, pip, cargo, go…) contra a base OSV de vulnerabilidades.",
                        onRecheck: { scanner.detect() })
                        .frame(minHeight: 300)
                } else {
                    ScannerIntro(text: "Aponta para a pasta de um projeto e verifica se as bibliotecas que ele usa (npm, pip, cargo, go…) têm falhas de segurança já conhecidas e publicadas. A correção costuma ser atualizar a dependência.")
                    Label("Esta verificação consulta a base OSV pela internet.", systemImage: "network")
                        .font(.caption).foregroundStyle(.secondary)

                    ScanTargetPicker(running: scanner.running) { path in
                        Task { await scanner.scan(path: path) }
                    }

                    if scanner.running {
                        HStack { ProgressView().controlSize(.small); Text("Consultando vulnerabilidades…").foregroundStyle(.secondary) }
                    }
                    if let error = scanner.lastError {
                        Text(error).font(.callout).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                    }

                    if scanner.didScan && !scanner.running {
                        if scanner.vulns.isEmpty && scanner.lastError == nil {
                            Label("Nenhuma vulnerabilidade conhecida encontrada.", systemImage: "checkmark.shield.fill")
                                .foregroundStyle(.green)
                        } else if !scanner.vulns.isEmpty {
                            Text("\(scanner.vulns.count) vulnerabilidade(s) encontrada(s):")
                                .font(.callout).foregroundStyle(.orange)
                            VStack(spacing: 8) {
                                ForEach(scanner.vulns) { v in
                                    CardRow {
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: "exclamationmark.shield.fill").foregroundStyle(.orange)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("\(v.package) \(v.version)").fontWeight(.medium)
                                                + Text("  ·  \(v.ecosystem)").foregroundColor(.secondary)
                                                Text(ScannerHelp.osvActionHint(package: v.package))
                                                    .font(.callout).foregroundStyle(.secondary)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                Text(v.summary.isEmpty ? v.vulnID : "\(v.vulnID) — \(v.summary)")
                                                    .font(.caption).foregroundStyle(.tertiary)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                    } trailing: { EmptyView() }
                                }
                            }
                        }
                    }
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
        .task { scanner.detect() }
    }
}
