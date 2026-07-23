import Testing
import Foundation
@testable import Uptend

struct CryptoToolsTests {
    @Test func passwordHonorsLength() {
        #expect(PasswordGenerator.generate(length: 24, useDigits: true, useSymbols: true).count == 24)
        #expect(PasswordGenerator.generate(length: 1, useDigits: false, useSymbols: false).count == 1)
        #expect(PasswordGenerator.generate(length: 0, useDigits: false, useSymbols: false).count == 1)   // piso 1
    }

    @Test func passwordExcludesDisabledSets() {
        // Sem dígitos nem símbolos: só letras. Gera um longo para reduzir falso-negativo.
        let onlyLetters = PasswordGenerator.generate(length: 400, useDigits: false, useSymbols: false)
        #expect(onlyLetters.allSatisfy { $0.isLetter })
        #expect(onlyLetters.contains { $0.isNumber } == false)
        let withDigits = PasswordGenerator.generate(length: 400, useDigits: true, useSymbols: false)
        #expect(withDigits.allSatisfy { $0.isLetter || $0.isNumber })
        #expect(withDigits.contains { PasswordGenerator.symbols.contains($0) } == false)
    }

    @Test func sha256KnownVectors() {
        // Vetores conhecidos.
        #expect(HashUtil.sha256(data: Data()) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        #expect(HashUtil.sha256(data: Data("abc".utf8)) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func sha256FileMatchesData() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("uptend-hash-\(UUID().uuidString).bin")
        let bytes = Data((0..<1000).map { UInt8($0 % 256) })
        try bytes.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(HashUtil.sha256(fileAt: url) == HashUtil.sha256(data: bytes))
    }
}
