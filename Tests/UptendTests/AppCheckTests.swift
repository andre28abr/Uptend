import Testing
@testable import Uptend

struct AppCheckTests {

    @Test func parsesSpctlAccepted() {
        let out = "/Applications/Foo.app: accepted\nsource=Notarized Developer ID\norigin=Developer ID Application: Foo (ABCDE12345)"
        let r = AppCheckService.parseSpctl(out)
        #expect(r.accepted)
        #expect(r.source == "Notarized Developer ID")
    }

    @Test func parsesSpctlRejected() {
        let r = AppCheckService.parseSpctl("/Applications/Bar.app: rejected\nsource=no usable signature")
        #expect(!r.accepted)
        #expect(r.source == "no usable signature")
    }

    @Test func parsesCodesignAuthorityAndTeam() {
        let out = """
        Executable=/Applications/Foo.app/Contents/MacOS/Foo
        Authority=Developer ID Application: Foo Inc (ABCDE12345)
        Authority=Developer ID Certification Authority
        Authority=Apple Root CA
        TeamIdentifier=ABCDE12345
        """
        let r = AppCheckService.parseCodesign(out)
        #expect(r.authority == "Developer ID Application: Foo Inc (ABCDE12345)")
        #expect(r.teamID == "ABCDE12345")
    }

    @Test func codesignTeamNotSetBecomesEmpty() {
        let r = AppCheckService.parseCodesign("Authority=Software Signing\nTeamIdentifier=not set")
        #expect(r.authority == "Software Signing")
        #expect(r.teamID == "")
    }

    // MARK: Veredito

    private func verdict(signed: Bool = true, valid: Bool = true, accepted: Bool = true,
                         notarized: Bool = true, apple: Bool = false, quarantined: Bool = false,
                         adhoc: Bool = false, teamID: String = "TEAM") -> AppVerdict {
        AppVerdict(name: "X", signed: signed, valid: valid, adhoc: adhoc, authority: "", teamID: teamID,
                   notarized: notarized, appleSigned: apple, gatekeeperAccepted: accepted,
                   gatekeeperSource: "", quarantined: quarantined)
    }

    @Test func selfMadeAppGetsFriendlyNote() {
        // App próprio: ad-hoc, sem team, não notarizado.
        let mine = verdict(notarized: false, adhoc: true, teamID: "")
        #expect(mine.selfMadeLike)
        #expect(mine.note != nil)
        // App notarizado não recebe a nota de "app próprio".
        let trusted = verdict()
        #expect(!trusted.selfMadeLike)
        #expect(trusted.note == nil)
    }

    @Test func trustLevels() {
        #expect(verdict().level == .trusted)                              // assinado, notarizado, aceito
        #expect(verdict(notarized: false, apple: true).level == .trusted) // app da Apple
        #expect(verdict(notarized: false).level == .caution)             // assinado mas não notarizado
        #expect(verdict(quarantined: true).level == .caution)            // em quarentena
        #expect(verdict(accepted: false).level == .danger)               // Gatekeeper bloqueia
        #expect(verdict(signed: false).level == .danger)                 // sem assinatura
        #expect(verdict(valid: false).level == .danger)                  // assinatura inválida
    }
}
