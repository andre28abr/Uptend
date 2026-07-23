import Foundation

// =============================================================================
// BASELINE COMO CÓDIGO (policy-as-code) — FASE B4
// Define o PADRÃO esperado (quais controles são obrigatórios) num arquivo
// versionável (JSON) e mede o DESVIO de cada auditoria contra ele. Ideal para
// consultoria sob demanda: o auditor carrega o mesmo baseline em qualquer cliente
// e gera "conformidade ao baseline" na hora. Lógica pura → testável.
// =============================================================================

public struct BaselineItem: Codable, Equatable, Sendable, Identifiable {
    public let key: String        // chave-base do controle (ex.: "firewall", "ssh-root-login")
    public let title: String      // rótulo legível
    public let mandatory: Bool     // obrigatório para conformidade
    public let note: String        // por que importa / valor esperado
    public var id: String { key }

    public init(key: String, title: String, mandatory: Bool = true, note: String = "") {
        self.key = key; self.title = title; self.mandatory = mandatory; self.note = note
    }
}

public struct Baseline: Codable, Equatable, Sendable {
    public var name: String
    public var version: String
    public var createdAt: String   // "yyyy-MM-dd"
    public var items: [BaselineItem]

    public init(name: String, version: String = "1.0", createdAt: String, items: [BaselineItem]) {
        self.name = name; self.version = version; self.createdAt = createdAt; self.items = items
    }

    public var mandatoryCount: Int { items.filter(\.mandatory).count }
}

public enum BaselineStatus: String, Sendable, CaseIterable {
    case conforme = "Conforme"
    case desvio = "Desvio"
    case naoAvaliado = "Não avaliado"

    public var colorHex: String {
        switch self { case .conforme: "#30a46c"; case .desvio: "#e5484d"; case .naoAvaliado: "#8a8a8f" }
    }
}

public struct BaselineResult: Identifiable, Sendable, Equatable {
    public let item: BaselineItem
    public let status: BaselineStatus
    public let findingId: String?      // achado que sustenta o status (quando houver)
    public let severity: AuditSeverity?
    public var id: String { item.key }
}

public struct BaselineSummary: Sendable, Equatable {
    public let total: Int
    public let conforme: Int
    public let desvio: Int
    public let naoAvaliado: Int
    public let mandatoryDesvio: Int    // desvios em itens obrigatórios (o que reprova)
    /// % de conformidade sobre o que foi avaliado (conforme / (conforme+desvio)).
    public let percent: Int
    /// Passou no baseline? (nenhum desvio obrigatório).
    public var passed: Bool { mandatoryDesvio == 0 }
}

// =============================================================================
// PERFIS RECOMENDADOS — baselines curados prontos, calibrados por RISCO/CONTEXTO
// (não por "nota"). Mesmo catálogo de controles nos três; muda só o que é
// obrigatório. Rigoroso ⊇ Padrão ⊇ Básico nos itens obrigatórios.
//   • Básico    — máquina interna / dev / laboratório (só o essencial obrigatório)
//   • Padrão    — servidor corporativo comum (essencial + hardening principal)
//   • Rigoroso  — exposto à internet / dados sensíveis / PCI-LGPD (quase tudo)
// =============================================================================

public enum BaselineProfile: String, Sendable, CaseIterable {
    case basico, padrao, rigoroso

    public var displayName: String {
        switch self { case .basico: "Básico"; case .padrao: "Padrão"; case .rigoroso: "Rigoroso" }
    }
    public var subtitle: String {
        switch self {
        case .basico: "Interno / dev / laboratório — só o essencial obrigatório"
        case .padrao: "Servidor corporativo comum — essencial + hardening principal"
        case .rigoroso: "Exposto à internet / dados sensíveis — quase tudo obrigatório"
        }
    }
    fileprivate var level: Int { switch self { case .basico: 1; case .padrao: 2; case .rigoroso: 3 } }
}

public enum BaselineEngine {

    /// Um controle no catálogo curado: identidade canônica, título como exigência,
    /// nota e o perfil MÍNIMO em que ele passa a ser obrigatório.
    struct Curated { let key: String; let title: String; let note: String; let minTier: BaselineProfile }

    /// Catálogo curado (controles com confirmação positiva de conformidade no coletor).
    static let curatedControls: [Curated] = [
        // Essenciais — obrigatórios em todos os perfis
        Curated(key: "firewall", title: "Firewall ativo", note: "Firewall (ufw/nftables) ligado com regras.", minTier: .basico),
        Curated(key: "ssh-root-login", title: "SSH sem login direto de root", note: "PermitRootLogin no/prohibit-password.", minTier: .basico),
        Curated(key: "ssh-permit-empty", title: "SSH sem senha vazia", note: "PermitEmptyPasswords no.", minTier: .basico),
        Curated(key: "pass-hash", title: "Senhas com hash forte", note: "SHA-512/yescrypt, não MD5/DES.", minTier: .basico),
        Curated(key: "uid0-unique", title: "Apenas uma conta root (UID 0)", note: "Nenhuma outra conta com UID 0.", minTier: .basico),
        Curated(key: "updates", title: "Atualizações do sistema em dia", note: "Sem pacotes de segurança pendentes.", minTier: .basico),
        Curated(key: "os-eol", title: "Sistema operacional com suporte", note: "Versão não descontinuada (EOL).", minTier: .basico),
        Curated(key: "disk-space", title: "Espaço em disco saudável", note: "Sem partição perto de encher.", minTier: .basico),
        // Padrão — corporativo
        Curated(key: "exposed-ports", title: "Portas expostas minimizadas", note: "Só o necessário ouvindo em rede.", minTier: .padrao),
        Curated(key: "ssh-password-auth", title: "SSH só com chave (sem senha)", note: "PasswordAuthentication no.", minTier: .padrao),
        Curated(key: "pass-complexity", title: "Complexidade de senha exigida", note: "Regras de qualidade de senha (pwquality).", minTier: .padrao),
        Curated(key: "pam-lockout", title: "Bloqueio após tentativas falhas", note: "faillock/pam_tally contra brute-force local.", minTier: .padrao),
        Curated(key: "etc-passwd-perms", title: "Permissões corretas em /etc/passwd", note: "Arquivos de conta sem escrita indevida.", minTier: .padrao),
        Curated(key: "sensitive-file-perms", title: "Permissões restritas em arquivos sensíveis", note: "shadow/sudoers/chaves protegidos.", minTier: .padrao),
        Curated(key: "auto-updates", title: "Atualizações automáticas de segurança", note: "unattended-upgrades/dnf-automatic.", minTier: .padrao),
        Curated(key: "logs-persistent", title: "Logs persistentes habilitados", note: "journald grava em disco entre reinícios.", minTier: .padrao),
        Curated(key: "fail2ban", title: "Proteção contra brute-force (fail2ban)", note: "Banimento por tentativas repetidas.", minTier: .padrao),
        Curated(key: "mac", title: "Controle de acesso mandatório ativo", note: "SELinux/AppArmor em enforcing.", minTier: .padrao),
        Curated(key: "kernel-aslr", title: "ASLR do kernel ativo", note: "randomize_va_space = 2.", minTier: .padrao),
        Curated(key: "kernel-syncookies", title: "SYN cookies ativos", note: "Proteção contra SYN flood.", minTier: .padrao),
        Curated(key: "tls-config", title: "Configuração TLS forte", note: "Se houver servidor web: protocolos/cifras seguros.", minTier: .padrao),
        // Rigoroso — exposto / regulado
        Curated(key: "fw-default", title: "Firewall com política padrão \"negar\"", note: "Default deny de entrada.", minTier: .rigoroso),
        Curated(key: "ssh-idle-timeout", title: "SSH com timeout de sessão ociosa", note: "ClientAliveInterval configurado.", minTier: .rigoroso),
        Curated(key: "ssh-tcp-forward", title: "SSH sem encaminhamento TCP", note: "AllowTcpForwarding no (quando não usado).", minTier: .rigoroso),
        Curated(key: "pass-max-days", title: "Expiração de senha configurada", note: "PASS_MAX_DAYS dentro da política.", minTier: .rigoroso),
        Curated(key: "umask", title: "umask restritivo", note: "027/077 para novos arquivos.", minTier: .rigoroso),
        Curated(key: "auditd", title: "Auditoria do sistema (auditd) ativa", note: "Trilha de auditoria do kernel.", minTier: .rigoroso),
        Curated(key: "rootkit-tool", title: "Detecção de rootkit instalada", note: "rkhunter/chkrootkit presente.", minTier: .rigoroso),
        Curated(key: "kernel-suid-dumpable", title: "suid_dumpable desativado", note: "fs.suid_dumpable = 0.", minTier: .rigoroso),
        Curated(key: "kernel-info-leak", title: "Proteções contra vazamento do kernel", note: "kptr_restrict/dmesg_restrict.", minTier: .rigoroso),
        Curated(key: "kernel-net-hardening", title: "Hardening de rede do kernel", note: "rp_filter, no redirects, etc.", minTier: .rigoroso),
        Curated(key: "tmp-partition", title: "/tmp em partição separada", note: "Isolamento de /tmp (nodev/nosuid).", minTier: .rigoroso),
    ]

    /// Gera um baseline recomendado pronto para o perfil escolhido.
    public static func builtin(_ profile: BaselineProfile, today: String) -> Baseline {
        let items = curatedControls.map { c in
            BaselineItem(key: c.key, title: c.title,
                         mandatory: c.minTier.level <= profile.level, note: c.note)
        }
        return Baseline(name: "Recomendado — \(profile.displayName)", version: "1.0",
                        createdAt: today, items: items)
    }


    /// Pior severidade por chave-base, com o id do achado representativo.
    static func worstByBaseKey(_ audit: ExternalAudit) -> [String: (sev: AuditSeverity, id: String)] {
        var map: [String: (AuditSeverity, String)] = [:]
        for f in audit.findings {
            let k = ComplianceMap.controlKey(f.id)
            if let cur = map[k] {
                if f.severity > cur.0 { map[k] = (f.severity, f.id) }
            } else {
                map[k] = (f.severity, f.id)
            }
        }
        return map
    }

    /// Avalia a auditoria contra o baseline (um resultado por item, na ordem do baseline).
    public static func assess(_ audit: ExternalAudit, against baseline: Baseline) -> [BaselineResult] {
        let byKey = worstByBaseKey(audit)
        return baseline.items.map { item in
            if let hit = byKey[item.key] {
                let status: BaselineStatus = hit.sev > .ok ? .desvio : .conforme
                return BaselineResult(item: item, status: status, findingId: hit.id, severity: hit.sev)
            } else {
                return BaselineResult(item: item, status: .naoAvaliado, findingId: nil, severity: nil)
            }
        }
    }

    public static func summary(_ results: [BaselineResult]) -> BaselineSummary {
        let conforme = results.filter { $0.status == .conforme }.count
        let desvio = results.filter { $0.status == .desvio }.count
        let naoAval = results.filter { $0.status == .naoAvaliado }.count
        let mandDesvio = results.filter { $0.status == .desvio && $0.item.mandatory }.count
        let avaliado = conforme + desvio
        return BaselineSummary(
            total: results.count, conforme: conforme, desvio: desvio, naoAvaliado: naoAval,
            mandatoryDesvio: mandDesvio,
            percent: avaliado == 0 ? 0 : Int(Double(conforme) / Double(avaliado) * 100))
    }

    /// Gera um baseline a partir de uma auditoria de referência: captura todos os
    /// controles que o coletor avaliou (por chave-base), todos como obrigatórios.
    public static func generate(from audit: ExternalAudit, name: String, today: String) -> Baseline {
        var seen = Set<String>()
        var items: [BaselineItem] = []
        for f in audit.findings.sorted(by: { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }) {
            let k = ComplianceMap.controlKey(f.id)
            guard !seen.contains(k) else { continue }
            seen.insert(k)
            items.append(BaselineItem(key: k, title: f.title, mandatory: true, note: ""))
        }
        return Baseline(name: name, version: "1.0", createdAt: today, items: items)
    }

    // MARK: Export CSV

    public static func csv(_ results: [BaselineResult]) -> String {
        var out = "controle,titulo,obrigatorio,status,achado,severidade\n"
        for r in results {
            out += [r.item.key, r.item.title, r.item.mandatory ? "sim" : "não",
                    r.status.rawValue, r.findingId ?? "", r.severity?.label ?? ""]
                .map(csvEscape).joined(separator: ",") + "\n"
        }
        return out
    }

    private static func csvEscape(_ v: String) -> String {
        if v.contains(",") || v.contains("\"") || v.contains("\n") {
            return "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return v
    }
}
