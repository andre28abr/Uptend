import Testing
import Foundation
@testable import Uptend

/// Testes dos interpretadores de status de segurança e das ferramentas (senha, hash).
struct SecurityToolsTests {

    // MARK: Interpretação de status

    @Test func fileVaultInterpretation() {
        #expect(SecurityService.interpretFileVault("FileVault is On.").1 == .ok)
        #expect(SecurityService.interpretFileVault("FileVault is Off.").1 == .warning)
    }

    @Test func firewallInterpretation() {
        #expect(SecurityService.interpretFirewall("Firewall is enabled. (State = 1)").1 == .ok)
        #expect(SecurityService.interpretFirewall("Firewall is disabled. (State = 0)").1 == .warning)
    }

    @Test func gatekeeperInterpretation() {
        #expect(SecurityService.interpretGatekeeper("assessments enabled").1 == .ok)
        #expect(SecurityService.interpretGatekeeper("assessments disabled").1 == .warning)
    }

    @Test func sipInterpretation() {
        #expect(SecurityService.interpretSIP("System Integrity Protection status: enabled.").1 == .ok)
        #expect(SecurityService.interpretSIP("System Integrity Protection status: disabled.").1 == .warning)
    }

    @Test func updatesInterpretation() {
        #expect(SecurityService.interpretUpdates("No new software available.").status == .ok)
        let listed = """
        Software Update found the following new software:
        * Label: macOS Sequoia 15.5
        * Label: Safari 18.5
        """
        let result = SecurityService.interpretUpdates(listed)
        #expect(result.status == .warning)
        #expect(result.detail.contains("2"))
    }

    // MARK: Gerador de senhas

    @Test func passwordLengthAndCharset() {
        let onlyLetters = PasswordGenerator.generate(length: 30, useDigits: false, useSymbols: false)
        #expect(onlyLetters.count == 30)
        #expect(onlyLetters.allSatisfy { PasswordGenerator.letters.contains($0) })

        let withDigits = PasswordGenerator.generate(length: 200, useDigits: true, useSymbols: false)
        #expect(withDigits.allSatisfy { PasswordGenerator.letters.contains($0) || PasswordGenerator.digits.contains($0) })
        #expect(!withDigits.contains { PasswordGenerator.symbols.contains($0) })
    }

    @Test func passwordMinimumLength() {
        #expect(PasswordGenerator.generate(length: 0, useDigits: true, useSymbols: true).count == 1)
    }

    // MARK: Hash

    @Test func sha256KnownVector() {
        // SHA-256 de "abc" é um vetor de teste conhecido.
        let data = Data("abc".utf8)
        #expect(HashUtil.sha256(data: data) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
