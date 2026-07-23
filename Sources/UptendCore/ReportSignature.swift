import Foundation

// =============================================================================
// ASSINATURA DIGITAL DO RELATÓRIO — FASE A2
// Manifesto que atesta a integridade da auditoria: hash do conteúdo, assinatura
// (ECDSA P-256), chave pública, impressão digital, auditor e data. Struct pura;
// a assinatura/verificação real (CryptoKit + Keychain) vive no app (AuditSigner).
// =============================================================================

public struct ReportSignature: Codable, Equatable, Sendable {
    public let contentHash: String     // SHA-256 do JSON da auditoria (o que foi assinado)
    public let signatureB64: String    // assinatura ECDSA (raw, base64)
    public let publicKeyB64: String    // chave pública P-256 (raw, base64)
    public let fingerprint: String     // impressão digital da chave (hex curto)
    public let auditor: String         // quem assinou (nome da marca)
    public let signedAt: String        // ISO 8601

    public init(contentHash: String, signatureB64: String, publicKeyB64: String,
                fingerprint: String, auditor: String, signedAt: String) {
        self.contentHash = contentHash; self.signatureB64 = signatureB64
        self.publicKeyB64 = publicKeyB64; self.fingerprint = fingerprint
        self.auditor = auditor; self.signedAt = signedAt
    }

    /// Impressão digital formatada em grupos (ex.: "A1B2 C3D4 …") para leitura humana.
    public var prettyFingerprint: String {
        let chars = Array(fingerprint)
        var groups: [String] = []
        var i = 0
        while i < chars.count {
            let end = min(i + 4, chars.count)
            groups.append(String(chars[i..<end]))
            i = end
        }
        return groups.joined(separator: " ")
    }
}
