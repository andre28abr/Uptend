import Testing
@testable import Uptend

struct AppsTests {

    @Test func detectsAdminRequiredFromBrewLog() {
        // Casos típicos de cask .pkg que exige sudo.
        #expect(BrewService.logSuggestsAdmin("Error: sudo: a terminal is required to read the password"))
        #expect(BrewService.logSuggestsAdmin("Password is required to install this package"))
        #expect(BrewService.logSuggestsAdmin("This cask requires administrator privileges"))
    }

    @Test func normalLogDoesNotFlagAdmin() {
        #expect(!BrewService.logSuggestsAdmin("==> Downloading\n==> Installing Cask foo\n🍺 foo was installed"))
        #expect(!BrewService.logSuggestsAdmin(""))
    }
}
