import Foundation
import Network
import Security
import UptendCore

// =============================================================================
// SCANNER TLS NATIVO (modo pentester, opt-in)
// Faz o handshake TLS com um host:porta usando os frameworks da Apple
// (Network + Security) — SEM depender de nmap/openssl/testssl. É sondagem ATIVA
// (envia pacotes): só usar com AUTORIZAÇÃO. Lê: versão TLS negociada, cifra,
// certificado (validade/emissor/chave/auto-assinado) e se aceita TLS 1.0/1.1.
// =============================================================================

struct TLSProbeResult: Identifiable, Sendable {
    let id = UUID()
    let host: String
    let port: Int
    var reachable = false
    var speaksTLS = false
    var tlsVersion: String?
    var cipher: String?
    var certSubject: String?
    var notAfter: Date?
    var daysLeft: Int?
    var selfSigned = false
    var keyBits: Int?
    var acceptsLegacy = false
    var issues: [String] = []
    var note: String?

    /// Gravidade visual do resultado (para a interface).
    var worst: AuditSeverityLevel {
        if issues.contains(where: { $0.contains("expirado") || $0.contains("1.0") }) { return .high }
        if !issues.isEmpty { return .medium }
        if speaksTLS { return .ok }
        return .info
    }
}

enum AuditSeverityLevel { case ok, info, low, medium, high }

/// Referência mutável para capturar o certificado dentro do verify block.
/// Estado mutável do handshake, compartilhado entre o verify block (fila global),
/// o stateUpdateHandler (fila da conexão) e o finish() (fila serial `done`).
/// Uma classe evita a mutação de `var` capturada em código concorrente (erro no
/// modo Swift 6); a serialização de escrita/leitura é garantida por `done.sync`.
private final class ProbeBox: @unchecked Sendable {
    var cert: SecCertificate?
    var result: TLSProbeResult
    init(result: TLSProbeResult) { self.result = result }
}

enum TLSScanner {

    /// Sonda uma porta: handshake moderno + verificação de TLS legado.
    static func probe(host: String, port: Int, timeoutMs: Int = 6000) async -> TLSProbeResult {
        var r = await handshake(host: host, port: port, minVersion: .TLSv12, maxVersion: .TLSv13, timeoutMs: timeoutMs)
        guard r.reachable else { r.note = "Sem resposta (porta fechada/filtrada ou host inacessível)."; return r }
        if !r.speaksTLS {
            // conectou TCP mas não fez TLS moderno — pode ser texto puro ou só TLS legado
            let legacy = await handshake(host: host, port: port, minVersion: legacyTLS10, maxVersion: .TLSv13, timeoutMs: timeoutMs)
            if legacy.speaksTLS {
                r = legacy
                r.acceptsLegacy = true
                r.issues.append("Aceita TLS 1.0/1.1 (obsoleto)")
            } else {
                r.note = "A porta respondeu, mas não completou um handshake TLS (provavelmente serviço em texto puro)."
                return r
            }
        } else {
            // fala TLS moderno; testa se TAMBÉM aceita legado
            let legacy = await handshake(host: host, port: port, minVersion: legacyTLS10, maxVersion: legacyTLS11, timeoutMs: timeoutMs)
            if legacy.speaksTLS {
                r.acceptsLegacy = true
                r.issues.append("Aceita TLS 1.0/1.1 (obsoleto)")
            }
        }
        // Deriva problemas do certificado
        if let d = r.daysLeft {
            if d < 0 { r.issues.append("Certificado expirado") }
            else if d < 30 { r.issues.append("Certificado expira em \(d) dias") }
        }
        if r.selfSigned { r.issues.append("Certificado auto-assinado") }
        if let k = r.keyBits, k < 2048 { r.issues.append("Chave fraca (\(k) bits)") }
        return r
    }

    /// Converte os resultados da varredura em achados de auditoria (para relatório + nota).
    /// Um achado por porta ALCANÇÁVEL; ids "tls-scan-<porta>" (mapeiam a tls-config nos frameworks).
    static func findings(from results: [TLSProbeResult]) -> [AuditFinding] {
        results.compactMap { r in
            guard r.reachable else { return nil }   // portas fechadas não viram achado
            let svc = PortService.info(r.port)
            let svcName = svc?.name ?? "porta \(r.port)"
            let svcDesc = svc?.description ?? ""

            var severity: AuditSeverity = .ok
            var title = ""
            var evidence = "Porta \(r.port) (\(svcName)) aberta"
            var recommendation: String? = nil

            if r.speaksTLS {
                evidence += " · \(r.tlsVersion ?? "TLS")"
                if let c = r.certSubject { evidence += " · cert: \(c)" }
                if let d = r.daysLeft { evidence += " · expira em \(d) dia(s)" }
                if r.issues.isEmpty {
                    severity = .ok
                    title = "\(svcName) (porta \(r.port)) com TLS saudável"
                } else {
                    // pior caso define a severidade
                    if r.issues.contains(where: { $0.contains("expirado") }) || r.acceptsLegacy {
                        severity = .high
                    } else { severity = .medium }
                    title = "\(svcName) (porta \(r.port)): \(r.issues.joined(separator: ", "))"
                    evidence += " · " + r.issues.joined(separator: "; ")
                    recommendation = "Ajuste o TLS do serviço (só TLS 1.2/1.3; renove/valide o certificado)."
                }
            } else {
                // aberta, sem TLS
                if PortService.expectsTLS(r.port) {
                    severity = .medium
                    title = "\(svcName) (porta \(r.port)) sem TLS onde se espera criptografia"
                    recommendation = "Habilite TLS neste serviço."
                } else {
                    severity = .ok
                    title = "\(svcName) (porta \(r.port)) aberta (sem TLS)"
                }
                evidence += svcDesc.isEmpty ? "" : " — \(svcDesc)"
            }

            let impact = severity > .ok
                ? "Comunicação sem criptografia forte pode ser interceptada/alterada na rede (man-in-the-middle)."
                : nil
            return AuditFinding(id: "tls-scan-\(r.port)", title: title, severity: severity,
                                category: "Segurança / TLS", cis: nil, evidence: evidence,
                                recommendation: recommendation, businessImpact: impact)
        }
    }

    // TLS 1.0/1.1 são sondados DE PROPÓSITO (achado "aceita TLS legado"). Os símbolos
    // `.TLSv10`/`.TLSv11` estão depreciados; os valores de protocolo (RFC 2246/4346) não
    // mudam, então usamos o raw value — a inicialização não falha para constantes válidas.
    private static let legacyTLS10 = tls_protocol_version_t(rawValue: 0x0301)!  // TLS 1.0
    private static let legacyTLS11 = tls_protocol_version_t(rawValue: 0x0302)!  // TLS 1.1

    private static func handshake(host: String, port: Int,
                                  minVersion: tls_protocol_version_t, maxVersion: tls_protocol_version_t,
                                  timeoutMs: Int) async -> TLSProbeResult {
        await withCheckedContinuation { (cont: CheckedContinuation<TLSProbeResult, Never>) in
            let box = ProbeBox(result: TLSProbeResult(host: host, port: port))

            let tls = NWProtocolTLS.Options()
            let sec = tls.securityProtocolOptions
            sec_protocol_options_set_min_tls_protocol_version(sec, minVersion)
            sec_protocol_options_set_max_tls_protocol_version(sec, maxVersion)
            // Aceita qualquer certificado — estamos INSPECIONANDO, não validando confiança.
            sec_protocol_options_set_verify_block(sec, { _, trust, complete in
                let secTrust = sec_trust_copy_ref(trust).takeRetainedValue()
                if let chain = SecTrustCopyCertificateChain(secTrust) as? [SecCertificate], let leaf = chain.first {
                    box.cert = leaf
                }
                complete(true)
            }, DispatchQueue.global())

            guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
                cont.resume(returning: box.result); return
            }
            let conn = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: NWParameters(tls: tls))

            let done = DispatchQueue(label: "tls.probe.\(port)")
            var finished = false
            func finish() {
                done.sync {
                    guard !finished else { return }
                    finished = true
                    conn.cancel()
                    cont.resume(returning: box.result)
                }
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(timeoutMs)) { finish() }

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    box.result.reachable = true
                    if let md = conn.metadata(definition: NWProtocolTLS.definition) as? NWProtocolTLS.Metadata {
                        let m = md.securityProtocolMetadata
                        let v = sec_protocol_metadata_get_negotiated_tls_protocol_version(m)
                        box.result.speaksTLS = true
                        box.result.tlsVersion = versionName(v)
                        box.result.cipher = cipherName(sec_protocol_metadata_get_negotiated_tls_ciphersuite(m))
                    }
                    if let cert = box.cert { fill(&box.result, from: cert) }
                    finish()
                case .failed:
                    box.result.reachable = true      // TCP respondeu mas TLS falhou nesta faixa de versão
                    finish()
                case .cancelled:
                    finish()
                default:
                    break
                }
            }
            conn.start(queue: .global())
        }
    }

    // MARK: Extração do certificado

    private static func fill(_ r: inout TLSProbeResult, from cert: SecCertificate) {
        r.certSubject = SecCertificateCopySubjectSummary(cert) as String?
        if let notAfter = validity(cert) {
            r.notAfter = notAfter
            r.daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: notAfter).day
        }
        if let subj = SecCertificateCopyNormalizedSubjectSequence(cert),
           let iss = SecCertificateCopyNormalizedIssuerSequence(cert) {
            r.selfSigned = CFEqual(subj, iss)
        }
        if let key = SecCertificateCopyKey(cert),
           let attrs = SecKeyCopyAttributes(key) as? [String: Any],
           let bits = attrs[kSecAttrKeySizeInBits as String] as? Int {
            r.keyBits = bits
        }
    }

    private static func validity(_ cert: SecCertificate) -> Date? {
        let keys = [kSecOIDX509V1ValidityNotAfter] as CFArray
        guard let values = SecCertificateCopyValues(cert, keys, nil) as? [CFString: Any],
              let entry = values[kSecOIDX509V1ValidityNotAfter] as? [CFString: Any],
              let num = entry[kSecPropertyKeyValue] as? Double else { return nil }
        // Valor é "tempo absoluto" (segundos desde 2001-01-01).
        return Date(timeIntervalSinceReferenceDate: num)
    }

    // MARK: Nomes

    private static func versionName(_ v: tls_protocol_version_t) -> String {
        switch v {
        case .TLSv10: "TLS 1.0"; case .TLSv11: "TLS 1.1"; case .TLSv12: "TLS 1.2"; case .TLSv13: "TLS 1.3"
        case .DTLSv10: "DTLS 1.0"; case .DTLSv12: "DTLS 1.2"; @unknown default: "TLS ?"
        }
    }

    private static func cipherName(_ c: tls_ciphersuite_t) -> String {
        switch c {
        case .AES_128_GCM_SHA256: "TLS_AES_128_GCM_SHA256"
        case .AES_256_GCM_SHA384: "TLS_AES_256_GCM_SHA384"
        case .CHACHA20_POLY1305_SHA256: "TLS_CHACHA20_POLY1305_SHA256"
        default: String(format: "0x%04X", c.rawValue)
        }
    }
}
