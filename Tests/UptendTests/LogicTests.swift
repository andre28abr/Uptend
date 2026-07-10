import Testing
import SwiftUI
@testable import Uptend

/// Testes de lógica pura (parsing, formatação, mapeamentos) — o que tem risco de quebrar.
struct LogicTests {

    @Test func cleanupTargets() {
        // A Lixeira é permanente; caches vão para a Lixeira (reversível).
        let trash = CleanupService.targets(for: "trash")
        #expect(trash.count == 1)
        #expect(trash.first?.isReversible == false)

        let caches = CleanupService.targets(for: "caches")
        #expect(caches.first?.isReversible == true)

        // A subseção "dev" inclui o brew cleanup.
        let dev = CleanupService.targets(for: "dev")
        #expect(dev.contains { $0.isBrewCleanup })

        #expect(CleanupService.targets(for: "inexistente").isEmpty)
    }

    @Test func gitStatusLabels() {
        #expect(GitStatus.synced.label == "Sincronizado")
        #expect(GitStatus.ahead(2).label == "2 à frente")
        #expect(GitStatus.behind(3).label == "3 atrás")
        #expect(GitStatus.dirty.label == "Alterações locais")
    }

    @Test func appearanceColorScheme() {
        #expect(Appearance.system.colorScheme == nil)
        #expect(Appearance.light.colorScheme == .light)
        #expect(Appearance.dark.colorScheme == .dark)
    }

    @Test func everyCategoryHasSubsections() {
        for category in Category.allCases {
            #expect(!category.subsections.isEmpty, "\(category) sem subseções")
        }
    }

    @Test func primaryCategoriesExcludeSettings() {
        #expect(!Category.primary.contains(.settings))
        #expect(Category.allCases.contains(.settings))
    }

    @Test func formatUptime() {
        #expect(SystemService.formatUptime(90) == "1min")
        #expect(SystemService.formatUptime(3660) == "1h 1min")
        #expect(SystemService.formatUptime(90000) == "1d 1h")
    }

    @Test func appOriginLabels() {
        #expect(AppOrigin.appStore.label == "App Store")
        #expect(AppOrigin.other.label == "Manual / Homebrew")
    }

    @MainActor @Test func systemToggles() {
        #expect(SystemService.toggleSections == ["Finder", "Dock", "Teclado e texto", "Capturas de tela"])
        let ids = SystemService.toggles.map(\.id)
        #expect(ids.count == Set(ids).count)
        let shadow = SystemService.toggles.first { $0.id == "screenshadow" }
        #expect(shadow?.inverted == true)
        #expect(shadow?.restart == .systemUIServer)
    }

    @MainActor @Test func residualsEmptyWithoutBundleID() {
        let service = AppsService()
        let app = MacApp(name: "Teste", path: URL(fileURLWithPath: "/Applications/Teste.app"),
                         bundleID: nil, sizeBytes: 0, origin: .other)
        #expect(service.residualURLs(for: app).isEmpty)
    }
}
