import Foundation

// =============================================================================
// CONTEÚDO DE DETECÇÃO (Sigma / Falco) — FASE C2
// Para cada LACUNA encontrada na auditoria, gera uma regra de detecção
// COMPENSATÓRIA pronta para o SOC/SIEM: "não corrigiu o hardening? então pelo
// menos DETECTE o ataque". Mapeadas a MITRE ATT&CK. Lógica pura → testável.
// =============================================================================

public struct DetectionRule: Identifiable, Sendable, Equatable {
    public let key: String        // id estável ("uptend-ssh-bruteforce")
    public let title: String
    public let format: String     // "sigma" | "falco"
    public let mitre: String      // técnica ATT&CK (ex.: "T1110")
    public let reason: String     // por que (qual lacuna compensa)
    public let yaml: String
    public var id: String { key }
}

public enum DetectionRules {

    /// Base-keys de achados ABERTOS na auditoria (para decidir quais regras incluir).
    private static func openKeys(_ audit: ExternalAudit) -> Set<String> {
        Set(audit.findings.filter { $0.severity > .ok }.map { ComplianceMap.controlKey($0.id) })
    }

    public static func rules(for audit: ExternalAudit) -> [DetectionRule] {
        let open = openKeys(audit)
        func any(_ ks: [String]) -> Bool { ks.contains { open.contains($0) } }
        var out: [DetectionRule] = []

        // 1) Força-bruta SSH — compensa fail2ban/senha/root/maxauthtries
        if any(["fail2ban", "ssh-password-auth", "ssh-maxauthtries", "ssh-root-login", "ssh-permit-empty"]) {
            out.append(DetectionRule(key: "uptend-ssh-bruteforce", title: "Força-bruta SSH (múltiplas falhas)",
                format: "sigma", mitre: "T1110", reason: "Sem fail2ban/proteção de senha — detecte a tentativa.",
                yaml: """
                title: Forca-bruta SSH
                id: uptend-ssh-bruteforce
                status: experimental
                description: Multiplas falhas de autenticacao SSH (controle compensatorio — protecao contra forca-bruta ausente)
                logsource:
                  product: linux
                  service: sshd
                detection:
                  selection:
                    message|contains: 'Failed password'
                  timeframe: 5m
                  condition: selection | count() by src_ip > 5
                level: medium
                tags:
                  - attack.credential_access
                  - attack.t1110
                """))
        }
        // 2) Login de root por SSH
        if open.contains("ssh-root-login") {
            out.append(DetectionRule(key: "uptend-ssh-root-login", title: "Login de root por SSH",
                format: "sigma", mitre: "T1078.003", reason: "Root via SSH está permitido — detecte o uso.",
                yaml: """
                title: Login de root por SSH
                id: uptend-ssh-root-login
                status: experimental
                description: Autenticacao SSH bem-sucedida como root
                logsource:
                  product: linux
                  service: sshd
                detection:
                  selection:
                    message|contains: 'Accepted'
                    message|contains: ' root '
                  condition: selection
                level: high
                tags:
                  - attack.persistence
                  - attack.t1078.003
                """))
        }
        // 3) Acesso a arquivos sensíveis (Falco) — compensa auditd/perms
        if any(["auditd", "sensitive-file-perms", "shadow-perms"]) {
            out.append(DetectionRule(key: "uptend-sensitive-file-read", title: "Leitura de /etc/shadow, /etc/sudoers",
                format: "falco", mitre: "T1003.008", reason: "Sem auditoria (auditd) — detecte acesso a credenciais.",
                yaml: """
                - rule: Leitura de arquivo sensivel (shadow/sudoers)
                  desc: Controle compensatorio — auditoria de acesso ausente
                  condition: open_read and fd.name in (/etc/shadow, /etc/gshadow, /etc/sudoers)
                  output: "Arquivo sensivel lido (file=%fd.name user=%user.name proc=%proc.cmdline)"
                  priority: WARNING
                  tags: [attack.credential_access, attack.t1003.008]
                """))
        }
        // 4) Escalonamento via sudo NOPASSWD (Falco)
        if open.contains("sudo-nopasswd") {
            out.append(DetectionRule(key: "uptend-sudo-nopasswd-exec", title: "Execução via sudo sem senha",
                format: "falco", mitre: "T1548.003", reason: "sudo NOPASSWD configurado — detecte uso indevido.",
                yaml: """
                - rule: Execucao com sudo (NOPASSWD)
                  desc: Controle compensatorio — sudo sem senha permite escalonamento silencioso
                  condition: spawned_process and proc.pname=sudo
                  output: "Comando via sudo (user=%user.name cmd=%proc.cmdline parent=%proc.pname)"
                  priority: NOTICE
                  tags: [attack.privilege_escalation, attack.t1548.003]
                """))
        }
        // 5) Nova porta/serviço ouvindo (Sigma) — compensa firewall/exposição
        if any(["firewall", "exposed-ports", "fw-default"]) {
            out.append(DetectionRule(key: "uptend-new-listener", title: "Novo serviço ouvindo em rede",
                format: "sigma", mitre: "T1571", reason: "Firewall fraco/portas expostas — detecte novos listeners.",
                yaml: """
                title: Novo servico ouvindo em rede
                id: uptend-new-listener
                status: experimental
                description: Processo passou a escutar em porta de rede (controle compensatorio — firewall/exposicao)
                logsource:
                  product: linux
                  category: network_connection
                detection:
                  selection:
                    action: listen
                  condition: selection
                level: medium
                tags:
                  - attack.command_and_control
                  - attack.t1571
                """))
        }
        // 6) Ferramenta/binário suspeito (Falco) — compensa rootkit-tool ausente
        if open.contains("rootkit-tool") {
            out.append(DetectionRule(key: "uptend-suspicious-binary", title: "Binário suspeito em /tmp",
                format: "falco", mitre: "T1059", reason: "Sem detector de rootkit — detecte execução em áreas de escrita.",
                yaml: """
                - rule: Execucao a partir de area gravavel
                  desc: Controle compensatorio — sem detector de rootkit/malware
                  condition: spawned_process and (proc.exepath startswith /tmp/ or proc.exepath startswith /dev/shm/)
                  output: "Binario executado em area gravavel (path=%proc.exepath user=%user.name)"
                  priority: WARNING
                  tags: [attack.execution, attack.t1059]
                """))
        }
        return out
    }

    /// Junta as regras num único arquivo (Sigma e Falco separados por cabeçalho).
    public static func bundle(_ rules: [DetectionRule]) -> String {
        var out = "# Regras de deteccao geradas pelo Uptend (controles compensatorios)\n"
        out += "# NAO substituem a correcao — sao para DETECTAR enquanto o gap nao e fechado.\n\n"
        for group in ["sigma", "falco"] {
            let rs = rules.filter { $0.format == group }
            guard !rs.isEmpty else { continue }
            out += "# ========================= \(group.uppercased()) =========================\n"
            for r in rs {
                out += "# [\(r.mitre)] \(r.title) — \(r.reason)\n\(r.yaml)\n\n"
            }
        }
        return out
    }
}
