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
    @StateObject private var cleanup = CleanupService()
    @StateObject private var security = SecurityService()
    @StateObject private var docker = DockerService()
    @StateObject private var clipboard = ClipboardService()
    @StateObject private var monitor = MonitorService()
    @StateObject private var schedule = ScheduleService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environmentObject(brew)
                .environmentObject(apps)
                .environmentObject(system)
                .environmentObject(git)
                .environmentObject(cleanup)
                .environmentObject(security)
                .environmentObject(docker)
                .environmentObject(clipboard)
                .environmentObject(monitor)
                .environmentObject(schedule)
                .frame(minWidth: 940, minHeight: 580)
                .preferredColorScheme(state.appearance.colorScheme)
                .task { await brew.bootstrap() }
                .task { clipboard.start() }
                .task { monitor.start() }
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
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
