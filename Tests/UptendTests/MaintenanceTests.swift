import Testing
@testable import Uptend

/// Testes das novas funções de manutenção: comparador de Brewfile, favoritos, saúde.
struct MaintenanceTests {

    @Test func brewfileParse() {
        let content = """
        tap "homebrew/bundle"
        brew "node"
        brew "git"
        cask "visual-studio-code"
        cask "figma"
        # comentário
        """
        let parsed = ProfilesService.parseBrewfile(content)
        #expect(parsed.brews == ["node", "git"])
        #expect(parsed.casks == ["visual-studio-code", "figma"])
    }

    @Test func favoriteURLValidation() {
        #expect(FavoritesService.isValidRepoURL("https://github.com/user/repo.git"))
        #expect(FavoritesService.isValidRepoURL("git@github.com:user/repo.git"))
        #expect(!FavoritesService.isValidRepoURL("ftp://x"))
        #expect(!FavoritesService.isValidRepoURL("repo com espaço"))
        #expect(!FavoritesService.isValidRepoURL("-oProxy"))
        #expect(!FavoritesService.isValidRepoURL(""))
    }

    @Test func batteryParse() {
        let output = """
              Battery Information:
                  Cycle Count: 142
                  Condition: Normal
                  Maximum Capacity: 91%
                  State of Charge (%): 78
        """
        let info = HealthService.parseBattery(output)
        #expect(info.present)
        #expect(info.cycles == "142")
        #expect(info.condition == "Normal")
        #expect(info.maxCapacity == "91%")
    }

    @Test func smartParse() {
        let output = """
        NVMExpress:

            APPLE SSD AP0512Z:

              Capacity: 500.28 GB
              SMART Status: Verified
        """
        let disks = HealthService.parseDisks(output)
        #expect(disks.contains { $0.smart == "Verified" })
    }
}
