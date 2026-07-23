import Testing
import SwiftUI
@testable import Uptend

/// Smoke tests: renderizam as telas de verdade (via `ImageRenderer`, que força a
/// avaliação do `body` — pega crashes/loops de layout) e exercitam os fluxos
/// críticos contra o sistema real. Removem a incerteza do "não vi renderizado".
@MainActor
struct SmokeTests {

    /// Renderiza uma view offscreen (com todos os environment objects injetados);
    /// devolve true se o body avaliou sem travar/crashar.
    private func renders(_ view: some View) -> Bool {
        let hosted = view
            .frame(width: 700, height: 500)
            .environmentObject(AppState())
            .environmentObject(BrewService())
            .environmentObject(AppsService())
            .environmentObject(SystemService())
            .environmentObject(GitService())
            .environmentObject(GitHubService())
            .environmentObject(SecurityService())
            .environmentObject(MyPackagesStore())
            .environmentObject(TapProvidersStore())
            .environmentObject(HostStore())
            .environmentObject(ServerAlertsService())
            .environmentObject(ExternalAuditService(vault: .inMemory()))
            .environmentObject(UptendVault.inMemory())
            .environmentObject(BrandingStore(defaults: UserDefaults(suiteName: "smoke.branding")!))
        return ImageRenderer(content: hosted).nsImage != nil
    }

    // MARK: Renderização (UI)

    @Test func markdownViewRenders() {
        // Inclui o caso que causava o loop infinito e tabelas/código/listas.
        let md = "# Título\n\n#semEspaco\n\n- item **a**\n- item `b`\n\n| A | B |\n|---|---|\n| 1 | 2 |\n\n```swift\nlet x = 1\n```"
        #expect(renders(MarkdownView(text: md)))
    }

    @Test func codeViewRenders() {
        #expect(renders(CodeView(code: "func hi() {\n  let s = \"oi\" // nota\n}", language: "swift")))
    }

    @Test func securityScreensRender() {
        #expect(renders(ExposureView()))
        #expect(renders(AppCheckView()))
        #expect(renders(SecretScanView()))
        #expect(renders(AuditView()))
        #expect(renders(DepsScanView()))
    }

    @Test func mainScreensRender() {
        #expect(renders(ApplicationsView(sub: nil)))
        #expect(renders(GitView(sub: nil)))
        #expect(renders(ReportPanel(initialScope: .complete)))
        #expect(renders(SecurityView(sub: SubSection(id: "status", title: "Status", systemImage: "checklist"))))
        #expect(renders(AppDataView()))
        #expect(renders(EnvironmentSetupView()))
        #expect(renders(BrandingView()))
    }

    @Test func serverScreensRender() {
        // Telas do módulo Servidor/HomeLab, sem host selecionado (mostram o estado vazio).
        // Garante que `body` avalia sem crashar/loopar em cada uma.
        #expect(renders(HLOverviewView()))
        #expect(renders(HLSetupView()))
        #expect(renders(HLMachinesView(sub: nil)))
        #expect(renders(HLContainersView(sub: nil)))
        #expect(renders(HLCatalogView()))
        #expect(renders(HLDeployView()))
        #expect(renders(HLServicesView()))
        #expect(renders(HLSecurityStatusView()))
        #expect(renders(HLMonitorView()))
        #expect(renders(HLAuditView()))
        #expect(renders(HLStorageView(sub: nil)))
        #expect(renders(HLFilesView()))
        #expect(renders(HLBackupsView(sub: nil)))
        #expect(renders(HLNetworkView(sub: nil)))
        #expect(renders(HLUpdatesView()))
        #expect(renders(HLTerminalView()))
    }

    @Test func auditoriaExternaScreensRender() {
        // Aba Auditoria Externa: painel vazio, importar e histórico (sem auditoria carregada).
        #expect(renders(AuditoriaExternaView(sub: SubSection(id: "painel", title: "Painel", systemImage: "gauge"))))
        #expect(renders(AuditoriaExternaView(sub: SubSection(id: "importar", title: "Importar", systemImage: "square.and.arrow.down"))))
        #expect(renders(AuditoriaExternaView(sub: SubSection(id: "historico", title: "Histórico", systemImage: "clock"))))
        // Colunas da aba própria (sidebar / subseções / detalhe).
        #expect(renders(AuditoriaSidebar()))
        #expect(renders(AuditoriaContentColumn()))
        #expect(renders(AuditoriaDetailColumn()))
        // Seções: Relatórios, Dashboard (BI), Coletar de servidor (com varredura ativa integrada) e Frota.
        #expect(renders(AuditReportsView()))
        #expect(renders(AuditBIView()))
        #expect(renders(AuditCollectServerView()))
        #expect(renders(DatabaseAuditView()))
        #expect(renders(FleetView()))
    }

    // MARK: Fluxos críticos (integração, sistema real)

    @Test func systemInfoLoads() async {
        let s = SystemService(); await s.loadInfo()
        #expect(s.info.model != "—" || s.info.chip != "—")   // algo foi lido
    }

    @Test func appsScanFindsRealApps() async {
        let a = AppsService(); await a.scan()
        #expect(!a.apps.isEmpty)
        #expect(a.apps.allSatisfy { !$0.name.isEmpty })
    }

    @Test func exposureRefreshWorks() async {
        let e = ExposureService(); await e.refresh()
        #expect(!e.checks.isEmpty)
        #expect(e.checks.contains { $0.name.contains("Firewall") })
    }

    @Test func appCheckOnSystemAppIsTrusted() async {
        let c = AppCheckService()
        await c.check(path: "/System/Applications/Calculator.app")
        #expect(c.verdict != nil)
        #expect(c.verdict?.gatekeeperAccepted == true)   // app da Apple
        #expect(c.verdict?.appleSigned == true)
    }

    @Test func reportGathersAndRendersHTML() async {
        let data = await ReportBuilder.gather(scope: .hardware, system: SystemService(),
                                              apps: AppsService(), brew: BrewService(), security: SecurityService())
        #expect(data.serialNumber != "—" || data.modelIdentifier != "—")   // identificação real
        let html = SystemReport.render(data, scope: .hardware, format: .html, detail: .summary)
        #expect(html.hasPrefix("<!doctype html>"))
        #expect(html.contains("Inventário do Mac"))
    }

    @Test func securityChecksRun() async {
        let s = SecurityService(); await s.refresh()
        #expect(!s.checks.isEmpty)
    }
}
