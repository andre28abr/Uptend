import Foundation

// =============================================================================
// AUDITORIA EXTERNA — mapeamento de conformidade (frameworks)
// Relaciona cada achado a controles de CIS, ISO/IEC 27001 (Anexo A), NIST CSF e
// OWASP Top 10 (2021), e calcula a ADERÊNCIA (dos controles que a auditoria
// verifica — não é certificação completa). Base dos relatórios turbinados.
// Lógica pura → testável.
// =============================================================================

/// Referências de frameworks para um achado.
public struct FrameworkRefs: Equatable, Sendable {
    public let cis: String?
    public let iso27001: String?     // ex.: "A.9.4.2"
    public let nist: String?         // ex.: "PR.AC-7"
    public let owasp: String?        // ex.: "A07:2021"
    public let pci: String?          // requisito PCI-DSS, ex.: "8"
    public let cisv8: String?        // controle CIS v8, ex.: "6"
    public let soc2: String?         // critério SOC 2, ex.: "CC6.1"
}

public enum ComplianceFramework: String, CaseIterable, Sendable {
    case cis = "CIS Benchmarks"
    case iso = "ISO/IEC 27001"
    case nist = "NIST CSF"
    case owasp = "OWASP Top 10"
    case pci = "PCI-DSS"
    case cisv8 = "CIS Controls v8"
    case soc2 = "SOC 2"
}

/// Cobertura de um framework: de X controles verificados, Y atendidos.
public struct FrameworkCoverage: Identifiable, Equatable, Sendable {
    public let framework: ComplianceFramework
    public let met: Int
    public let checked: Int
    public var id: String { framework.rawValue }
    public var percent: Int { checked == 0 ? 0 : Int(Double(met) / Double(checked) * 100) }
}

public enum ComplianceMap {

    /// Nome amigável das funções do NIST CSF (pela sigla do prefixo).
    public static func nistFunction(_ ref: String) -> String {
        switch ref.prefix(2) {
        case "ID": "Identificar"; case "PR": "Proteger"; case "DE": "Detectar"
        case "RS": "Responder"; case "RC": "Recuperar"; default: "—"
        }
    }

    /// Nome da categoria do OWASP Top 10 (2021).
    public static func owaspName(_ ref: String) -> String {
        switch ref {
        case "A01:2021": "Quebra de Controle de Acesso"
        case "A02:2021": "Falhas Criptográficas"
        case "A03:2021": "Injeção"
        case "A04:2021": "Design Inseguro"
        case "A05:2021": "Configuração Incorreta de Segurança"
        case "A06:2021": "Componentes Vulneráveis/Desatualizados"
        case "A07:2021": "Falhas de Identificação e Autenticação"
        case "A08:2021": "Falhas de Integridade de Software/Dados"
        case "A09:2021": "Falhas de Registro e Monitoramento"
        case "A10:2021": "SSRF"
        default: "—"
        }
    }

    /// Chave-base do achado (remove o "-ok" e o sufixo do dispositivo de disco).
    static func baseKey(_ id: String) -> String {
        var k = id
        if k.hasSuffix("-ok") { k = String(k.dropLast(3)) }
        for p in ["disk-smart", "disk-realloc", "disk-space"] where k.hasPrefix(p) { return p }
        if k.hasPrefix("cert-") { return "cert-tls" }   // ids têm sufixo do arquivo do certificado
        if k.hasPrefix("tls-") { return "tls-config" }
        return k
    }

    /// Vários controles têm ids diferentes para "conforme" e "não conforme" que NÃO
    /// compartilham token (ex.: `firewall-ok` vs `firewall-inactive`, `umask-strict-ok`
    /// vs `umask-loose`). Para baseline/comparação precisamos de uma IDENTIDADE canônica
    /// estável do controle, igual numa máquina boa ou ruim.
    private static let controlAlias: [String: String] = [
        "firewall-ok": "firewall", "firewall-inactive": "firewall",
        "auditd-ok": "auditd", "auditd-missing": "auditd",
        "auto-updates-ok": "auto-updates", "auto-updates-missing": "auto-updates",
        "fail2ban-ok": "fail2ban", "fail2ban-missing": "fail2ban",
        "mac-ok": "mac", "mac-inactive": "mac", "mac-missing": "mac",
        "rootkit-tool-ok": "rootkit-tool", "rootkit-tool-missing": "rootkit-tool",
        "kernel-net-ok": "kernel-net-hardening", "kernel-net-hardening": "kernel-net-hardening",
        "uid0-unique-ok": "uid0-unique", "uid0-multiple": "uid0-unique",
        "umask-strict-ok": "umask", "umask-loose": "umask",
        "fw-default-deny-ok": "fw-default", "fw-default-allow": "fw-default",
        "updates-ok": "updates", "updates-pending": "updates", "updates-security-pending": "updates",
    ]

    /// Identidade canônica do controle (unifica variantes conforme/não conforme).
    public static func controlKey(_ id: String) -> String {
        controlAlias[id] ?? baseKey(id)
    }

    // Mapa base-key → (ISO, NIST, OWASP). O CIS vem do próprio achado quando existe.
    private static let table: [String: (iso: String, nist: String, owasp: String?)] = [
        "ssh-root-login":      ("A.9.2.3", "PR.AC-4", "A07:2021"),
        "ssh-password-auth":   ("A.9.4.2", "PR.AC-7", "A07:2021"),
        "ssh-maxauthtries":    ("A.9.4.2", "PR.AC-7", "A07:2021"),
        "firewall":            ("A.13.1.1", "PR.AC-5", "A05:2021"),
        "firewall-inactive":   ("A.13.1.1", "PR.AC-5", "A05:2021"),
        "fail2ban":            ("A.12.4.1", "DE.CM-1", "A09:2021"),
        "fail2ban-missing":    ("A.12.4.1", "DE.CM-1", "A09:2021"),
        "auto-updates":        ("A.12.6.1", "PR.IP-12", "A06:2021"),
        "auto-updates-missing":("A.12.6.1", "PR.IP-12", "A06:2021"),
        "updates-pending":     ("A.12.6.1", "ID.RA-1", "A06:2021"),
        "updates-security-pending": ("A.12.6.1", "ID.RA-1", "A06:2021"),
        "updates":             ("A.12.6.1", "ID.RA-1", "A06:2021"),
        "os-eol":              ("A.12.6.1", "PR.IP-12", "A06:2021"),
        "exposed-ports":       ("A.13.1.3", "PR.AC-5", "A05:2021"),
        "disk-space":          ("A.12.1.3", "PR.DS-4", nil),
        "disk-smart":          ("A.11.2.4", "PR.DS-4", nil),
        "disk-realloc":        ("A.11.2.4", "PR.DS-4", nil),
        "reboot-required":     ("A.12.6.1", "PR.IP-12", "A06:2021"),
        "time-not-synced":     ("A.12.4.4", "PR.PT-1", "A09:2021"),
        "empty-passwords":     ("A.9.2.4", "PR.AC-1", "A07:2021"),
        "sudo-nopasswd":       ("A.9.2.3", "PR.AC-4", "A05:2021"),
        "shadow-perms":        ("A.9.4.1", "PR.AC-1", "A05:2021"),
        // Ampliação (hardening adicional)
        "ssh-permit-empty":    ("A.9.4.2", "PR.AC-7", "A07:2021"),
        "ssh-x11":             ("A.13.1.1", "PR.PT-3", "A05:2021"),
        "ssh-idle-timeout":    ("A.11.2.8", "PR.AC-7", "A07:2021"),
        "mac":                 ("A.9.4.1", "PR.PT-3", "A05:2021"),
        "mac-inactive":        ("A.9.4.1", "PR.PT-3", "A05:2021"),
        "mac-missing":         ("A.9.4.1", "PR.PT-3", "A05:2021"),
        "auditd":              ("A.12.4.1", "DE.CM-1", "A09:2021"),
        "auditd-missing":      ("A.12.4.1", "DE.CM-1", "A09:2021"),
        "kernel-aslr":         ("A.14.2.5", "PR.IP-1", "A05:2021"),
        "uid0-unique":         ("A.9.2.3", "PR.AC-4", "A07:2021"),
        "uid0-multiple":       ("A.9.2.3", "PR.AC-4", "A07:2021"),
        "pass-max-days":       ("A.9.4.3", "PR.AC-1", "A07:2021"),
        "fw-default-deny":     ("A.13.1.1", "PR.AC-5", "A05:2021"),
        "fw-default-allow":    ("A.13.1.1", "PR.AC-5", "A05:2021"),
        "rootkit-tool":        ("A.12.2.1", "DE.CM-4", "A08:2021"),
        "rootkit-tool-missing":("A.12.2.1", "DE.CM-4", "A08:2021"),
        // Ampliação 2 (fs/kernel/logs/senha)
        "ssh-logingrace":      ("A.9.4.2", "PR.AC-7", "A07:2021"),
        "tmp-partition":       ("A.12.1.1", "PR.IP-1", "A05:2021"),
        "kernel-suid-dumpable":("A.14.2.5", "PR.IP-1", "A05:2021"),
        "kernel-syncookies":   ("A.13.1.1", "PR.PT-4", "A05:2021"),
        "logs-persistent":     ("A.12.4.1", "DE.CM-1", "A09:2021"),
        "pass-hash":           ("A.10.1.1", "PR.AC-1", "A02:2021"),
        "umask-strict":        ("A.9.4.1", "PR.AC-4", "A05:2021"),
        "umask-loose":         ("A.9.4.1", "PR.AC-4", "A05:2021"),
        // Ampliação 3
        "ssh-tcp-forward":     ("A.13.1.1", "PR.PT-4", "A05:2021"),
        "kernel-net-hardening":("A.13.1.1", "PR.PT-4", "A05:2021"),
        "kernel-info-leak":    ("A.14.2.5", "PR.IP-1", "A05:2021"),
        "etc-passwd-perms":    ("A.9.2.3", "PR.AC-4", "A05:2021"),
        "pass-complexity":     ("A.9.4.3", "PR.AC-1", "A07:2021"),
        // Ampliação 4
        "var-partition":       ("A.12.1.3", "PR.DS-4", "A05:2021"),
        "home-partition":      ("A.12.1.3", "PR.DS-4", "A05:2021"),
        "pam-lockout":         ("A.9.4.2", "PR.AC-7", "A07:2021"),
        "sensitive-file-perms":("A.9.2.3", "PR.AC-4", "A05:2021"),
        // TLS / criptografia
        "cert-tls":            ("A.10.1.1", "PR.DS-2", "A02:2021"),
        "tls-config":          ("A.14.1.2", "PR.DS-2", "A02:2021"),
    ]

    // Grupos de achados por ÁREA — base para PCI/CISv8/SOC2 (mapeamento por domínio).
    private static let areaAuth = ["ssh-root-login","ssh-password-auth","ssh-permit-empty","ssh-maxauthtries","ssh-idle-timeout","ssh-logingrace","empty-passwords","pass-max-days","pass-hash","pass-complexity","uid0-unique","uid0-multiple","sudo-nopasswd","etc-passwd-perms","pam-lockout","sensitive-file-perms"]
    private static let areaNet = ["firewall","firewall-inactive","fw-default-deny","fw-default-allow","exposed-ports","kernel-syncookies","kernel-net-hardening","ssh-tcp-forward"]
    private static let areaPatch = ["auto-updates","auto-updates-missing","updates","updates-pending","updates-security-pending","os-eol","reboot-required"]
    private static let areaCfg = ["mac","mac-inactive","mac-missing","kernel-aslr","kernel-suid-dumpable","kernel-info-leak","tmp-partition","var-partition","home-partition","umask-strict","umask-loose","shadow-perms","ssh-x11"]
    private static let areaLog = ["auditd","auditd-missing","logs-persistent","time-not-synced","fail2ban","fail2ban-missing"]
    private static let areaMal = ["rootkit-tool","rootkit-tool-missing"]
    private static let areaDisk = ["disk-space","disk-smart","disk-realloc"]

    private static func areaTable(auth: String, net: String, patch: String, cfg: String,
                                  log: String, mal: String, disk: String?) -> [String: String] {
        var m: [String: String] = [:]
        for k in areaAuth { m[k] = auth }; for k in areaNet { m[k] = net }
        for k in areaPatch { m[k] = patch }; for k in areaCfg { m[k] = cfg }
        for k in areaLog { m[k] = log }; for k in areaMal { m[k] = mal }
        if let disk { for k in areaDisk { m[k] = disk } }
        return m
    }

    // PCI-DSS (requisito), CIS Controls v8 (controle) e SOC 2 (critério TSC).
    // + criptografia/TLS (cert-tls, tls-config).
    private static let pciTable   = areaTable(auth: "8",     net: "1",     patch: "6",     cfg: "2",     log: "10",    mal: "5",     disk: nil)
        .merging(["cert-tls": "4", "tls-config": "4"]) { a, _ in a }
    private static let cisv8Table = areaTable(auth: "6",     net: "12",    patch: "7",     cfg: "4",     log: "8",     mal: "10",    disk: "11")
        .merging(["cert-tls": "3", "tls-config": "3"]) { a, _ in a }
    private static let soc2Table  = areaTable(auth: "CC6.1", net: "CC6.6", patch: "CC7.1", cfg: "CC6.8", log: "CC7.2", mal: "CC6.8", disk: "A1.2")
        .merging(["cert-tls": "CC6.7", "tls-config": "CC6.7"]) { a, _ in a }

    // CIS de reserva por chave-base (quando o achado não traz o campo cis).
    private static let cisFallback: [String: String] = [
        "ssh-root-login": "5.2.8", "ssh-password-auth": "5.2.10", "ssh-maxauthtries": "5.2.7",
        "firewall": "3.5.1", "firewall-inactive": "3.5.1",
        "empty-passwords": "5.4.2", "sudo-nopasswd": "5.3.4", "shadow-perms": "6.1.9",
    ]

    /// Referências de frameworks para um achado.
    public static func refs(for finding: AuditFinding) -> FrameworkRefs {
        let key = baseKey(finding.id)
        let row = table[key]
        return FrameworkRefs(
            cis: finding.cis ?? cisFallback[key],
            iso27001: row?.iso,
            nist: row?.nist,
            owasp: row?.owasp,
            pci: pciTable[key],
            cisv8: cisv8Table[key],
            soc2: soc2Table[key])
    }

    public static func hasAnyRef(_ f: AuditFinding) -> Bool {
        let r = refs(for: f)
        return r.cis != nil || r.iso27001 != nil || r.nist != nil || r.owasp != nil || r.pci != nil
    }

    /// Aderência por framework: dos controles verificados (achados mapeados), quantos
    /// estão atendidos (severidade "ok"). É parcial — só o que a auditoria checa.
    public static func coverage(_ audit: ExternalAudit) -> [FrameworkCoverage] {
        var met: [ComplianceFramework: Int] = [:]
        var total: [ComplianceFramework: Int] = [:]
        for f in audit.findings {
            let r = refs(for: f)
            let refByFw: [ComplianceFramework: String?] = [
                .cis: r.cis, .iso: r.iso27001, .nist: r.nist, .owasp: r.owasp, .pci: r.pci,
                .cisv8: r.cisv8, .soc2: r.soc2,
            ]
            for (fw, ref) in refByFw where ref != nil {
                total[fw, default: 0] += 1
                if f.severity == .ok { met[fw, default: 0] += 1 }
            }
        }
        return ComplianceFramework.allCases.compactMap { fw in
            let t = total[fw] ?? 0
            guard t > 0 else { return nil }
            return FrameworkCoverage(framework: fw, met: met[fw] ?? 0, checked: t)
        }
    }

    public struct NistFunctionCoverage: Identifiable, Equatable, Sendable {
        public let function: String     // Identificar/Proteger/Detectar/…
        public let met: Int
        public let checked: Int
        public var id: String { function }
        public var percent: Int { checked == 0 ? 0 : Int(Double(met) / Double(checked) * 100) }
    }

    /// Cobertura por FUNÇÃO do NIST CSF (Identificar/Proteger/Detectar/Responder/Recuperar).
    public static func nistFunctionCoverage(_ audit: ExternalAudit) -> [NistFunctionCoverage] {
        let order = ["Identificar", "Proteger", "Detectar", "Responder", "Recuperar"]
        var met: [String: Int] = [:], total: [String: Int] = [:]
        for f in audit.findings {
            guard let ref = refs(for: f).nist else { continue }
            let fn = nistFunction(ref)
            total[fn, default: 0] += 1
            if f.severity == .ok { met[fn, default: 0] += 1 }
        }
        return order.compactMap { fn in
            let t = total[fn] ?? 0
            return t > 0 ? NistFunctionCoverage(function: fn, met: met[fn] ?? 0, checked: t) : nil
        }
    }
}
