import Testing
@testable import Uptend

struct BrewTidyTests {

    @Test func parsesAutoremoveDryRun() {
        let output = """
        ==> Would autoremove 2 unneeded formulae:
        libevent
        unbound
        """
        #expect(BrewService.parseAutoremove(output) == ["libevent", "unbound"])
    }

    @Test func parseAutoremoveIgnoresHeadersAndEmpty() {
        #expect(BrewService.parseAutoremove("==> Would autoremove 0 unneeded formulae:").isEmpty)
        #expect(BrewService.parseAutoremove("").isEmpty)
        #expect(BrewService.parseAutoremove("Warning: nada\n").isEmpty)
    }

    @Test func parseAutoremoveKeepsTappedNames() {
        // Nomes com tap (prefixo) também são válidos.
        let out = "==> Would autoremove 1 unneeded formulae:\nandre28abr/peapod/peapod"
        #expect(BrewService.parseAutoremove(out) == ["andre28abr/peapod/peapod"])
    }
}
