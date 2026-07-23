import Testing
import Foundation
@testable import Uptend

@MainActor
struct RemoteHostTests {
    private func validHost() -> RemoteHost {
        RemoteHost(name: "srv", kind: .server, address: "192.168.1.10", user: "andre",
                   keyPath: "~/.ssh/uptend_ed25519")
    }

    @Test func removingHostClearsDbPassword() {
        // B2: ao remover o host, a senha do banco não pode ficar órfã no Keychain.
        let store = HostStore(defaults: UserDefaults(suiteName: "uptend-test-\(UUID().uuidString)")!)
        let host = validHost()
        DBCredentialStore.setPassword("s3cr3t", for: host)
        #expect(DBCredentialStore.password(for: host) == "s3cr3t")
        _ = store.add(host)
        store.remove(host)
        #expect(DBCredentialStore.password(for: host) == nil)   // limpa junto
    }

    @Test func isValidRejectsBadJumpHost() {
        var h = validHost()
        #expect(h.isValid)
        h.jumpHost = "bastion; rm -rf ~"          // B7: metacaractere invalida o host
        #expect(h.isValid == false)
        h.jumpHost = "user@bastion:22"            // bastion bem-formado é aceito
        #expect(h.isValid)
    }

    @Test func dbCredentialRejectsBadDatabaseName() {
        // M1: o nome do banco malformado invalida a CREDENCIAL (validada à parte do host).
        #expect(DBCredential(kind: "mysql", user: "ro", host: "localhost", port: 3306, database: "loja").isValid)
        #expect(DBCredential(kind: "mysql", user: "ro", host: "localhost", port: 3306, database: "x'; --").isValid == false)
    }
}
