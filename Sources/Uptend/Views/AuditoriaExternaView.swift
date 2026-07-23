import SwiftUI
import UniformTypeIdentifiers
import UptendCore

// =============================================================================
// AUDITORIA EXTERNA — aba nova (Fase 2)
// Importar/arrastar um arquivo de auditoria (ou rodar o coletor num host SSH) →
// painel (nota, semáforo por categoria, top riscos, hardware/SO, discos, Lynis).
// Toda a nota/semáforo vem de UptendCore (AuditScoring). Sem rede além do SSH.
// =============================================================================

/// Cores do semáforo (verde/amarelo/vermelho) reutilizadas no painel.
extension AuditLight {
    var color: Color {
        switch self {
        case .green: .green
        case .yellow: .yellow
        case .red: .red
        }
    }
}

extension AuditSeverity {
    var color: Color {
        switch self {
        case .ok: .green
        case .low: .blue
        case .medium: .yellow
        case .high: .orange
        case .critical: .red
        }
    }
}

/// Seções da aba Auditoria Externa (barra lateral própria). Área pensada para
/// crescer — futuras ferramentas (relatórios, comparativos, coletor avulso) entram aqui.
enum AuditoriaSection: String, CaseIterable, Identifiable, Hashable {
    case painel, frota, relatorios, bi, importar, historico

    var id: String { rawValue }

    var title: String {
        switch self {
        case .painel: "Painel"
        case .frota: "Frota"
        case .relatorios: "Relatórios"
        case .bi: "Dashboard (BI)"
        case .importar: "Importar / Coletar"
        case .historico: "Histórico"
        }
    }

    var systemImage: String {
        switch self {
        case .painel: "gauge.with.dots.needle.bottom.50percent"
        case .frota: "square.grid.3x3.fill.square"
        case .relatorios: "doc.text"
        case .bi: "chart.bar.xaxis"
        case .importar: "square.and.arrow.down"
        case .historico: "clock.arrow.circlepath"
        }
    }

    var help: String {
        switch self {
        case .painel: "Nota, riscos e semáforo da auditoria carregada"
        case .frota: "Visão consolidada de todos os hosts (nota, heatmap, piores)"
        case .relatorios: "Gerar relatórios (executivo, técnico, SOC) da auditoria"
        case .bi: "Dashboard interativo (Metabase) e exportação de dados"
        case .importar: "Importar um arquivo de auditoria ou coletar de um servidor"
        case .historico: "Auditorias já importadas (comparar no tempo)"
        }
    }

    var subsections: [SubSection] {
        switch self {
        case .painel:
            return [SubSection(id: "painel", title: "Painel", systemImage: "gauge.with.dots.needle.bottom.50percent")]
        case .frota:
            return [SubSection(id: "frota", title: "Frota", systemImage: "square.grid.3x3.fill.square")]
        case .relatorios:
            return [
                SubSection(id: "relatorios", title: "Relatórios", systemImage: "doc.text"),
                SubSection(id: "aceitacao", title: "Aceitação de risco", systemImage: "checkmark.shield"),
                SubSection(id: "baseline", title: "Baseline", systemImage: "ruler"),
                SubSection(id: "branding", title: "Marca / dados da empresa", systemImage: "paintpalette"),
            ]
        case .bi:
            return [SubSection(id: "bi", title: "Dashboard (BI)", systemImage: "chart.bar.xaxis")]
        case .importar:
            return [
                SubSection(id: "importar", title: "Importar / Coletor", systemImage: "square.and.arrow.down"),
                SubSection(id: "coletar", title: "Coletar de servidor", systemImage: "dot.radiowaves.left.and.right"),
                SubSection(id: "banco", title: "Banco de dados", systemImage: "cylinder.split.1x2"),
            ]
        case .historico:
            return [SubSection(id: "historico", title: "Histórico", systemImage: "clock.arrow.circlepath")]
        }
    }
}

// MARK: - Colunas da aba Auditoria Externa

struct AuditoriaSidebar: View {
    @EnvironmentObject var state: AppState

    private var selection: Binding<AuditoriaSection?> {
        Binding(get: { state.auditoriaSection }, set: { if let v = $0 { state.auditoriaSection = v } })
    }

    var body: some View {
        List(selection: selection) {
            Section("Auditoria Externa") {
                ForEach(AuditoriaSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tip(section.help)
                        .tag(section)
                }
            }
        }
        .listStyle(.sidebar)
    }
}

struct AuditoriaContentColumn: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        List(selection: $state.auditoriaSubID) {
            Section(state.auditoriaSection.title) {
                ForEach(state.auditoriaSection.subsections) { sub in
                    Label(sub.title, systemImage: sub.systemImage).tag(sub.id)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(state.auditoriaSection.title)
    }
}

struct AuditoriaDetailColumn: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            switch state.auditoriaSection {
            case .painel: AuditDashboardView()
            case .frota: FleetView()
            case .relatorios:
                switch state.auditoriaSubID {
                case "branding": BrandingView()
                case "aceitacao": RiskAcceptanceView()
                case "baseline": BaselineView()
                default: AuditReportsView()
                }
            case .bi: AuditBIView()
            case .importar:
                switch state.auditoriaSubID {
                case "coletar": AuditCollectServerView()
                case "banco": DatabaseAuditView()
                default: AuditImportView()
                }
            case .historico: AuditHistoryView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Router fino usado por testes/smoke (renderiza cada tela por id de subseção).
struct AuditoriaExternaView: View {
    let sub: SubSection?

    var body: some View {
        switch sub?.id {
        case "importar": AuditImportView()
        case "coletar": AuditCollectServerView()
        case "banco": DatabaseAuditView()
        case "historico": AuditHistoryView()
        default: AuditDashboardView()
        }
    }
}

// MARK: - Importar / Coletar

struct AuditImportView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var service: ExternalAuditService
    @EnvironmentObject var hosts: HostStore
    @State private var targeted = false
    @State private var showInstructions = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Importar / Coletor",
                             subtitle: "Traga um arquivo de auditoria pronto ou gere o coletor para enviar ao cliente") {
                    if service.busy { ProgressView().controlSize(.small) }
                }

                if let err = service.lastError { ErrorBanner(err) { service.lastError = nil } }

                introImport

                // Zona de arrastar (importar um .json já coletado)
                dropZone

                // Gerar o coletor para enviar ao cliente (pen drive / sem SSH)
                standaloneCard

                // Nota honesta (o que o coletor é e não é)
                honestyNote
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
    }

    private var introImport: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.down.doc").foregroundStyle(.blue).font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("Dois caminhos sem SSH").font(.callout).bold()
                Text("**Importar** um arquivo `.json` de auditoria que você já tem em mãos, ou **gerar o coletor** (`.sh`) para o cliente rodar na máquina dele e te devolver o `.json`. Para coletar direto por SSH, use a aba **Coletar de servidor**.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.blue.opacity(0.25), lineWidth: 1))
    }

    private var dropZone: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 34)).foregroundStyle(.secondary)
            Text("Arraste aqui o arquivo `.json` da auditoria")
                .font(.callout).foregroundStyle(.secondary)
            Button {
                importViaPanel()
            } label: {
                Label("Importar arquivo…", systemImage: "folder")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(targeted ? Color.accentColor : Color(nsColor: .separatorColor))
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(targeted ? Color.accentColor.opacity(0.06) : .clear)
        )
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            handleDrop(providers)
        }
    }


    private var standaloneCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Gerar coletor para o cliente", systemImage: "externaldrive.badge.plus")
                .font(.headline)
            Text("Salve o coletor `.sh` e envie ao cliente (e-mail, pen drive…). Ele roda numa máquina isolada, sem acesso SSH, sem instalar nada. Depois é só o cliente te devolver o `.json` gerado e você importa aqui.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button { saveCollector() } label: {
                    Label("Salvar coletor…", systemImage: "square.and.arrow.down")
                }
                Button { showInstructions.toggle() } label: {
                    Label(showInstructions ? "Ocultar instruções" : "Como usar / instruir o cliente", systemImage: "info.circle")
                }
                .buttonStyle(.borderless)
            }
            if showInstructions {
                Text("""
                1. Envie o `audit-collector.sh` ao cliente (ou copie para um pen drive).
                2. No servidor, o cliente roda:  `bash audit-collector.sh`  (ou `sudo bash audit-collector.sh` para auditoria completa).
                3. Ele gera um `uptend-audit-<host>-<data>.json` na pasta atual (e um `.sha256` para conferência).
                4. O cliente te devolve esse `.json` — arraste aqui ou use "Importar arquivo…".
                """)
                .font(.caption).foregroundStyle(.secondary)
                .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                .padding(10).background(Color(nsColor: .textBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private var honestyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.shield").foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 4) {
                Text("O coletor é transparente e read-only").font(.subheadline).fontWeight(.medium)
                Text("Ele só lê a configuração (não instala, não altera, não abre conexões de saída) e gera um arquivo com hash SHA-256. Rode apenas em servidores que você tem autorização para auditar.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    // MARK: Ações

    private func importViaPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            if service.importFile(url) { state.auditoriaSection = .painel }
        }
    }

    private func saveCollector() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "audit-collector.sh"
        panel.canCreateDirectories = true
        panel.title = "Salvar coletor de auditoria"
        if panel.runModal() == .OK, let url = panel.url {
            service.exportCollector(to: url)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in
                if service.importFile(url) { state.auditoriaSection = .painel }
            }
        }
        return true
    }
}

// MARK: - Banco de dados (subseção própria) — FASE E4 (v1: SQLite, modo estrutura)

struct DatabaseAuditView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var service: ExternalAuditService
    @State private var schema: DatabaseSchema?
    @State private var loadedURL: URL?
    @State private var completeMode = false
    @State private var error: String?
    @State private var targeted = false
    // Materializados (M5): recalculados só no load() e ao alternar o modo — não a cada
    // render, que releria o SQLite (I/O + amostragem de dado sensível) repetidamente.
    @State private var passwordSamples: [String: [String]] = [:]
    @State private var findings: [AuditFinding] = []

    private var openCount: Int { findings.filter { $0.severity > .ok }.count }

    /// Lê as amostras (só no modo completo) e deriva os achados, uma vez.
    private func recompute() {
        guard let sc = schema else { passwordSamples = [:]; findings = []; return }
        if completeMode, let url = loadedURL {
            passwordSamples = SQLiteSchemaReader.samplePasswordColumns(fileURL: url, schema: sc)
        } else {
            passwordSamples = [:]
        }
        findings = DatabaseAudit.findings(from: sc, passwordSamples: passwordSamples)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Banco de dados", subtitle: "Auditoria de estrutura (LGPD-safe) — nunca lê os dados")
                if let error { ErrorBanner(error) { self.error = nil } }

                privacyBanner
                dropZone
                if let schema {
                    schemaCard(schema)
                    completeModeCard
                    findingsCard
                }
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
        .onChange(of: completeMode) { recompute() }
    }

    private var privacyBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill").foregroundStyle(.green).font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("Modo estrutura — privacidade por design").font(.callout).bold()
                Text("O Uptend lê **apenas a estrutura** do banco (tabelas, colunas, tipos, chaves, índices). **Nunca executa consulta em dados** — é tecnicamente impossível ver um registro. Aponta o que merece verificação para LGPD: colunas com cara de dado pessoal em texto plano, senha sem hash, etc. Nada do arquivo é armazenado — só os achados.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.green.opacity(0.25), lineWidth: 1))
    }

    private var dropZone: some View {
        VStack(spacing: 10) {
            Image(systemName: "cylinder.split.1x2").font(.system(size: 32)).foregroundStyle(.secondary)
            Text("Arraste um arquivo SQLite (`.db`, `.sqlite`, `.sqlite3`)").font(.callout).foregroundStyle(.secondary)
            Button { pick() } label: { Label("Escolher arquivo de banco…", systemImage: "folder") }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 30)
        .background(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            .foregroundStyle(targeted ? Color.accentColor : Color(nsColor: .separatorColor)))
        .background(RoundedRectangle(cornerRadius: 12).fill(targeted ? Color.accentColor.opacity(0.06) : .clear))
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            _ = providers.first?.loadObject(ofClass: URL.self) { url, _ in
                if let url { DispatchQueue.main.async { load(url) } }
            }
            return true
        }
    }

    private func schemaCard(_ schema: DatabaseSchema) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Estrutura lida — \(schema.name)", systemImage: "cylinder.split.1x2").font(.headline)
            Text("\(schema.tables.count) tabela(s) · \(schema.columnCount) coluna(s) · motor \(schema.engine).")
                .font(.callout).foregroundStyle(.secondary)
            Text(schema.tables.map(\.name).prefix(12).joined(separator: " · ") + (schema.tables.count > 12 ? " …" : ""))
                .font(.caption2).foregroundStyle(.tertiary).lineLimit(2)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private var completeModeCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $completeMode) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Modo completo — amostrar dados (só banco próprio)").font(.callout)
                    Text("Lê algumas amostras APENAS das colunas de senha, em memória (nunca armazena), para confirmar se estão com hash ou em texto plano. Use só em bancos que você tem autorização para inspecionar os dados.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }.toggleStyle(.checkbox)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private var findingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Achados (\(openCount))\(completeMode ? " · modo completo" : "")", systemImage: "checklist").font(.headline)
                Spacer()
                Button {
                    let iso = ISO8601DateFormatter().string(from: Date())
                    if let sc = schema, service.ingestAudit(DatabaseAudit.makeAudit(from: sc, collectedAt: iso, passwordSamples: passwordSamples), suggestedName: sc.name) {
                        state.auditoriaSection = .painel
                    } else { error = service.lastError ?? "Não consegui adicionar." }
                } label: { Label("Adicionar à auditoria", systemImage: "plus.rectangle.on.folder") }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
            if openCount == 0 {
                Text("Nenhum achado na estrutura. 🎉 O banco vira uma auditoria conforme.").font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(findings.filter { $0.severity > .ok }) { f in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(sevColor(f.severity)).frame(width: 9, height: 9).padding(.top, 5)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.title).font(.callout)
                            if let r = f.recommendation { Text(r).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                        }
                        Spacer()
                        Text(f.severity.label).font(.caption2).bold().foregroundStyle(sevColor(f.severity))
                    }
                    .padding(.vertical, 3)
                    Divider()
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private func sevColor(_ s: AuditSeverity) -> Color {
        switch s { case .critical: .red; case .high: .orange; case .medium: .yellow; case .low: .blue; case .ok: .green }
    }

    private func pick() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = ["db", "sqlite", "sqlite3", "db3"].compactMap { UTType(filenameExtension: $0) }
        panel.allowsOtherFileTypes = true
        if panel.runModal() == .OK, let url = panel.url { load(url) }
    }

    private func load(_ url: URL) {
        do { schema = try SQLiteSchemaReader.read(fileURL: url); loadedURL = url; error = nil }
        catch { self.error = error.localizedDescription; schema = nil; loadedURL = nil }
        recompute()
    }
}

// MARK: - Coletar de servidor (subseção própria)

struct AuditCollectServerView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var service: ExternalAuditService
    @EnvironmentObject var hosts: HostStore
    @State private var runLynis = false
    @State private var scanAuthorized = false
    @State private var activeScan = false
    @State private var scanPorts = "22, 80, 443, 8080, 8443, 993, 465, 3306, 5432, 6379"
    @State private var scanning = false
    @State private var doneMsg: String?
    @State private var selectedHostID: RemoteHost.ID?
    @State private var collectFleet = false
    @State private var auditDB = false

    private var ports: [Int] {
        scanPorts.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }.filter { (1...65535).contains($0) }
    }
    private var working: Bool { service.busy || scanning }
    private var busyText: String? { scanning ? "Varredura ativa de TLS em andamento…" : service.busyMessage }
    private var selectedHost: RemoteHost? { hosts.hosts.first { $0.id == selectedHostID } ?? hosts.hosts.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Coletar de servidor",
                             subtitle: "Roda o coletor por SSH num host cadastrado e traz o resultado") {
                    if working { ProgressView().controlSize(.small) }
                    if !hosts.hosts.isEmpty { hostPicker }
                }
                if let err = service.lastError { ErrorBanner(err) { service.lastError = nil } }

                if working, let msg = busyText { busyBanner(msg) }
                optionsCard
                collectCard
                honesty
            }
            .screenPadding()
            .frame(maxWidth: 860, alignment: .leading)
        }
    }

    /// Seletor de servidor no cabeçalho — mesmo padrão do de Relatórios (harmonia).
    private var hostPicker: some View {
        Menu {
            ForEach(hosts.hosts) { host in
                Button { selectedHostID = host.id } label: {
                    if selectedHost?.id == host.id {
                        Label("\(host.name) · \(host.user)@\(host.address)", systemImage: "checkmark")
                    } else {
                        Text("\(host.name) · \(host.user)@\(host.address)")
                    }
                }
            }
        } label: {
            Label(collectFleet ? "Toda a frota" : (selectedHost?.name ?? "Selecionar servidor"), systemImage: "desktopcomputer")
        }
        .menuStyle(.borderlessButton).fixedSize().disabled(working || collectFleet)
        .help("Escolher qual servidor cadastrado coletar")
    }

    private func busyBanner(_ msg: String) -> some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text(msg).font(.callout)
            Spacer()
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Opções da coleta", systemImage: "slider.horizontal.3").font(.headline)
            Toggle(isOn: $runLynis) {
                Text("Rodar Lynis (auditoria completa — mais lenta, 1–2 min)").font(.callout)
            }.toggleStyle(.checkbox)
            Text(runLynis
                 ? "O Lynis será executado no servidor para gerar o índice de endurecimento (leva alguns minutos)."
                 : "Sem Lynis a coleta é rápida (segundos). Se o Lynis já foi rodado antes no servidor, o resultado existente é aproveitado.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

            Divider().padding(.vertical, 4)

            // Varredura ativa (opt-in, exige autorização)
            Toggle(isOn: $scanAuthorized) {
                Text("Tenho autorização para varredura ativa deste alvo").font(.callout)
            }
            .toggleStyle(.checkbox)
            .onChange(of: scanAuthorized) { _, v in if !v { activeScan = false } }

            Toggle(isOn: $activeScan) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Rodar varredura ativa de TLS junto").font(.callout)
                    Text("Sondagem ATIVA das portas (conecta no alvo — pode aparecer em IDS/IPS e logs). Habilite a autorização acima para liberar.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.checkbox)
            .disabled(!scanAuthorized)

            if activeScan {
                TextField("portas da varredura (separadas por vírgula)", text: $scanPorts)
                    .textFieldStyle(.roundedBorder).font(.callout)
            }

            Divider().padding(.vertical, 4)

            // Auditoria de banco de dados (só estrutura — LGPD-safe)
            Toggle(isOn: $auditDB) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Auditar bancos de dados (só estrutura — LGPD-safe)").font(.callout)
                    Text("Lê apenas o schema do PostgreSQL no servidor (information_schema) — nunca consulta dados. Aponta colunas com cara de PII em texto plano, senha sem hash, etc.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }.toggleStyle(.checkbox)

            if hosts.hosts.count > 1 {
                Divider().padding(.vertical, 4)
                Toggle(isOn: $collectFleet) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Coletar de toda a frota (\(hosts.hosts.count) servidores)").font(.callout)
                        Text("Roda a coleta em cada host cadastrado, um a um (com as opções acima). O painel consolidado — nota média, heatmap host×área e os piores — fica na aba **Frota**.")
                            .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }.toggleStyle(.checkbox)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private var collectCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(collectFleet ? "Coletar a frota" : "Coletar servidor", systemImage: "server.rack").font(.headline)
                Spacer()
                if !hosts.hosts.isEmpty {
                    Button { state.auditoriaSection = .frota } label: {
                        Label("Abrir painel da Frota", systemImage: "square.grid.3x3.fill.square")
                    }.buttonStyle(.borderless).controlSize(.small)
                        .help("Visão consolidada (nota média, heatmap, piores) na aba Frota")
                }
            }
            if hosts.hosts.isEmpty {
                Text("Nenhum host cadastrado ainda. Cadastre um servidor (ou HomeLab) na barra superior do app para poder coletar por SSH.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                // Caixinha de explicação (o que o botão faz)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill").foregroundStyle(.blue)
                    Text(explainText)
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .padding(11).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))

                // Botão de iniciar (embaixo)
                HStack(spacing: 10) {
                    Button {
                        if collectFleet { Task { await collectAll() } }
                        else if let h = selectedHost { Task { await collect(h) } }
                    } label: {
                        Label(working ? (busyText ?? "Trabalhando…")
                              : (collectFleet ? "Iniciar coleta da frota (\(hosts.hosts.count))"
                                              : "Iniciar coleta em \(selectedHost?.name ?? "…")"),
                              systemImage: "bolt.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(working || (!collectFleet && selectedHost == nil))
                    if working { ProgressView().controlSize(.small) }
                    Spacer()
                }
            }
            if let doneMsg { Text(doneMsg).font(.callout).foregroundStyle(.green) }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    /// Coleta por SSH e, se a varredura ativa estiver marcada, sonda o TLS e mescla na auditoria do host.
    @MainActor
    private func collect(_ host: RemoteHost) async {
        doneMsg = nil
        await service.runCollector(on: host, runLynis: runLynis, auditDB: auditDB)
        guard service.lastError == nil, let target = service.selected else {
            state.auditoriaSection = .painel; return
        }
        if activeScan, !ports.isEmpty {
            scanning = true
            var results: [TLSProbeResult] = []
            for p in ports { results.append(await TLSScanner.probe(host: host.address, port: p)) }
            let findings = TLSScanner.findings(from: results)
            if !findings.isEmpty { service.mergeScanFindings(findings, into: target) }
            scanning = false
            doneMsg = "Coleta + varredura de \(host.name) concluídas — painel e relatórios atualizados."
        }
        state.auditoriaSection = .painel
    }

    /// Coleta de toda a frota (um host por vez) e abre o painel consolidado.
    @MainActor
    private func collectAll() async {
        doneMsg = nil
        var ok = 0, fail = 0
        for host in hosts.hosts {
            await service.runCollector(on: host, runLynis: runLynis, auditDB: auditDB)
            if service.lastError != nil { fail += 1; service.lastError = nil; continue }
            ok += 1
            if activeScan, !ports.isEmpty, let target = service.selected {
                scanning = true
                var results: [TLSProbeResult] = []
                for p in ports { results.append(await TLSScanner.probe(host: host.address, port: p)) }
                let findings = TLSScanner.findings(from: results)
                if !findings.isEmpty { service.mergeScanFindings(findings, into: target) }
                scanning = false
            }
        }
        doneMsg = "Frota coletada: \(ok) ok" + (fail > 0 ? " · \(fail) com falha" : "") + ". Veja o consolidado na aba Frota."
        state.auditoriaSection = .frota
    }

    private var explainText: String {
        let scan = activeScan ? "A varredura ativa de TLS roda em seguida em cada host e os achados entram na auditoria dele. " : ""
        if collectFleet {
            return "Coleta todos os \(hosts.hosts.count) servidores cadastrados, um a um, com as opções acima. \(scan)Ao terminar, abre o painel da Frota com o consolidado (nota média, heatmap, piores). Nada é alterado nos servidores."
        }
        return "Escolha o servidor no seletor do topo e clique em Iniciar coleta: o Uptend conecta por SSH e coleta com as opções acima. \(scan)Nada é alterado no servidor."
    }

    private var honesty: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.shield").foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 4) {
                Text("Coleta transparente e read-only").font(.subheadline).fontWeight(.medium)
                Text("Só lê a configuração (não instala, não altera, não abre conexões de saída) e gera um arquivo com hash SHA-256. Rode apenas em servidores que você tem autorização para auditar.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }
}

// MARK: - Histórico

struct AuditHistoryView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var service: ExternalAuditService
    @EnvironmentObject var branding: BrandingStore
    @EnvironmentObject var riskExceptions: RiskExceptionStore   // nota efetiva (desconta aceitos)
    @State private var confirmClear = false
    @State private var compareHTML: String?

    /// Auditorias agrupadas por servidor (mais antigas → mais novas), para a evolução.
    private var byHost: [(host: String, items: [LoadedAudit])] {
        let groups = Dictionary(grouping: service.audits, by: \.hostname)
        return groups.map { (host: $0.key, items: $0.value.sorted { $0.importedAt < $1.importedAt }) }
            .sorted { $0.host.localizedCaseInsensitiveCompare($1.host) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Histórico",
                             subtitle: "\(service.audits.count) auditoria(s) · \(sizeLabel) · guardadas por \(service.retentionDays) dias") {
                    IconButton(systemImage: "arrow.clockwise", help: "Recarregar") { service.reload() }
                    if !service.audits.isEmpty {
                        Button(role: .destructive) { confirmClear = true } label: {
                            Label("Limpar", systemImage: "trash")
                        }
                    }
                }

                if service.audits.isEmpty {
                    ContentUnavailableView("Nenhuma auditoria ainda",
                                           systemImage: "clock.arrow.circlepath",
                                           description: Text("Importe um arquivo ou colete de um servidor na aba Importar."))
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    // Evolução da saúde por servidor (só quando há ≥2 coletas do mesmo host).
                    let trends = byHost.filter { $0.items.count >= 2 }
                    if !trends.isEmpty {
                        Label("Saúde ao longo do tempo", systemImage: "chart.xyaxis.line").font(.headline)
                        ForEach(trends, id: \.host) { g in trendRow(g.host, g.items) }
                    }

                    Label("Todas as auditorias", systemImage: "list.bullet").font(.headline).padding(.top, 4)
                    ForEach(service.audits) { item in row(item) }
                }
            }
            .screenPadding()
            .frame(maxWidth: 820, alignment: .leading)
        }
        .confirmationDialog("Limpar todo o histórico de auditorias?",
                            isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Limpar tudo", role: .destructive) { service.clearAll() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Isto apaga todas as auditorias guardadas neste Mac. Os servidores não são afetados.")
        }
        .sheet(isPresented: Binding(get: { compareHTML != nil }, set: { if !$0 { compareHTML = nil } })) {
            if let html = compareHTML { AuditReportPreview(html: html) }
        }
    }

    private var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: service.storageBytes(), countStyle: .file)
    }

    private func trendRow(_ host: String, _ items: [LoadedAudit]) -> some View {
        // Nota efetiva (desconta riscos aceitos) — igual aos relatórios (M3).
        let es = items.map { riskExceptions.effectiveScore($0.audit) }
        let scores = es.map { Double($0.score) }
        let first = es.first!.score
        let last = es.last!.score
        let lastLight = es.last!.light
        let delta = last - first
        return CardRow {
            HStack(spacing: 12) {
                ScoreBadge(score: last, light: lastLight, compact: true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(host).fontWeight(.medium)
                    HStack(spacing: 6) {
                        Text("\(items.count) coletas")
                        if delta != 0 {
                            Label("\(delta > 0 ? "+" : "")\(delta)", systemImage: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                                .foregroundStyle(delta > 0 ? .green : .orange)
                        } else {
                            Text("estável")
                        }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
            }
        } trailing: {
            Sparkline(values: scores, tint: lastLight.color, maxValue: 100)
                .frame(width: 90, height: 30)
            Button("Comparar") {
                compareHTML = AuditReport.comparisonHTML(previous: items[items.count - 2].audit,
                                                         current: items.last!.audit, branding: branding.forReports)
            }
            .buttonStyle(.borderless)
            .help("Comparar as duas últimas coletas deste servidor")
        }
    }

    private func row(_ item: LoadedAudit) -> some View {
        let s = riskExceptions.effectiveScore(item.audit)
        return CardRow {
            HStack(spacing: 12) {
                ScoreBadge(score: s.score, light: s.light, compact: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.hostname).fontWeight(.medium)
                    Text("\(item.audit.os?.pretty ?? item.audit.os?.distro ?? "—") · coletado \(AuditFormat.dateTime(item.audit.collectedAt))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } trailing: {
            Button("Abrir") { service.selectedID = item.id; state.auditoriaSection = .painel }
                .buttonStyle(.borderless)
            IconButton(systemImage: "trash", help: "Remover", role: .destructive) { service.remove(item) }
        }
    }
}

/// Formatação de data/hora dos relatórios (mostra data E hora para distinguir coletas
/// feitas em sequência). `collected_at` vem em UTC (ISO); convertemos para o fuso local.
enum AuditFormat {
    static func dateTime(_ iso: String) -> String {
        let parser = ISO8601DateFormatter()
        guard let date = parser.date(from: iso) else { return String(iso.prefix(16)).replacingOccurrences(of: "T", with: " ") }
        return dateTime(date)
    }
    static func dateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "dd/MM/yyyy 'às' HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Seletor de servidor (menu em cascata) — usado no Painel e em Relatórios

/// Menu em cascata para escolher qual servidor (auditoria do histórico) está em foco.
/// Troca `service.selectedID` — Painel e Relatórios refletem a escolha na hora.
struct AuditHostPicker: View {
    @EnvironmentObject var service: ExternalAuditService

    /// Auditorias agrupadas por host (host alfabético, coleta mais recente primeiro).
    private var ordered: [LoadedAudit] {
        service.audits.sorted {
            if $0.hostname != $1.hostname {
                return $0.hostname.localizedCaseInsensitiveCompare($1.hostname) == .orderedAscending
            }
            return $0.audit.collectedAt > $1.audit.collectedAt
        }
    }

    var body: some View {
        Menu {
            if ordered.isEmpty {
                Text("Nenhuma auditoria no histórico")
            } else {
                ForEach(ordered) { item in
                    Button {
                        service.selectedID = item.id
                    } label: {
                        if service.selected?.id == item.id {
                            Label("\(item.hostname)  ·  \(AuditFormat.dateTime(item.audit.collectedAt))", systemImage: "checkmark")
                        } else {
                            Text("\(item.hostname)  ·  \(AuditFormat.dateTime(item.audit.collectedAt))")
                        }
                    }
                }
            }
        } label: {
            Label(service.selected?.hostname ?? "Selecionar servidor", systemImage: "desktopcomputer")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Escolher qual servidor do histórico exibir")
    }
}

// MARK: - Painel (dashboard)

struct AuditDashboardView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var service: ExternalAuditService
    @EnvironmentObject var riskExceptions: RiskExceptionStore   // nota efetiva (desconta aceitos)

    var body: some View {
        Group {
            if let item = service.selected {
                content(item)
            } else {
                ContentUnavailableView {
                    Label("Nenhuma auditoria carregada", systemImage: "chart.bar.doc.horizontal")
                } description: {
                    Text("Importe um arquivo ou colete de um servidor.")
                } actions: {
                    Button("Ir para Importar") { state.auditoriaSection = .importar }
                }
            }
        }
    }

    private func content(_ item: LoadedAudit) -> some View {
        let audit = item.audit
        let s = riskExceptions.effectiveScore(item.audit)   // desconta riscos aceitos (M3)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: audit.host.hostname,
                             subtitle: "\(audit.os?.pretty ?? "SO desconhecido") · coletado \(AuditFormat.dateTime(audit.collectedAt)) · modo \(audit.collector.mode)") {
                    AuditHostPicker()
                }

                // Nota + resumo por severidade
                HStack(alignment: .top, spacing: 14) {
                    ScoreBadge(score: s.score, light: s.light, compact: false)
                    severitySummary(s)
                }

                // Desvio (drift) desde a última coleta do mesmo host
                driftBanner(item)

                // Top riscos
                if !s.topRisks.isEmpty {
                    sectionTitle("Principais riscos", "exclamationmark.triangle")
                    VStack(spacing: 8) { ForEach(s.topRisks) { finding(($0)) } }
                }

                // Semáforo por categoria
                sectionTitle("Categorias", "square.grid.2x2")
                categoryGrid(s)

                // Perfil do servidor (para que serve)
                if let p = audit.profile, !p.purposes.isEmpty {
                    sectionTitle("Para que serve este servidor", "target")
                    profileCard(p)
                }

                // Docker / containers
                if let dk = audit.docker, dk.installed, !dk.containers.isEmpty {
                    sectionTitle("Docker · \(dk.running ?? 0)/\(dk.total ?? 0) ativos", "shippingbox")
                    VStack(spacing: 8) { ForEach(dk.containers) { containerRow($0) } }
                }

                // Máquina / SO / hardware
                sectionTitle("Máquina e sistema", "cpu")
                machineCards(audit)

                // Discos
                if !audit.disks.isEmpty {
                    sectionTitle("Discos", "internaldrive")
                    VStack(spacing: 8) { ForEach(audit.disks) { diskRow($0) } }
                }

                // Lynis
                if let lynis = audit.lynis, lynis.available {
                    sectionTitle("Lynis", "list.bullet.clipboard")
                    lynisCard(lynis)
                }

                // Todos os achados
                sectionTitle("Todos os achados (\(audit.findings.count))", "checklist")
                VStack(spacing: 8) {
                    ForEach(audit.findings.sorted { $0.severity > $1.severity }) { finding($0) }
                }
            }
            .screenPadding()
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private func sectionTitle(_ text: String, _ icon: String) -> some View {
        Label(text, systemImage: icon).font(.headline).padding(.top, 4)
    }

    /// Banner de desvio (drift) comparando esta coleta com a anterior do mesmo host.
    @ViewBuilder
    private func driftBanner(_ item: LoadedAudit) -> some View {
        if let prev = service.previousAudit(for: item) {
            let drift = DriftAnalysis.analyze(previous: prev.audit, current: item.audit)
            let color = driftColor(drift.level)
            let icon: String = {
                switch drift.level {
                case .melhorou: "arrow.up.forward.circle.fill"
                case .estavel: "equal.circle.fill"
                case .atencao: "exclamationmark.triangle.fill"
                case .critico: "exclamationmark.octagon.fill"
                }
            }()
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon).foregroundStyle(color).font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Desvio desde a última coleta: \(drift.level.rawValue)").font(.callout).bold()
                        Text(scoreDeltaLabel(drift.scoreDelta)).font(.caption).foregroundStyle(color)
                    }
                    Text("Comparado com \(AuditFormat.dateTime(prev.audit.collectedAt)) · " + drift.reasons.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if !drift.newSevere.isEmpty {
                        ForEach(drift.newSevere.prefix(4)) { f in
                            Text("• novo: \(f.title) (\(f.severity.label))")
                                .font(.caption2).foregroundStyle(color)
                        }
                    }
                }
                Spacer()
                Button { state.auditoriaSection = .historico } label: { Label("Histórico", systemImage: "clock.arrow.circlepath") }
                    .buttonStyle(.borderless).controlSize(.small)
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color.opacity(0.35), lineWidth: 1))
        }
    }

    private func driftColor(_ l: DriftLevel) -> Color {
        switch l {
        case .melhorou: .green
        case .estavel: .secondary
        case .atencao: .orange
        case .critico: .red
        }
    }

    private func scoreDeltaLabel(_ d: Int) -> String {
        d > 0 ? "▲ +\(d)" : (d < 0 ? "▼ \(d)" : "sem mudança na nota")
    }

    private func severitySummary(_ s: AuditScore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach([AuditSeverity.critical, .high, .medium, .low, .ok], id: \.self) { sev in
                let n = s.counts[sev] ?? 0
                HStack(spacing: 8) {
                    StatusDot(color: sev.color)
                    Text(sev.label).font(.callout)
                    Spacer()
                    Text("\(n)").font(.callout).fontWeight(.medium).foregroundStyle(n > 0 ? .primary : .secondary)
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private func categoryGrid(_ s: AuditScore) -> some View {
        let cols = [GridItem(.adaptive(minimum: 200), spacing: 8)]
        return LazyVGrid(columns: cols, spacing: 8) {
            ForEach(s.categories) { cat in
                HStack(spacing: 8) {
                    StatusDot(color: cat.light.color)
                    Text(cat.category).font(.callout).lineLimit(1)
                    Spacer()
                    Text("\(cat.count)").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 10).cardBackground()
            }
        }
    }

    private func finding(_ f: AuditFinding) -> some View {
        CardRow {
            HStack(alignment: .top, spacing: 10) {
                StatusDot(color: f.severity.color).padding(.top, 5)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(f.title).fontWeight(.medium)
                        if let cis = f.cis {
                            Text("CIS \(cis)").font(.caption2)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(.blue.opacity(0.12), in: Capsule()).foregroundStyle(.blue)
                        }
                    }
                    if let ev = f.evidence, !ev.isEmpty {
                        Text(ev).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    if f.severity > .ok, let imp = f.businessImpact, !imp.isEmpty {
                        Text(imp).font(.caption).foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if f.severity > .ok, let rec = f.recommendation, !rec.isEmpty {
                        Label(rec, systemImage: "wrench.and.screwdriver")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        } trailing: {
            Text(f.severity.label).font(.caption).foregroundStyle(f.severity.color)
        }
    }

    private func machineCards(_ audit: ExternalAudit) -> some View {
        let cols = [GridItem(.adaptive(minimum: 220), spacing: 8)]
        return LazyVGrid(columns: cols, spacing: 8) {
            infoCard("Máquina", (audit.machine?.virtual == true ? "Virtual" : "Física"),
                     detail: [audit.machine?.vendor, audit.machine?.model].compactMap { $0 }.joined(separator: " "),
                     icon: audit.machine?.virtual == true ? "cube.transparent" : "pc")
            infoCard("CPU", audit.machine?.cpuModel ?? "—",
                     detail: audit.machine?.cpuCores.map { "\($0) núcleos" } ?? "",
                     icon: "cpu")
            infoCard("Memória", ramLabel(audit.machine?.ramBytes), detail: "", icon: "memorychip")
            infoCard("Kernel", audit.os?.kernel ?? "—", detail: audit.os?.distro ?? "", icon: "cpu.fill")
            if let eol = audit.os?.eolDate {
                infoCard("Fim de suporte (SO)", eol,
                         detail: isPast(eol) ? "FORA DE SUPORTE" : "com suporte",
                         icon: "calendar.badge.exclamationmark",
                         tint: isPast(eol) ? .red : .green)
            }
            if let up = audit.os?.uptimeSeconds {
                infoCard("Ligado há", LinuxStats.humanUptime(up), detail: "", icon: "clock")
            }
            if let pct = audit.resources?.diskRootPercent {
                infoCard("Uso do disco (/)", "\(pct)%",
                         detail: audit.resources?.diskRootFreeBytes.map { "\(sizeLabel($0) ?? "—") livres" } ?? "",
                         icon: "internaldrive", tint: pct >= 85 ? .red : .secondary)
            }
            if audit.resources?.rebootRequired == true {
                infoCard("Reinício", "Pendente", detail: "atualizações aguardando", icon: "arrow.clockwise.circle", tint: .orange)
            }
            if let ts = audit.resources?.timeSynced {
                infoCard("Relógio (NTP)", ts ? "Sincronizado" : "Fora de sincronia", detail: "", icon: "clock.badge.checkmark", tint: ts ? .secondary : .orange)
            }
            if let n = audit.users?.loginUsers {
                infoCard("Contas com login", "\(n)", detail: audit.users?.sudoUsers.isEmpty == false ? "sudo: \(audit.users!.sudoUsers.joined(separator: ", "))" : "", icon: "person.2")
            }
        }
    }

    private func profileCard(_ p: ExternalAudit.Profile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let primary = p.primary {
                Text("Predominante: **\(primary)**").font(.callout)
            }
            ForEach(p.purposes.sorted { $0.score > $1.score }) { pu in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(pu.label).font(.callout)
                        Spacer()
                        Text("\(pu.score)%").font(.callout).fontWeight(.medium)
                            .foregroundStyle(pu.score >= 70 ? .green : (pu.score >= 40 ? .orange : .secondary))
                    }
                    ProgressView(value: Double(pu.score), total: 100)
                        .tint(pu.score >= 70 ? .green : (pu.score >= 40 ? .orange : .gray))
                    if !pu.present.isEmpty {
                        Text(pu.present.joined(separator: " · ")).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private func containerRow(_ c: ExternalAudit.Docker.Container) -> some View {
        CardRow {
            HStack(spacing: 10) {
                StatusDot(color: c.state == "running" ? .green : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(c.name).fontWeight(.medium)
                        if let desc = AuditReport.containerPurpose(image: c.image) {
                            Text(desc).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text(c.image).font(.caption).foregroundStyle(.secondary)
                }
            }
        } trailing: {
            Text(c.status ?? c.state ?? "—").font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
    }

    private func infoCard(_ title: String, _ value: String, detail: String, icon: String, tint: Color = .secondary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary)
            Text(value.isEmpty ? "—" : value).font(.callout).fontWeight(.medium).lineLimit(2)
            if !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(tint) }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private func diskRow(_ d: ExternalAudit.Disk) -> some View {
        CardRow {
            HStack(spacing: 10) {
                Image(systemName: d.rotational == true ? "internaldrive" : "memorychip")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("/dev/\(d.name)\(d.model.map { " · \($0)" } ?? "")").fontWeight(.medium)
                    Text([sizeLabel(d.sizeBytes),
                          d.rotational == true ? "HDD" : "SSD",
                          d.powerOnHours.map { "\($0) h ligado" }].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } trailing: {
            if d.smartAvailable == true {
                Text(d.smartHealthy == true ? "SMART OK" : "SMART falha")
                    .font(.caption).foregroundStyle(d.smartHealthy == true ? .green : .red)
            } else {
                Text("sem SMART").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func lynisCard(_ lynis: ExternalAudit.Lynis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Índice de endurecimento").font(.callout)
                Spacer()
                Text(lynis.hardeningIndex.map { "\($0)/100" } ?? "não executado")
                    .fontWeight(.medium)
                    .foregroundStyle(lynis.hardeningIndex == nil ? .secondary : .primary)
            }
            if lynis.hardeningIndex == nil {
                Text("O Lynis está instalado mas não foi executado nesta coleta (rode o coletor com UPTEND_RUN_LYNIS=1 para incluir).")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if !lynis.warnings.isEmpty {
                Text("Avisos (\(lynis.warnings.count))").font(.caption).foregroundStyle(.orange)
                ForEach(Array(lynis.warnings.prefix(8).enumerated()), id: \.offset) { Text("• \($0.element)").font(.caption).foregroundStyle(.secondary) }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    // MARK: helpers

    private func ramLabel(_ bytes: Int64?) -> String {
        guard let bytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory)
    }
    private func sizeLabel(_ bytes: Int64?) -> String? {
        guard let bytes, bytes > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    private func isPast(_ isoDate: String) -> Bool {
        let today = ISO8601DateFormatter.dateOnly(Date())
        return isoDate < today
    }
}

private extension ISO8601DateFormatter {
    /// "AAAA-MM-DD" de hoje (para comparar com eol_date sem depender de fuso).
    static func dateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

// MARK: - Selo de nota

struct ScoreBadge: View {
    let score: Int
    let light: AuditLight
    var compact: Bool

    var body: some View {
        let size: CGFloat = compact ? 44 : 96
        let line: CGFloat = compact ? 5 : 9
        ZStack {
            Circle().stroke(Color(nsColor: .separatorColor), lineWidth: line)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(light.color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(score)").font(.system(size: compact ? 16 : 34, weight: .semibold))
                if !compact { Text("de 100").font(.caption2).foregroundStyle(.secondary) }
            }
        }
        .frame(width: size, height: size)
        .padding(compact ? 0 : 14)
        .background(compact ? Color.clear : Color(nsColor: .controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Exportação de relatórios (helpers reutilizados)

enum AuditExport {
    static func saveText(name: String, contents: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            try? contents.data(using: .utf8)?.write(to: url, options: .atomic)
        }
    }
    static func copy(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
    static func savePDF(html: String, name: String, onError: @escaping (String) -> Void) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // No PDF não dá para clicar: abre todas as seções recolhíveis (evidências) para
        // ficarem visíveis no documento estático.
        let printHTML = html.replacingOccurrences(of: "<details", with: "<details open")
        HTMLToPDF.render(html: printHTML) { data in
            if let data { try? data.write(to: url, options: .atomic) }
            else { onError("Não consegui gerar o PDF.") }
        }
    }
}

// MARK: - Relatórios (seção própria da barra lateral)

struct AuditReportsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var service: ExternalAuditService
    @EnvironmentObject var branding: BrandingStore
    @EnvironmentObject var riskExceptions: RiskExceptionStore
    @AppStorage("uptend.signReports") private var signReports = false
    @State private var previewHTML: String?
    @State private var error: String?
    @State private var verifyResult: String?

    /// Data de hoje em "yyyy-MM-dd" (para validade das exceções).
    static func todayString() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    var body: some View {
        Group {
            if let item = service.selected { content(item.audit) }
            else {
                ContentUnavailableView {
                    Label("Nenhuma auditoria carregada", systemImage: "doc.text")
                } description: {
                    Text("Importe ou colete uma auditoria para gerar relatórios.")
                } actions: {
                    Button("Ir para Importar") { state.auditoriaSection = .importar }
                }
            }
        }
        .sheet(isPresented: Binding(get: { previewHTML != nil }, set: { if !$0 { previewHTML = nil } })) {
            if let html = previewHTML { AuditReportPreview(html: html) }
        }
    }

    /// Assinatura da auditoria selecionada (nil se assinatura desligada).
    private func currentSignature() -> ReportSignature? {
        guard signReports, let data = service.selectedPayload() else { return nil }
        let who = branding.branding.auditor.isEmpty ? (branding.branding.company.isEmpty ? "Auditor Uptend" : branding.branding.company) : branding.branding.auditor
        return AuditSigner.sign(data, auditor: who)
    }

    private func content(_ audit: ExternalAudit) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Relatórios", subtitle: audit.host.hostname) {
                    AuditHostPicker()
                }
                if let error { ErrorBanner(error) { self.error = nil } }

                signatureCard
                if let verifyResult { verifyBanner(verifyResult) }

                let b = branding.forReports
                let sig = currentSignature()

                // Aceitação de risco (B2): achados aceitos saem da nota e da matriz.
                // A gestão das exceções fica na subseção "Aceitação de risco".
                let today = Self.todayString()
                let allExc = riskExceptions.exceptions(for: audit)
                let effective = RiskExceptions.effective(audit, exceptions: allExc, today: today)
                let accepted = RiskExceptions.accepted(audit, exceptions: allExc, today: today)

                reportCard(
                    "Executivo (diretoria)", "person.2.fill",
                    "Linguagem de negócio: veredito, para que serve o servidor, plano de ação e pontos fortes. Riscos aceitos não entram na nota.",
                    html: { AuditReport.executiveHTML(effective, branding: b, signature: sig) }, baseName: "executivo-\(audit.host.hostname)")

                reportCard(
                    "Segurança (SOC)", "lock.shield.fill",
                    "Postura de segurança, achados por severidade, conformidade CIS e Lynis. Riscos aceitos não entram na nota.",
                    html: { AuditReport.socHTML(effective, branding: b, signature: sig) }, baseName: "soc-\(audit.host.hostname)")

                reportCard(
                    "Técnico", "doc.plaintext.fill",
                    "Inventário completo: máquina, discos, Docker, todos os achados (inclusive aceitos). Também em Markdown (para IA).",
                    html: { AuditReport.html(audit, branding: b, signature: sig) }, baseName: "auditoria-\(audit.host.hostname)",
                    markdown: { AuditReport.markdown(audit, branding: b) })

                riskRegisterCard(effective, branding: b, signature: sig, accepted: accepted)
                soaCard(audit, branding: b, signature: sig)
                lgpdCard(effective, branding: b, signature: sig)
                cveCard(audit, branding: b, signature: sig)
                surfaceCard(effective, branding: b, signature: sig)
                detectionCard(effective, branding: b, signature: sig)
                playbookCard(effective, branding: b, signature: sig)
            }
            .screenPadding()
            .frame(maxWidth: 820, alignment: .leading)
        }
    }

    @ViewBuilder
    private func verifyBanner(_ msg: String) -> some View {
        let invalid = msg.contains("INVÁLIDA")
        let valid = msg.contains("VÁLIDA") && !invalid
        let color: Color = invalid ? .red : (valid ? .green : .orange)
        let icon = invalid ? "xmark.seal.fill" : (valid ? "checkmark.seal.fill" : "info.circle.fill")
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(color).font(.title3)
            Text(msg).font(.callout).foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            Spacer()
            Button { verifyResult = nil } label: { Image(systemName: "xmark") }.buttonStyle(.borderless)
        }
        .padding(12)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color.opacity(0.4), lineWidth: 1))
    }

    private var signatureCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $signReports) { Label("Assinar digitalmente os relatórios", systemImage: "signature").font(.headline) }
                .toggleStyle(.switch)
            Text("Assinatura ECDSA P-256 (cadeia de custódia). Impressão digital da sua chave: \(AuditSigner.fingerprint.prefix(16))…")
                .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            if signReports {
                HStack {
                    Button { saveSignature() } label: { Label("Salvar assinatura (.sig)", systemImage: "square.and.arrow.down") }
                    Button { verifySignature() } label: { Label("Verificar .sig…", systemImage: "checkmark.seal") }
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private func saveSignature() {
        guard let data = service.selectedPayload(),
              let sig = currentSignature() ?? AuditSigner.sign(data, auditor: branding.branding.auditor),
              let json = try? JSONEncoder().encode(sig) else { error = "Não consegui assinar."; return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "auditoria-\(service.selected?.hostname ?? "host").sig.json"
        if panel.runModal() == .OK, let url = panel.url { try? json.write(to: url) }
    }

    private func verifySignature() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url,
              let sigData = try? Data(contentsOf: url),
              let sig = try? JSONDecoder().decode(ReportSignature.self, from: sigData),
              let payload = service.selectedPayload() else { verifyResult = "Não consegui ler o arquivo de assinatura."; return }
        let ok = AuditSigner.verify(payload, sig)
        verifyResult = ok
            ? "Assinatura VÁLIDA ✓ — assinada por \(sig.auditor), impressão \(sig.prettyFingerprint). O conteúdo não foi adulterado."
            : "Assinatura INVÁLIDA ✗ — não corresponde a esta auditoria (conteúdo alterado ou chave diferente)."
    }

    /// Ações padrão de um relatório: um botão grande "Visualizar" + um menu em cascata
    /// "Salvar / Exportar" com todos os formatos (nomes completos, sem abreviar).
    @ViewBuilder
    private func reportActions(baseName: String, html: @escaping () -> String,
                               markdown: (() -> String)? = nil, csv: (() -> String)? = nil) -> some View {
        HStack(spacing: 10) {
            Button { previewHTML = html() } label: {
                Label("Visualizar relatório", systemImage: "eye")
            }
            .buttonStyle(.borderedProminent).controlSize(.large)

            Menu {
                Button { AuditExport.savePDF(html: html(), name: "\(baseName).pdf") { error = $0 } } label: {
                    Label("Salvar como PDF", systemImage: "doc.richtext")
                }
                Button { AuditExport.saveText(name: "\(baseName).html", contents: html()) } label: {
                    Label("Salvar como página HTML", systemImage: "safari")
                }
                if let csv {
                    Button { AuditExport.saveText(name: "\(baseName).csv", contents: csv()) } label: {
                        Label("Salvar dados em CSV (planilha)", systemImage: "tablecells")
                    }
                }
                if let markdown {
                    Divider()
                    Button { AuditExport.saveText(name: "\(baseName).md", contents: markdown()) } label: {
                        Label("Salvar como Markdown", systemImage: "doc.plaintext")
                    }
                    Button { AuditExport.copy(markdown()) } label: {
                        Label("Copiar Markdown (para IA)", systemImage: "doc.on.doc")
                    }
                }
            } label: {
                Label("Salvar / Exportar", systemImage: "square.and.arrow.down")
            }
            .controlSize(.large).fixedSize()
            Spacer()
        }
    }

    private func reportCard(_ title: String, _ icon: String, _ desc: String,
                            html: @escaping () -> String, baseName: String, markdown: (() -> String)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.headline)
            Text(desc).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            reportActions(baseName: baseName, html: html, markdown: markdown)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private func riskRegisterCard(_ audit: ExternalAudit, branding b: ReportBranding?, signature sig: ReportSignature?,
                                  accepted: [RiskException]) -> some View {
        let risks = RiskRegister.risks(from: audit)
        return VStack(alignment: .leading, spacing: 10) {
            Label("Registro de risco (GRC)", systemImage: "tablecells.badge.ellipsis").font(.headline)
            Text("Matriz de risco 5×5 (probabilidade × impacto) + tabela de \(risks.count) risco(s) priorizado(s), com ID, nível e tratamento. Exportável em CSV para GRC.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            reportActions(baseName: "risco-\(audit.host.hostname)",
                          html: { AuditReport.riskRegisterHTML(audit, branding: b, signature: sig, accepted: accepted) },
                          csv: { RiskRegister.csv(risks) })
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    /// Card da Declaração de Aplicabilidade (SoA) ISO 27001:2022 — FASE B1.
    private func soaCard(_ audit: ExternalAudit, branding b: ReportBranding?, signature sig: ReportSignature?) -> some View {
        let soa = ComplianceCatalog.soaISO27001(audit)
        let sum = ComplianceCatalog.summary(soa)
        return VStack(alignment: .leading, spacing: 10) {
            Label("Declaração de Aplicabilidade (SoA) — ISO 27001:2022", systemImage: "checklist").font(.headline)
            Text("Gap assessment dos \(sum.total) controles do Anexo A: coberto / não conforme / não avaliado / manual. Conformidade sobre o verificado: \(sum.checkedPercent)%. Exportável em CSV.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                ForEach(SoAStatus.allCases, id: \.self) { st in
                    HStack(spacing: 5) {
                        Circle().fill(soaColor(st)).frame(width: 8, height: 8)
                        Text("\(sum.counts[st] ?? 0)").font(.caption).monospacedDigit()
                        Text(st.rawValue).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            reportActions(baseName: "soa-iso27001-\(audit.host.hostname)",
                          html: { AuditReport.soaHTML(audit, branding: b, signature: sig) },
                          csv: { ComplianceCatalog.csv(soa) })
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    /// Card das regras de detecção Sigma/Falco (controles compensatórios) — FASE C2.
    private func detectionCard(_ audit: ExternalAudit, branding b: ReportBranding?, signature sig: ReportSignature?) -> some View {
        let rules = DetectionRules.rules(for: audit)
        return VStack(alignment: .leading, spacing: 10) {
            Label("Regras de detecção (Sigma / Falco)", systemImage: "sensor.tag.radiowaves.forward").font(.headline)
            Text(rules.isEmpty
                 ? "Sem lacunas que peçam detecção compensatória. 🎉"
                 : "\(rules.count) regra(s) compensatória(s) para o SIEM/Falco, derivadas das lacunas (ex.: fail2ban ausente → força-bruta SSH). Cada uma mapeada a MITRE ATT&CK.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if !rules.isEmpty {
                HStack(spacing: 10) {
                    Button { previewHTML = AuditReport.detectionRulesHTML(audit, branding: b, signature: sig) } label: {
                        Label("Visualizar regras", systemImage: "eye")
                    }.buttonStyle(.borderedProminent).controlSize(.large)
                    Menu {
                        Button { AuditExport.saveText(name: "deteccao-\(audit.host.hostname).yml", contents: DetectionRules.bundle(rules)) } label: {
                            Label("Salvar regras (.yml)", systemImage: "doc.text")
                        }
                        Button { AuditExport.copy(DetectionRules.bundle(rules)) } label: {
                            Label("Copiar regras", systemImage: "doc.on.doc")
                        }
                    } label: { Label("Salvar / Exportar", systemImage: "square.and.arrow.down") }
                        .controlSize(.large).fixedSize()
                    Spacer()
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    /// Card do mapa de superfície de ataque (diagrama do que está exposto) — FASE D3.
    private func surfaceCard(_ audit: ExternalAudit, branding b: ReportBranding?, signature sig: ReportSignature?) -> some View {
        let surf = AttackSurfaceMap.from(audit)
        return VStack(alignment: .leading, spacing: 10) {
            Label("Superfície de ataque (o que está exposto)", systemImage: "point.3.connected.trianglepath.dotted").font(.headline)
            Text("\(surf.entries.count) porta(s) exposta(s) pela rede — \(surf.redCount) de risco alto, \(surf.yellowCount) a restringir. Diagrama do caminho de entrada de um atacante, com o risco de cada porta.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            reportActions(baseName: "superficie-\(audit.host.hostname)",
                          html: { AuditReport.attackSurfaceHTML(audit, branding: b, signature: sig) })
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    /// Card do playbook de hardening (script com backup/rollback) — FASE D2.
    private func playbookCard(_ audit: ExternalAudit, branding b: ReportBranding?, signature sig: ReportSignature?) -> some View {
        let auto = HardeningPlaybook.autoCount(for: audit)
        return VStack(alignment: .leading, spacing: 10) {
            Label("Playbook de hardening (correção)", systemImage: "wrench.and.screwdriver").font(.headline)
            Text(auto == 0
                 ? "Nada a corrigir automaticamente — postura já limpa nos itens automatizáveis. 🎉"
                 : "Gera um script bash com \(auto) correção(ões) automática(s) + backup e modo rollback, a partir dos achados. Nunca roda sozinho — você revisa e aplica.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("Rode em janela de manutenção, com acesso alternativo ao servidor.").font(.caption2).foregroundStyle(.orange)
            if auto > 0 {
                HStack(spacing: 10) {
                    Button { previewHTML = AuditReport.playbookHTML(audit, branding: b, signature: sig) } label: {
                        Label("Visualizar playbook", systemImage: "eye")
                    }.buttonStyle(.borderedProminent).controlSize(.large)
                    Menu {
                        Button { AuditExport.saveText(name: "playbook-\(audit.host.hostname).sh", contents: HardeningPlaybook.generate(for: audit)) } label: {
                            Label("Salvar script (.sh)", systemImage: "terminal")
                        }
                        Button { AuditExport.copy(HardeningPlaybook.generate(for: audit)) } label: {
                            Label("Copiar script", systemImage: "doc.on.doc")
                        }
                    } label: { Label("Salvar / Exportar", systemImage: "square.and.arrow.down") }
                        .controlSize(.large).fixedSize()
                    Spacer()
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    /// Card da lente LGPD (segurança de dados pessoais) — FASE E4.
    private func lgpdCard(_ audit: ExternalAudit, branding b: ReportBranding?, signature sig: ReportSignature?) -> some View {
        let items = LGPDLens.items(audit)
        let sum = LGPDLens.summary(items)
        return VStack(alignment: .leading, spacing: 10) {
            Label("LGPD — Segurança de dados pessoais", systemImage: "shield.lefthalf.filled").font(.headline)
            Text("Mapeia os achados (sistema + banco) às obrigações de segurança da LGPD (art. 46, 6º-VII, 37): \(items.isEmpty ? "nenhum ponto de atenção. 🎉" : "\(sum.total) ponto(s) — \(sum.critical) crítico(s), \(sum.high) alto(s).")")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("Avaliação técnica, não parecer jurídico.").font(.caption2).foregroundStyle(.secondary)
            reportActions(baseName: "lgpd-\(audit.host.hostname)",
                          html: { AuditReport.lgpdHTML(audit, branding: b, signature: sig) },
                          csv: items.isEmpty ? nil : { LGPDLens.csv(items) })
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    /// Card de vulnerabilidades conhecidas (CVE) — FASE C1.
    private func cveCard(_ audit: ExternalAudit, branding b: ReportBranding?, signature sig: ReportSignature?) -> some View {
        let software = CVEMatcher.allSoftware(audit)
        let matches = CVEMatcher.matches(software)
        let crit = matches.filter { $0.cve.severity == .critical }.count
        let high = matches.filter { $0.cve.severity == .high }.count
        return VStack(alignment: .leading, spacing: 10) {
            Label("Vulnerabilidades conhecidas (CVE)", systemImage: "ladybug").font(.headline)
            if software.isEmpty {
                Text("Nenhuma versão de software foi colhida nesta auditoria. Recolha com um coletor atualizado (a coleta de versões é da versão nova) para cruzar com CVEs.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Cruzamento de \(software.count) componente(s) com base curada de CVEs críticas. \(matches.isEmpty ? "Nenhuma exposição conhecida." : "\(matches.count) exposição(ões) potencial(is) — \(crit) crítica(s), \(high) alta(s).")")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text("Exposição potencial pela versão upstream — confirme o backport da distro. Base curada, não é o NVD completo.")
                    .font(.caption2).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                reportActions(baseName: "cve-\(audit.host.hostname)",
                              html: { AuditReport.cveHTML(audit, branding: b, signature: sig) },
                              csv: matches.isEmpty ? nil : { CVEMatcher.csv(matches) })
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private func soaColor(_ s: SoAStatus) -> Color {
        switch s {
        case .coberto: .green
        case .naoConforme: .red
        case .naoAvaliado: .gray
        case .manual: .blue
        case .naoAplicavel: .secondary
        }
    }
}

// MARK: - Frota / multi-host roll-up — FASE D1

struct FleetView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var service: ExternalAuditService
    @EnvironmentObject var branding: BrandingStore
    @EnvironmentObject var hosts: HostStore
    @EnvironmentObject var riskExceptions: RiskExceptionStore   // nota efetiva (desconta aceitos)
    @State private var previewHTML: String?
    @State private var error: String?

    /// Auditorias com os riscos aceitos descontados — para a frota bater com o painel e
    /// os relatórios (M3).
    private var effectiveAudits: [ExternalAudit] {
        service.audits.map { riskExceptions.effective($0.audit) }
    }

    private static let shortDomain: [String: String] = [
        "Acesso e autenticação": "Acesso", "Rede e firewall": "Rede",
        "Endurecimento do sistema": "Hardening", "Atualizações e patches": "Updates",
        "Registro e detecção": "Logs", "Discos e resiliência": "Discos",
    ]
    private func short(_ d: String) -> String { Self.shortDomain[d] ?? d }

    private func scoreColor(_ s: Int) -> Color { s >= 80 ? .green : (s >= 50 ? .yellow : .red) }

    var body: some View {
        let fleet = FleetRollup.rollup(effectiveAudits)
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Frota", subtitle: "\(fleet.hostCount) host(s) auditado(s)")
                if let error { ErrorBanner(error) { self.error = nil } }

                if fleet.isEmpty {
                    ContentUnavailableView {
                        Label("Nenhum host auditado", systemImage: "square.grid.3x3")
                    } description: {
                        Text("Colete ou importe auditorias de vários hosts para ver a visão de frota.")
                    } actions: {
                        Button("Ir para Importar") { state.auditoriaSection = .importar }
                    }
                } else {
                    summaryCard(fleet)
                    heatmapCard(fleet)
                    hostsCard(fleet)
                    if !fleet.topFindings.isEmpty { topFindingsCard(fleet) }
                }

                batchCollectCard
            }
            .screenPadding()
            .frame(maxWidth: 900, alignment: .leading)
        }
        .sheet(isPresented: Binding(get: { previewHTML != nil }, set: { if !$0 { previewHTML = nil } })) {
            if let html = previewHTML { AuditReportPreview(html: html) }
        }
    }

    private func summaryCard(_ fleet: Fleet) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 18) {
                VStack(alignment: .leading) {
                    Text("Nota média").font(.caption).foregroundStyle(.secondary)
                    Text("\(fleet.avgScore)").font(.system(size: 34, weight: .bold)).foregroundStyle(scoreColor(fleet.avgScore))
                }
                Divider().frame(height: 44)
                distItem("Crítico", fleet.redCount, .red)
                distItem("Atenção", fleet.yellowCount, .yellow)
                distItem("Bom", fleet.greenCount, .green)
                Spacer()
                let b = branding.forReports
                VStack(spacing: 6) {
                    Button { previewHTML = AuditReport.fleetHTML(fleet, branding: b) } label: { Label("Ver relatório", systemImage: "eye") }
                    HStack {
                        Button { AuditExport.savePDF(html: AuditReport.fleetHTML(fleet, branding: b), name: "frota.pdf") { error = $0 } } label: { Label("PDF", systemImage: "doc.richtext") }
                        Button { AuditExport.saveText(name: "frota.csv", contents: FleetRollup.csv(fleet)) } label: { Label("CSV", systemImage: "tablecells") }
                    }.controlSize(.small)
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private func distItem(_ label: String, _ n: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) { Circle().fill(color).frame(width: 9, height: 9); Text("\(n)").font(.title3).bold().monospacedDigit() }
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func heatmapCard(_ fleet: Fleet) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Mapa de conformidade (host × área)", systemImage: "square.grid.3x3.fill").font(.headline)
            Text("Cada célula é a nota da área naquele host. Verde ≥80 · amarelo 50–79 · vermelho <50.")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                    GridRow {
                        Text("Host").font(.caption2).bold().frame(width: 120, alignment: .leading)
                        Text("Nota").font(.caption2).bold().frame(width: 42)
                        ForEach(fleet.domains, id: \.self) { d in
                            Text(short(d)).font(.caption2).foregroundStyle(.secondary).frame(width: 62)
                        }
                    }
                    ForEach(fleet.hosts) { h in
                        GridRow {
                            Text(h.hostname).font(.caption).lineLimit(1).frame(width: 120, alignment: .leading)
                            cell(h.score, wide: true)
                            ForEach(fleet.domains, id: \.self) { d in
                                if let sc = h.domainScores[d] { cell(sc) }
                                else { Text("—").font(.caption2).foregroundStyle(.tertiary).frame(width: 62, height: 26) }
                            }
                        }
                    }
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private func cell(_ score: Int, wide: Bool = false) -> some View {
        Text("\(score)").font(.caption).bold().foregroundStyle(.white)
            .frame(width: wide ? 42 : 62, height: 26)
            .background(scoreColor(score), in: RoundedRectangle(cornerRadius: 5))
    }

    private func hostsCard(_ fleet: Fleet) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Hosts (do mais fraco ao mais forte)", systemImage: "list.number").font(.headline)
            ForEach(fleet.hosts) { h in
                Button {
                    // M7: abre a MESMA coleta que a linha da frota mostra — latestPerHost
                    // deduplica pelo collectedAt mais recente, não pelo importedAt.
                    if let a = service.audits
                        .filter({ FleetRollup.hostKey($0.audit) == h.hostKey })
                        .max(by: { $0.audit.collectedAt < $1.audit.collectedAt }) {
                        service.selectedID = a.id; state.auditoriaSection = .painel
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text("\(h.score)").font(.callout).bold().monospacedDigit().foregroundStyle(.white)
                            .frame(width: 40, height: 30).background(scoreColor(h.score), in: RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(h.hostname).font(.callout)
                            Text("\(h.os) · \(String(h.collectedAt.prefix(10)))").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        if h.criticalCount > 0 { badge("\(h.criticalCount) crít.", .red) }
                        if h.highCount > 0 { badge("\(h.highCount) alto", .orange) }
                        Text("\(h.openCount) abertos").font(.caption2).foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 3)
                Divider()
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text).font(.caption2).bold().foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
    }

    private func topFindingsCard(_ fleet: Fleet) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Achados mais comuns na frota", systemImage: "exclamationmark.triangle").font(.headline)
            ForEach(fleet.topFindings.prefix(10)) { f in
                HStack(spacing: 10) {
                    Circle().fill(sevColor(f.severity)).frame(width: 9, height: 9)
                    Text(f.title).font(.callout).lineLimit(1)
                    Spacer()
                    Text("\(f.hostCount)/\(fleet.hostCount) hosts").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private func sevColor(_ s: AuditSeverity) -> Color {
        switch s { case .critical: .red; case .high: .orange; case .medium: .yellow; case .low: .blue; case .ok: .green }
    }

    private var batchCollectCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Coleta em lote", systemImage: "square.and.arrow.down.on.square").font(.headline)
            Text("Roda o coletor em todos os hosts cadastrados, um a um, e atualiza a frota.")
                .font(.caption).foregroundStyle(.secondary)
            Button {
                Task {
                    for h in hosts.hosts { await service.runCollector(on: h) }
                }
            } label: {
                Label(service.busy ? (service.busyMessage ?? "Coletando…") : "Coletar de todos (\(hosts.hosts.count))", systemImage: "bolt")
            }
            .disabled(service.busy || hosts.hosts.isEmpty)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }
}

// MARK: - Aceitação de risco (subseção própria) — FASE B2

struct RiskAcceptanceView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var service: ExternalAuditService
    @EnvironmentObject var riskExceptions: RiskExceptionStore
    @State private var acceptTarget: Risk?

    var body: some View {
        Group {
            if let item = service.selected { content(item.audit) }
            else {
                ContentUnavailableView {
                    Label("Nenhuma auditoria carregada", systemImage: "checkmark.shield")
                } description: {
                    Text("Importe ou colete uma auditoria para gerenciar a aceitação de riscos.")
                } actions: {
                    Button("Ir para Importar") { state.auditoriaSection = .importar }
                }
            }
        }
        .sheet(item: $acceptTarget) { risk in
            if let audit = service.selected?.audit {
                RiskAcceptSheet(risk: risk, today: AuditReportsView.todayString()) { exception in
                    riskExceptions.accept(exception, in: audit)
                    acceptTarget = nil
                } onCancel: { acceptTarget = nil }
            }
        }
    }

    private func content(_ audit: ExternalAudit) -> some View {
        let today = AuditReportsView.todayString()
        let allExc = riskExceptions.exceptions(for: audit)
        let effective = RiskExceptions.effective(audit, exceptions: allExc, today: today)
        let accepted = RiskExceptions.accepted(audit, exceptions: allExc, today: today)
        let expired = RiskExceptions.expired(audit, exceptions: allExc, today: today)
        let openRisks = RiskRegister.risks(from: effective)

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Aceitação de risco", subtitle: audit.host.hostname)

                explanationBanner
                if !expired.isEmpty { expiredBanner(expired) }

                openRisksCard(audit, openRisks: openRisks, hasAccepted: !accepted.isEmpty)
                if !accepted.isEmpty { acceptedCard(audit, accepted: accepted, today: today) }
            }
            .screenPadding()
            .frame(maxWidth: 820, alignment: .leading)
        }
    }

    /// Cabeçalho explicativo: quem aceita o risco é o dono, não o auditor.
    private var explanationBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill").foregroundStyle(.blue).font(.title3)
            VStack(alignment: .leading, spacing: 5) {
                Text("Quem aceita o risco é o dono, não o auditor")
                    .font(.callout).bold()
                Text("Aceitar um risco é uma decisão de negócio — cabe ao **responsável pelo produto ou sistema** (gestor, dono do serviço, diretoria ou comitê de risco), que tem autoridade e orçamento para assumi-lo. O auditor apenas **registra** essa decisão, mantendo a independência.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text("No campo **Responsável**, informe quem de fato aceitou (nome/cargo ou setor). Na **Referência**, o número do chamado, ata ou e-mail que comprova a aprovação. Enquanto válido, o risco sai da nota e da matriz; ao expirar, volta automaticamente e exige nova revisão.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.blue.opacity(0.25), lineWidth: 1))
    }

    private func expiredBanner(_ expired: [RiskException]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(expired) { e in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("A aceitação de “\(e.title)” expirou em \(e.expiresAt) — o risco voltou a contar. Renove (aceite de novo) ou trate o achado.")
                        .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }

    private func openRisksCard(_ audit: ExternalAudit, openRisks: [Risk], hasAccepted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Riscos abertos", systemImage: "list.bullet.rectangle").font(.headline)
            if openRisks.isEmpty {
                Text(hasAccepted ? "Todos os riscos abertos foram tratados ou aceitos." : "Nenhum risco aberto nesta auditoria. 🎉")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Text("Selecione um risco para registrar a aceitação formal (decisão do dono do risco).")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(openRisks) { r in
                    HStack(spacing: 10) {
                        Circle().fill(levelColor(r.level)).frame(width: 9, height: 9)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.title).font(.callout).lineLimit(1)
                            Text("\(r.category) · \(r.level.rawValue) · probabilidade \(r.likelihood) × impacto \(r.impact) = \(r.score)")
                                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Button { acceptTarget = r } label: { Label("Aceitar risco", systemImage: "checkmark.shield") }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                    .padding(.vertical, 3)
                    Divider()
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private func acceptedCard(_ audit: ExternalAudit, accepted: [RiskException], today: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Riscos aceitos (\(accepted.count))", systemImage: "checkmark.seal.fill").font(.headline)
            Text("Fora da nota e da matriz enquanto válidos — registrados para auditoria.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(accepted) { e in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green).font(.callout)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.title).font(.callout).lineLimit(1)
                        Text("Aceito por \(e.responsible) · válido até \(e.expiresAt)\(daysHint(e, today: today))")
                            .font(.caption2).foregroundStyle(.secondary)
                        if !e.justification.isEmpty {
                            Text("“\(e.justification)”").font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        if !e.reference.isEmpty {
                            Text("Ref.: \(e.reference)").font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                    Button(role: .destructive) { riskExceptions.revoke(e.findingId, in: audit) } label: {
                        Label("Revogar", systemImage: "arrow.uturn.backward")
                    }.buttonStyle(.borderless).controlSize(.small)
                }
                .padding(.vertical, 3)
                Divider()
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private func levelColor(_ l: RiskLevel) -> Color {
        switch l { case .baixo: .green; case .medio: .yellow; case .alto: .orange; case .critico: .red }
    }

    private func daysHint(_ e: RiskException, today: String) -> String {
        guard let d = e.daysRemaining(asOf: today) else { return "" }
        if d < 0 { return " · expirado" }
        if d == 0 { return " · expira hoje" }
        return " · faltam \(d) dia(s)"
    }
}

// MARK: - Aceitação de risco (sheet) — FASE B2

struct RiskAcceptSheet: View {
    let risk: Risk
    let today: String
    let onAccept: (RiskException) -> Void
    let onCancel: () -> Void

    @EnvironmentObject var branding: BrandingStore
    @State private var justification = ""
    @State private var responsible = ""
    @State private var reference = ""
    @State private var expiry = Date().addingTimeInterval(90 * 86_400)   // padrão: 90 dias
    @State private var didPrefill = false

    private var canAccept: Bool {
        !justification.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !responsible.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield.fill").foregroundStyle(.orange).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aceitar risco").font(.headline)
                    Text(risk.title).font(.callout).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Text("\(risk.category) · \(risk.level.rawValue) · probabilidade \(risk.likelihood) × impacto \(risk.impact) = \(risk.score)")
                .font(.caption).foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Justificativa *").font(.subheadline).bold()
                Text("Por que a organização aceita esse risco (compensações, custo, contexto).")
                    .font(.caption2).foregroundStyle(.secondary)
                TextEditor(text: $justification)
                    .frame(height: 74).font(.callout)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.secondary.opacity(0.3)))
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Responsável *").font(.subheadline).bold()
                    TextField("quem aceita o risco", text: $responsible).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Válido até").font(.subheadline).bold()
                    DatePicker("", selection: $expiry, in: Date()..., displayedComponents: .date)
                        .labelsHidden().datePickerStyle(.compact)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Referência (opcional)").font(.subheadline).bold()
                TextField("ticket, chamado, documento…", text: $reference).textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Cancelar", role: .cancel) { onCancel() }.keyboardShortcut(.cancelAction)
                Button {
                    onAccept(RiskException(
                        findingId: risk.findingId, title: risk.title,
                        justification: justification.trimmingCharacters(in: .whitespacesAndNewlines),
                        responsible: responsible.trimmingCharacters(in: .whitespacesAndNewlines),
                        acceptedAt: today, expiresAt: Self.iso(expiry),
                        reference: reference.trimmingCharacters(in: .whitespacesAndNewlines)))
                } label: { Text("Aceitar risco").bold() }
                .keyboardShortcut(.defaultAction).disabled(!canAccept)
            }
        }
        .padding(20).frame(width: 460)
        .onAppear {
            guard !didPrefill else { return }
            didPrefill = true
            let b = branding.branding
            responsible = b.auditor.isEmpty ? b.company : b.auditor
        }
    }

    static func iso(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
}

// MARK: - Baseline como código (subseção própria) — FASE B4

struct BaselineView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var service: ExternalAuditService
    @EnvironmentObject var baselineStore: BaselineStore
    @EnvironmentObject var branding: BrandingStore
    @State private var newName = "Baseline Linux — meu padrão"
    @State private var previewHTML: String?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Baseline", subtitle: baselineStore.baseline?.name ?? "Nenhum baseline definido")
                if let error { ErrorBanner(error) { self.error = nil } }

                explanationBanner
                recommendedProfilesCard
                currentBaselineCard
                if baselineStore.baseline != nil { conformityCard }
            }
            .screenPadding()
            .frame(maxWidth: 820, alignment: .leading)
        }
        .sheet(isPresented: Binding(get: { previewHTML != nil }, set: { if !$0 { previewHTML = nil } })) {
            if let html = previewHTML { AuditReportPreview(html: html) }
        }
    }

    private var explanationBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "ruler.fill").foregroundStyle(.blue).font(.title3)
            VStack(alignment: .leading, spacing: 5) {
                Text("O seu padrão, como código").font(.callout).bold()
                Text("Um **baseline** define quais controles você exige de qualquer máquina. Guarde-o como arquivo JSON e reutilize em cada cliente: a auditoria é medida contra o seu padrão e gera um relatório de **conformidade ao baseline** (aprovado/reprovado por controle).")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text("Dica: gere um baseline a partir de uma máquina de referência bem configurada, edite o JSON se quiser (marcar itens como não obrigatórios, adicionar notas) e leve-o para os próximos trabalhos.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.blue.opacity(0.25), lineWidth: 1))
    }

    private var recommendedProfilesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Perfis recomendados", systemImage: "square.stack.3d.up").font(.headline)
            Text("Padrões prontos, calibrados por **risco/contexto** (não por nota). Um clique define o baseline ativo — depois você pode ajustar o JSON e salvar o seu.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ForEach(BaselineProfile.allCases, id: \.self) { profile in
                let count = BaselineEngine.builtin(profile, today: "2000-01-01").items.filter(\.mandatory).count
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: profileIcon(profile)).foregroundStyle(profileColor(profile)).frame(width: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(profile.displayName).font(.callout).bold()
                        Text(profile.subtitle).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Text("\(count) obrig.").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                    Button("Usar") { baselineStore.set(BaselineEngine.builtin(profile, today: AuditReportsView.todayString())) }
                        .controlSize(.small)
                }
                .padding(.vertical, 2)
                Divider()
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private func profileIcon(_ p: BaselineProfile) -> String {
        switch p { case .basico: "1.circle.fill"; case .padrao: "2.circle.fill"; case .rigoroso: "3.circle.fill" }
    }
    private func profileColor(_ p: BaselineProfile) -> Color {
        switch p { case .basico: .green; case .padrao: .blue; case .rigoroso: .red }
    }

    private var currentBaselineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Baseline ativo", systemImage: "doc.badge.gearshape").font(.headline)
            if let b = baselineStore.baseline {
                Text("**\(b.name)** · v\(b.version) · \(b.items.count) controles (\(b.mandatoryCount) obrigatórios) · criado \(b.createdAt)")
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button { baselineStore.saveToFile() } label: { Label("Salvar arquivo…", systemImage: "square.and.arrow.down") }
                    Button { if let e = baselineStore.loadFromFile() { error = e } } label: { Label("Carregar outro…", systemImage: "square.and.arrow.up") }
                    Button(role: .destructive) { baselineStore.clear() } label: { Label("Remover", systemImage: "trash") }
                }
            } else {
                Text("Nenhum baseline definido. Gere um a partir da auditoria carregada ou carregue um arquivo JSON.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if service.selected != nil {
                    HStack {
                        TextField("Nome do baseline", text: $newName).textFieldStyle(.roundedBorder).frame(maxWidth: 320)
                        Button {
                            if let audit = service.selected?.audit {
                                baselineStore.generate(from: audit, name: newName, today: AuditReportsView.todayString())
                            }
                        } label: { Label("Gerar desta auditoria", systemImage: "wand.and.stars") }
                            .buttonStyle(.borderedProminent)
                    }
                }
                Button { if let e = baselineStore.loadFromFile() { error = e } } label: { Label("Carregar arquivo…", systemImage: "square.and.arrow.up") }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    @ViewBuilder
    private var conformityCard: some View {
        if let b = baselineStore.baseline, let item = service.selected {
            let results = BaselineEngine.assess(item.audit, against: b)
            let sum = BaselineEngine.summary(results)
            VStack(alignment: .leading, spacing: 10) {
                Label("Conformidade — \(item.audit.host.hostname)", systemImage: "checkmark.gobackward").font(.headline)
                HStack(spacing: 8) {
                    Image(systemName: sum.passed ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .foregroundStyle(sum.passed ? .green : .red)
                    Text(sum.passed ? "APROVADO no baseline" : "REPROVADO — \(sum.mandatoryDesvio) desvio(s) obrigatório(s)")
                        .font(.callout).bold().foregroundStyle(sum.passed ? .green : .red)
                }
                Text("Conformidade sobre o avaliado: \(sum.percent)% · Conforme \(sum.conforme) · Desvio \(sum.desvio) · Não avaliado \(sum.naoAvaliado) de \(sum.total).")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button { previewHTML = AuditReport.baselineHTML(item.audit, baseline: b, branding: branding.forReports) } label: { Label("Ver", systemImage: "eye") }
                    Button { AuditExport.savePDF(html: AuditReport.baselineHTML(item.audit, baseline: b, branding: branding.forReports), name: "baseline-\(item.audit.host.hostname).pdf") { error = $0 } } label: { Label("PDF…", systemImage: "doc.richtext") }
                    Button { AuditExport.saveText(name: "baseline-\(item.audit.host.hostname).csv", contents: BaselineEngine.csv(results)) } label: { Label("CSV…", systemImage: "tablecells") }
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label("Conformidade", systemImage: "checkmark.gobackward").font(.headline)
                Text("Carregue uma auditoria (aba Importar) para medir a conformidade dela contra este baseline.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
        }
    }
}

// MARK: - Dashboard (BI) — Metabase embutido + exportação de dados

struct AuditBIView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var service: ExternalAuditService
    @EnvironmentObject var hosts: HostStore
    @EnvironmentObject var riskExceptions: RiskExceptionStore   // nota efetiva (desconta aceitos)
    /// Auditorias com riscos aceitos descontados — para o dashboard bater com o painel (M3).
    private var effectiveAudits: [ExternalAudit] { service.audits.map { riskExceptions.effective($0.audit) } }
    @AppStorage("uptend.metabaseURL") private var metabaseURL = ""
    @AppStorage("uptend.metabaseEmail") private var adminEmail = ""
    @State private var showPanel = false
    @State private var opening = false
    @State private var revealPassword = false
    @State private var panelCookie: HTTPCookie?
    @State private var showExisting = false
    @State private var existingPassword = ""
    @State private var savingExisting = false
    @State private var setupBusy = false
    @State private var setupMsg: String?
    @State private var setupErr: String?
    @State private var savedCred: MetabaseCredentials.Cred?
    @State private var dashHTML: String?
    @State private var showAdvanced = false
    @State private var dashError: String?

    private var metabaseValidURL: URL? {
        var t = metabaseURL.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        if !t.contains("://") { t = "http://" + t }   // aceita "ip:porta" sem esquema
        guard let u = URL(string: t), u.scheme == "http" || u.scheme == "https", u.host?.isEmpty == false else { return nil }
        return u
    }
    private var emailValid: Bool {
        let e = adminEmail.trimmingCharacters(in: .whitespaces)
        guard let at = e.lastIndex(of: "@"), at != e.startIndex else { return false }
        let domain = e[e.index(after: at)...]
        return domain.contains(".") && !domain.hasSuffix(".")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Dashboard", subtitle: "Visão consolidada das auditorias")

                dashboardCard
                if let dashError { ErrorBanner(dashError) { self.dashError = nil } }

                DisclosureGroup(isExpanded: $showAdvanced) {
                    VStack(alignment: .leading, spacing: 16) {
                        dataCard
                        metabaseCard
                        howToCard
                    }
                    .padding(.top, 8)
                } label: {
                    Label("Avançado: exportar dados e Metabase interativo", systemImage: "slider.horizontal.3")
                        .font(.headline)
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
            }
            .screenPadding()
            .frame(maxWidth: 820, alignment: .leading)
        }
        .sheet(isPresented: $showPanel) {
            if let url = metabaseValidURL {
                ServicePanelSheet(title: "Metabase", url: url, sessionCookie: panelCookie)
            }
        }
        .sheet(isPresented: Binding(get: { dashHTML != nil }, set: { if !$0 { dashHTML = nil } })) {
            if let html = dashHTML { AuditReportPreview(html: html) }
        }
        .task(id: metabaseURL) { savedCred = MetabaseCredentials.load(baseURL: normalizedURLString) }
    }

    private var dashboardCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Dashboard visual", systemImage: "chart.bar.xaxis")
                .font(.headline)
            Text("Painel consolidado com nota ao longo do tempo, risco por severidade, categorias e servidores — interativo (filtra por servidor) e pronto para apresentar, imprimir ou virar PDF. Gerado do histórico, offline.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if service.audits.isEmpty {
                Text("Importe ou colete ao menos uma auditoria para montar o dashboard.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                HStack {
                    Button { dashHTML = AuditDashboard.html(effectiveAudits) } label: {
                        Label("Ver dashboard", systemImage: "rectangle.inset.filled")
                    }
                    Button { AuditExport.savePDF(html: AuditDashboard.html(effectiveAudits), name: "dashboard-auditoria.pdf") { dashError = $0 } } label: {
                        Label("Salvar PDF…", systemImage: "doc.richtext")
                    }
                    Button { AuditExport.saveText(name: "dashboard-auditoria.html", contents: AuditDashboard.html(effectiveAudits)) } label: {
                        Label("HTML…", systemImage: "doc")
                    }
                    Spacer()
                    Text("\(service.audits.count) coleta(s)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private var normalizedURLString: String { metabaseValidURL?.absoluteString ?? metabaseURL }

    /// Motivo de o botão de configurar estar desligado (nil = está habilitado).
    private var disabledReason: String? {
        if metabaseValidURL == nil { return "Falta o passo 1: preencha o endereço do Metabase acima (ou use \"Usar host…\")." }
        if !emailValid { return "Digite um e-mail válido para o administrador." }
        return nil
    }

    /// Valida uma conta que já existe no Metabase e guarda no Keychain (para auto-login).
    @MainActor
    private func saveExisting() async {
        guard let url = metabaseValidURL else { return }
        savingExisting = true; setupMsg = nil; setupErr = nil
        defer { savingExisting = false }
        let email = adminEmail.trimmingCharacters(in: .whitespaces)
        do {
            _ = try await MetabaseAPI.login(baseURL: url, email: email, password: existingPassword)
            MetabaseCredentials.save(baseURL: url.absoluteString, email: email, password: existingPassword)
            savedCred = .init(email: email, password: existingPassword)
            existingPassword = ""
            showExisting = false
            setupMsg = "Credenciais válidas e guardadas no Keychain. O painel agora abre já logado."
        } catch {
            setupErr = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Abre o painel. Se houver credencial guardada, autentica antes e injeta a sessão
    /// na WebView — o Metabase abre já logado, sem pedir e-mail/senha.
    @MainActor
    private func openPanel() async {
        guard let url = metabaseValidURL else { return }
        panelCookie = nil
        if let cred = savedCred {
            opening = true
            defer { opening = false }
            if let id = try? await MetabaseAPI.login(baseURL: url, email: cred.email, password: cred.password) {
                panelCookie = MetabaseAPI.sessionCookie(baseURL: url, sessionID: id)
            }
            // Se o login falhar, abre mesmo assim (o Metabase pede as credenciais).
        }
        showPanel = true
    }

    @MainActor
    private func autoSetup() async {
        guard let url = metabaseValidURL else { return }
        setupBusy = true; setupMsg = nil; setupErr = nil
        defer { setupBusy = false }
        do {
            guard let token = try await MetabaseAPI.setupToken(baseURL: url) else {
                setupErr = MetabaseAPI.APIError.alreadyConfigured.errorDescription
                return
            }
            let email = adminEmail.trimmingCharacters(in: .whitespaces)
            let password = MetabaseAPI.strongPassword()
            try await MetabaseAPI.createAdmin(baseURL: url, token: token, email: email, password: password)
            MetabaseCredentials.save(baseURL: url.absoluteString, email: email, password: password)
            savedCred = .init(email: email, password: password)
            AuditExport.copy(password)     // senha já na área de transferência
            setupMsg = "Conta de administrador criada! A senha foi copiada e guardada no Keychain."
        } catch {
            setupErr = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Exportar dados (para o BI)", systemImage: "tablecells")
                .font(.headline)
            Text("Gera CSVs que o Metabase importa direto (também servem para Power BI ou planilha). Use o histórico para montar gráficos de evolução no tempo.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Menu {
                    Button("Resumo — auditoria atual") { exportSummary(currentOnly: true) }
                    Button("Resumo — histórico completo") { exportSummary(currentOnly: false) }
                } label: { Label("Exportar resumo (CSV)", systemImage: "square.and.arrow.up") }
                .disabled(service.selected == nil)
                Menu {
                    Button("Achados — auditoria atual") { exportFindings(currentOnly: true) }
                    Button("Achados — histórico completo") { exportFindings(currentOnly: false) }
                } label: { Label("Exportar achados (CSV)", systemImage: "square.and.arrow.up") }
                .disabled(service.selected == nil)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private var metabaseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Metabase", systemImage: "chart.bar.xaxis").font(.headline)

            // ---- Passo 1: endereço ------------------------------------------------
            Text("1. Endereço do Metabase").font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            HStack {
                TextField("http://ip-do-servidor:3010", text: $metabaseURL)
                    .textFieldStyle(.roundedBorder)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(metabaseURL.isEmpty ? Color.orange.opacity(0.6) : .clear, lineWidth: 1)
                    )
                if !hosts.hosts.isEmpty {
                    Menu {
                        ForEach(hosts.hosts) { h in
                            Button("\(h.name) — \(h.address):3010") { metabaseURL = "http://\(h.address):3010" }
                        }
                    } label: { Label("Usar host…", systemImage: "server.rack") }
                    .fixedSize()
                }
            }
            HStack {
                Button { Task { await openPanel() } } label: {
                    Label(opening ? "Entrando…" : "Abrir painel", systemImage: "rectangle.inset.filled")
                }
                .disabled(metabaseValidURL == nil || opening)
                if opening { ProgressView().controlSize(.small) }
                if let url = metabaseValidURL {
                    Button { NSWorkspace.shared.open(url) } label: { Label("Navegador", systemImage: "safari") }
                }
            }
            if savedCred != nil {
                Label("O painel abre já logado (o Uptend usa a senha guardada).", systemImage: "lock.open")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Divider()

            // ---- Passo 2: conta de administrador ----------------------------------
            Text("2. Conta de administrador").font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            Text("Se o Metabase é novo, o Uptend cria a conta sozinho — sem abrir o navegador. A senha é gerada e guardada no Keychain do Mac.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

            if let cred = savedCred {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Admin criado para este Metabase:").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text("E-mail: \(cred.email)").font(.callout).textSelection(.enabled)
                        Spacer()
                        Button { AuditExport.copy(cred.email) } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.borderless)
                    }
                    HStack {
                        Text("Senha: \(revealPassword ? cred.password : "••••••••")")
                            .font(.callout).textSelection(.enabled)
                        Spacer()
                        Button { revealPassword.toggle() } label: {
                            Image(systemName: revealPassword ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless).help(revealPassword ? "Ocultar" : "Mostrar senha")
                        Button("Copiar senha") { AuditExport.copy(cred.password) }.buttonStyle(.borderless)
                    }
                }
                .padding(10).background(Color(nsColor: .textBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            }

            TextField("E-mail do administrador", text: $adminEmail)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button { Task { await autoSetup() } } label: {
                    Label(setupBusy ? "Configurando…" : "Configurar Metabase automaticamente", systemImage: "wand.and.stars")
                }
                .disabled(setupBusy || metabaseValidURL == nil || !emailValid)
                if setupBusy { ProgressView().controlSize(.small) }
                Spacer()
                Button { withAnimation { showExisting.toggle() } } label: {
                    Label("Já tenho conta", systemImage: "key")
                }
                .buttonStyle(.borderless)
            }

            // Metabase que JÁ tem conta (criada por você antes): guarda a senha para
            // o painel abrir logado.
            if showExisting {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Guardar uma conta que já existe neste Metabase (para abrir o painel já logado):")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    SecureField("Senha da conta", text: $existingPassword)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button { Task { await saveExisting() } } label: {
                            Label(savingExisting ? "Verificando…" : "Entrar e guardar", systemImage: "checkmark.shield")
                        }
                        .disabled(savingExisting || metabaseValidURL == nil || !emailValid || existingPassword.isEmpty)
                        if savingExisting { ProgressView().controlSize(.small) }
                    }
                }
                .padding(10).background(Color(nsColor: .textBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            }
            // Explica por que o botão está desligado (evita "não habilita e não sei porquê").
            if !setupBusy, let reason = disabledReason {
                Label(reason, systemImage: "exclamationmark.circle.fill")
                    .font(.callout).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let setupMsg { Text(setupMsg).font(.callout).foregroundStyle(.green) }
            if let setupErr { Text(setupErr).font(.callout).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true) }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    private var howToCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle").foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text("Como montar o dashboard").font(.subheadline).fontWeight(.medium)
                Text("""
                1. Num servidor, instale o Metabase pelo Catálogo (é pesado — ~1–2 GB de RAM).
                2. No primeiro acesso, crie a conta de administrador e habilite "Uploads" (Admin → Settings → Uploads).
                3. Exporte o CSV aqui e faça o upload no Metabase; ele vira uma tabela.
                4. Monte as perguntas/gráficos e junte num dashboard — que você abre aqui embutido.
                Os dados ficam no seu Metabase (self-hosted) — não vão para nuvem de terceiros.
                """)
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
    }

    // MARK: Ações

    private func auditsFor(currentOnly: Bool) -> [ExternalAudit] {
        if currentOnly { return service.selected.map { [$0.audit] } ?? [] }
        return service.audits.map(\.audit)
    }
    private func exportSummary(currentOnly: Bool) {
        AuditExport.saveText(name: "auditoria-resumo\(currentOnly ? "" : "-historico").csv",
                             contents: AuditDataset.summaryCSV(auditsFor(currentOnly: currentOnly)))
    }
    private func exportFindings(currentOnly: Bool) {
        AuditExport.saveText(name: "auditoria-achados\(currentOnly ? "" : "-historico").csv",
                             contents: AuditDataset.findingsCSV(auditsFor(currentOnly: currentOnly)))
    }
}

// MARK: - Pré-visualização do relatório HTML (WebView, offline)

struct AuditReportPreview: View {
    let html: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Relatório").font(.headline)
                Spacer()
                Button { ReportWindow.open(html: html, title: "Relatório — Uptend"); dismiss() } label: {
                    Label("Abrir em janela", systemImage: "macwindow")
                }
                .help("Abre numa janela redimensionável — use o botão verde (ou ⌃⌘F) para tela cheia na TV")
                Button { openInBrowser() } label: { Label("Abrir no navegador", systemImage: "safari") }
                Button("Fechar") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(12)
            Divider()
            EmbeddedHTML(html: html)
        }
        .frame(minWidth: 1040, idealWidth: 1120, minHeight: 640, idealHeight: 780)
    }

    /// Escreve o HTML num arquivo temporário e abre no navegador padrão.
    private func openInBrowser() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("uptend-relatorio-\(UUID().uuidString.prefix(8)).html")
        do {
            try html.data(using: .utf8)?.write(to: url)
            NSWorkspace.shared.open(url)
        } catch { /* silencioso — a pré-visualização embutida continua disponível */ }
    }
}
