import Testing
import Foundation
@testable import Uptend

struct MetabaseAPITests {

    @Test func strongPasswordIsComplexEnough() {
        for _ in 0..<50 {
            let p = MetabaseAPI.strongPassword()
            #expect(p.count == 20)
            #expect(p.contains { $0.isUppercase })
            #expect(p.contains { $0.isLowercase })
            #expect(p.contains { $0.isNumber })
            #expect(p.contains { "!@#$%*-_".contains($0) })
        }
    }

    @Test func strongPasswordsAreUnique() {
        let set = Set((0..<20).map { _ in MetabaseAPI.strongPassword() })
        #expect(set.count == 20)   // aleatórias → sem repetição
    }

    @Test func credentialsCodableRoundTrip() throws {
        let cred = MetabaseCredentials.Cred(email: "a@b.com", password: "Xk7#mPq2")
        let data = try JSONEncoder().encode(cred)
        let back = try JSONDecoder().decode(MetabaseCredentials.Cred.self, from: data)
        #expect(back == cred)
    }
}
