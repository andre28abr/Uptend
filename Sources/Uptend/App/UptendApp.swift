import SwiftUI
import AppKit

@main
struct UptendApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()
    @StateObject private var brew = BrewService()
    @StateObject private var apps = AppsService()
    @StateObject private var system = SystemService()
    @StateObject private var git = GitService()
    @StateObject private var github = GitHubService()
    @StateObject private var clamav = ClamAVService()
    @StateObject private var cleanup = CleanupService()
    @StateObject private var security = SecurityService()
    @StateObject private var docker = DockerService()
    @StateObject private var clipboard = ClipboardService()
    @StateObject private var monitor = MonitorService()
    @StateObject private var schedule = ScheduleService()
    @StateObject private var myPackages = MyPackagesStore()
    @StateObject private var tapProviders = TapProvidersStore()
    @StateObject private var hostStore = HostStore()
    @StateObject private var serverAlerts = ServerAlertsService()
    @StateObject private var externalAudit = ExternalAuditService()
    @StateObject private var vault = UptendVault.shared
    @StateObject private var branding = BrandingStore()
    @StateObject private var riskExceptions = RiskExceptionStore()
    @StateObject private var baseline = BaselineStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environmentObject(brew)
                .environmentObject(apps)
                .environmentObject(system)
                .environmentObject(git)
                .environmentObject(github)
                .environmentObject(clamav)
                .environmentObject(cleanup)
                .environmentObject(security)
                .environmentObject(docker)
                .environmentObject(clipboard)
                .environmentObject(monitor)
                .environmentObject(schedule)
                .environmentObject(myPackages)
                .environmentObject(tapProviders)
                .environmentObject(hostStore)
                .environmentObject(serverAlerts)
                .environmentObject(externalAudit)
                .environmentObject(vault)
                .environmentObject(branding)
                .environmentObject(riskExceptions)
                .environmentObject(baseline)
                .frame(minWidth: 940, minHeight: 580)
                .preferredColorScheme(state.appearance.colorScheme)
                .task { await brew.bootstrap() }
                .task { clipboard.start() }
                .task { monitor.start() }
                .task { externalAudit.migrateLegacyFilesIfPresent() }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
        }

        MenuBarExtra("Uptend", systemImage: "gauge.with.dots.needle.bottom.50percent") {
            MenuBarDashboard()
                .environmentObject(monitor)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Garante que a janela apareça e ganhe foco mesmo rodando o binário direto
/// (fora de um bundle .app, via `swift run`).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Reduz o atraso do tooltip nativo (padrão do macOS é ~1,5s). Em ms.
        // Lido pelo AppKit no início; precisa estar setado antes do primeiro hover.
        UserDefaults.standard.register(defaults: ["NSInitialToolTipDelay": 350])
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
