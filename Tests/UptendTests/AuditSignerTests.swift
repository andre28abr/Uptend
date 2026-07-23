import Testing
import Foundation
import CryptoKit
@testable import Uptend
@testable import UptendCore

@MainActor
struct AuditSignerTests {

    @Test func signThenVerifySucceeds() {
        let data = Data("conteúdo da auditoria — original".utf8)
        let sig = AuditSigner.sign(data, auditor: "André Souza")
        #expect(sig != nil)
        #expect(AuditSigner.verify(data, sig!))
    }

    @Test func tamperingInvalidatesSignature() {
        let data = Data("relatório íntegro".utf8)
        let sig = AuditSigner.sign(data, auditor: "Auditor")!
        // Muda 1 byte → assinatura deve reprovar.
        var tampered = data
        tampered.append(0x21)
        #expect(AuditSigner.verify(tampered, sig) == false)
    }

    @Test func wrongContentHashRejected() {
        let data = Data("A".utf8)
        var sig = AuditSigner.sign(data, auditor: "x")!
        // Manifesto com hash trocado (ataque) → reprovado mesmo com assinatura "válida".
        sig = ReportSignature(contentHash: "deadbeef", signatureB64: sig.signatureB64,
                              publicKeyB64: sig.publicKeyB64, fingerprint: sig.fingerprint,
                              auditor: sig.auditor, signedAt: sig.signedAt)
        #expect(AuditSigner.verify(data, sig) == false)
    }

    @Test func signatureCarriesMetadata() {
        let sig = AuditSigner.sign(Data("x".utf8), auditor: "Maria")!
        #expect(sig.auditor == "Maria")
        #expect(!sig.fingerprint.isEmpty)
        #expect(sig.contentHash == HashUtil.sha256(data: Data("x".utf8)))
        #expect(sig.prettyFingerprint.contains(" "))   // agrupado
    }

    @Test func wrongPublicKeyRejected() {
        // Assinatura de OUTRO signatário (chave pública trocada por outra válida) → reprova.
        let data = Data("relatório".utf8)
        let sig = AuditSigner.sign(data, auditor: "x")!
        let otherPub = P256.Signing.PrivateKey().publicKey.rawRepresentation.base64EncodedString()
        let forged = ReportSignature(contentHash: sig.contentHash, signatureB64: sig.signatureB64,
                                     publicKeyB64: otherPub, fingerprint: sig.fingerprint,
                                     auditor: sig.auditor, signedAt: sig.signedAt)
        #expect(AuditSigner.verify(data, forged) == false)
    }

    @Test func malformedSignatureFailsGracefully() {
        let data = Data("x".utf8)
        let sig = AuditSigner.sign(data, auditor: "x")!
        // base64/assinatura inválidos → verify retorna false, sem crash.
        let bad = ReportSignature(contentHash: sig.contentHash, signatureB64: "não-é-base64!!",
                                  publicKeyB64: "@@@", fingerprint: sig.fingerprint,
                                  auditor: sig.auditor, signedAt: sig.signedAt)
        #expect(AuditSigner.verify(data, bad) == false)
    }

    @Test func privateKeyIsStableAcrossCalls() {
        // B3: a chave privada (e o fingerprint) deve ser a MESMA entre chamadas —
        // senão assinatura e fingerprint divergiriam.
        #expect(AuditSigner.privateKey().rawRepresentation == AuditSigner.privateKey().rawRepresentation)
        #expect(AuditSigner.fingerprint == AuditSigner.fingerprint)
        // E o fingerprint do manifesto bate com a chave usada para assinar.
        let sig = AuditSigner.sign(Data("y".utf8), auditor: "x")!
        #expect(sig.fingerprint == AuditSigner.fingerprint)
    }

    @Test func signatureBlockRendersInReport() throws {
        let url = try #require(Bundle.module.url(forResource: "lab-audit", withExtension: "json", subdirectory: "Fixtures"))
        let data = try Data(contentsOf: url)
        let audit = try ExternalAuditParser.parse(data)
        let sig = AuditSigner.sign(data, auditor: "André")!
        let html = AuditReport.executiveHTML(audit, signature: sig)
        #expect(html.contains("Assinatura digital"))
        #expect(html.contains("André"))
        // Sem assinatura, o bloco não aparece.
        #expect(AuditReport.executiveHTML(audit).contains("Assinatura digital") == false)
    }
}
