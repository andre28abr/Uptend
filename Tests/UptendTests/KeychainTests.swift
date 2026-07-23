import Testing
import Foundation
@testable import Uptend

/// Round-trip do cofre nativo. Também é a regressão do M4: garante que o Keychain
/// FUNCIONA com a configuração atual (sem kSecUseDataProtectionKeychain, que exigiria
/// entitlements e quebraria a gravação num app ad-hoc).
struct KeychainTests {
    @Test func setGetDeleteRoundTrip() {
        let svc = "uptend.test"
        let acc = "acct-\(UUID().uuidString)"
        #expect(Keychain.get(service: svc, account: acc) == nil)      // começa vazio
        #expect(Keychain.set("segredo-áéî-123", service: svc, account: acc))
        #expect(Keychain.get(service: svc, account: acc) == "segredo-áéî-123")
        // upsert: sobrescreve
        #expect(Keychain.set("novo-valor", service: svc, account: acc))
        #expect(Keychain.get(service: svc, account: acc) == "novo-valor")
        #expect(Keychain.delete(service: svc, account: acc))
        #expect(Keychain.get(service: svc, account: acc) == nil)      // sumiu
        #expect(Keychain.delete(service: svc, account: acc))          // deletar de novo = ok (não-encontrado)
    }
}
