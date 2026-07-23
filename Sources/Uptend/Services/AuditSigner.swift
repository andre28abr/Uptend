import Foundation
import CryptoKit
import UptendCore

// =============================================================================
// ASSINATURA DIGITAL — FASE A2
// Assina o JSON da auditoria com ECDSA P-256 (CryptoKit). A chave privada fica no
// Keychain do Mac; a pública + assinatura + hash vão no manifesto (ReportSignature)
// e no rodapé do relatório. Permite a terceiros verificar que o conteúdo não foi
// adulterado — cadeia de custódia real (não só um hash).
// =============================================================================

enum AuditSigner {
    private static let service = "uptend.signing"
    private static let account = "auditor-ecdsa-p256"

    // Cache em memória: garante a MESMA chave durante toda a sessão mesmo que a
    // gravação no Keychain falhe — senão `fingerprint` e `sign` (que chamam
    // privateKey() separadamente) gerariam chaves distintas e divergiriam. (B3)
    // Acesso sempre pela UI (main thread).
    private static var cached: P256.Signing.PrivateKey?

    /// Chave privada de assinatura (gera e guarda no Keychain na 1ª vez; reusa depois).
    static func privateKey() -> P256.Signing.PrivateKey {
        if let cached { return cached }
        if let b64 = Keychain.get(service: service, account: account),
           let data = Data(base64Encoded: b64),
           let key = try? P256.Signing.PrivateKey(rawRepresentation: data) {
            cached = key
            return key
        }
        let key = P256.Signing.PrivateKey()
        // Se não conseguir persistir, mantém a chave em memória nesta sessão (a
        // continuidade entre execuções depende do Keychain, mas a sessão fica coerente).
        _ = Keychain.set(key.rawRepresentation.base64EncodedString(), service: service, account: account)
        cached = key
        return key
    }

    /// Impressão digital da chave pública (SHA-256, hex maiúsculo).
    static var fingerprint: String {
        let pub = privateKey().publicKey.rawRepresentation
        return SHA256.hash(data: pub).map { String(format: "%02X", $0) }.joined()
    }

    /// Assina os bytes do JSON da auditoria e devolve o manifesto.
    static func sign(_ auditJSON: Data, auditor: String, at date: Date = Date()) -> ReportSignature? {
        let key = privateKey()
        guard let sig = try? key.signature(for: auditJSON) else { return nil }
        return ReportSignature(
            contentHash: HashUtil.sha256(data: auditJSON),
            signatureB64: sig.rawRepresentation.base64EncodedString(),
            publicKeyB64: key.publicKey.rawRepresentation.base64EncodedString(),
            fingerprint: fingerprint,
            auditor: auditor,
            signedAt: ISO8601DateFormatter().string(from: date))
    }

    /// Verifica: o hash bate E a assinatura é válida para a chave pública do manifesto.
    static func verify(_ auditJSON: Data, _ s: ReportSignature) -> Bool {
        guard HashUtil.sha256(data: auditJSON) == s.contentHash,
              let pubData = Data(base64Encoded: s.publicKeyB64),
              let pub = try? P256.Signing.PublicKey(rawRepresentation: pubData),
              let sigData = Data(base64Encoded: s.signatureB64),
              let sig = try? P256.Signing.ECDSASignature(rawRepresentation: sigData) else { return false }
        return pub.isValidSignature(sig, for: auditJSON)
    }
}
