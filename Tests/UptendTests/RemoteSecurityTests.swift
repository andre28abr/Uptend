import Testing
@testable import Uptend

struct RemoteSecurityTests {

    @Test func firewallStates() {
        #expect(RemoteSecurity.firewallCheck("NOTINSTALLED").level == 1)
        #expect(RemoteSecurity.firewallCheck("Status: active").level == 0)
        #expect(RemoteSecurity.firewallCheck("Status: inactive").level == 1)
    }

    @Test func sshChecksFromRealOutput() {
        // Saída real do uptend-lab.
        let out = "permitrootlogin prohibit-password\npasswordauthentication yes"
        let checks = RemoteSecurity.sshChecks(out)
        let root = checks.first { $0.title.contains("root") }
        let pass = checks.first { $0.title.contains("senha") }
        #expect(root?.level == 0)          // prohibit-password = só por chave
        #expect(pass?.level == 1)          // senha habilitada = atenção
    }

    @Test func sshRootYesIsProblem() {
        let checks = RemoteSecurity.sshChecks("permitrootlogin yes\npasswordauthentication no")
        #expect(checks.first { $0.title.contains("root") }?.level == 2)
        #expect(checks.first { $0.title.contains("senha") }?.level == 0)
    }

    @Test func otherChecks() {
        #expect(RemoteSecurity.fail2banCheck("active").level == 0)
        #expect(RemoteSecurity.fail2banCheck("inactive").level == 1)
        #expect(RemoteSecurity.unattendedCheck("yes").level == 0)
        #expect(RemoteSecurity.unattendedCheck("no").level == 1)
        #expect(RemoteSecurity.securityUpdatesCheck("0").level == 0)
        #expect(RemoteSecurity.securityUpdatesCheck("3").level == 2)
    }
}
