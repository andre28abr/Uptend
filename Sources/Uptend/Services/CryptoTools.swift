import Foundation
import CryptoKit

/// Gera senhas fortes localmente (nada sai da máquina — Privacy by Design).
enum PasswordGenerator {
    static let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    static let digits = "0123456789"
    static let symbols = "!@#$%^&*()-_=+[]{}"

    static func generate(length: Int, useDigits: Bool, useSymbols: Bool) -> String {
        var pool = letters
        if useDigits { pool += digits }
        if useSymbols { pool += symbols }

        let characters = Array(pool)
        var rng = SystemRandomNumberGenerator()
        let count = max(1, length)
        return String((0..<count).map { _ in characters[Int.random(in: 0..<characters.count, using: &rng)] })
    }
}

/// Calcula hashes de arquivos (verificação de integridade de downloads).
enum HashUtil {
    static func sha256(data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Lê o arquivo em blocos, para não carregar tudo na memória.
    static func sha256(fileAt url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let chunk = handle.readData(ofLength: 1 << 20) // 1 MB
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
