import Testing
@testable import Uptend

struct ServerSetupTests {

    @Test func stepsAreWellFormed() {
        let steps = ServerSetup.steps
        #expect(steps.count >= 5)
        // ids únicos, args não-vazios começando por "bash -lc"
        #expect(Set(steps.map(\.id)).count == steps.count)
        for s in steps {
            #expect(!s.title.isEmpty && !s.detail.isEmpty)
            #expect(s.args.first == "bash" && s.args.dropFirst().first == "-lc")
            #expect(!s.args.last!.isEmpty)
        }
    }

    @Test func firewallAllowsSSHBeforeEnabling() {
        // Trava de segurança: liberar a 22 tem que vir ANTES de ativar o ufw.
        let fw = ServerSetup.steps.first { $0.id == "firewall" }!
        let script = fw.args.last!
        let allowIdx = script.range(of: "ufw allow 22")!.lowerBound
        let enableIdx = script.range(of: "ufw --force enable")!.lowerBound
        #expect(allowIdx < enableIdx)
    }
}
