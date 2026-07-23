import Foundation

// =============================================================================
// AUDITORIA EXTERNA — MITRE ATT&CK (assinatura do relatório SOC)
// Relaciona os achados a técnicas do MITRE ATT&CK (o que um atacante exploraria).
// Times de SOC usam isso para priorizar detecção e resposta. Lógica pura.
// =============================================================================

public struct MitreTechnique: Equatable, Sendable {
    public let id: String        // ex.: "T1078"
    public let name: String      // ex.: "Valid Accounts"
    public let tactic: String    // ex.: "Acesso Inicial"
}

public enum MitreMap {

    private static let table: [String: MitreTechnique] = [
        "ssh-root-login":    .init(id: "T1078", name: "Valid Accounts", tactic: "Acesso Inicial"),
        "ssh-password-auth": .init(id: "T1110", name: "Brute Force", tactic: "Acesso a Credenciais"),
        "ssh-maxauthtries":  .init(id: "T1110", name: "Brute Force", tactic: "Acesso a Credenciais"),
        "ssh-permit-empty":  .init(id: "T1078", name: "Valid Accounts", tactic: "Acesso Inicial"),
        "empty-passwords":   .init(id: "T1078", name: "Valid Accounts", tactic: "Acesso Inicial"),
        "uid0-multiple":     .init(id: "T1078.003", name: "Valid Accounts: Local Accounts", tactic: "Persistência"),
        "fail2ban-missing":  .init(id: "T1110", name: "Brute Force", tactic: "Acesso a Credenciais"),
        "exposed-ports":     .init(id: "T1046", name: "Network Service Discovery", tactic: "Descoberta"),
        "firewall-inactive": .init(id: "T1133", name: "External Remote Services", tactic: "Acesso Inicial"),
        "fw-default-allow":  .init(id: "T1133", name: "External Remote Services", tactic: "Acesso Inicial"),
        "auditd-missing":    .init(id: "T1562.006", name: "Impair Defenses: Indicator Blocking", tactic: "Evasão de Defesa"),
        "mac-inactive":      .init(id: "T1562.001", name: "Impair Defenses: Disable/Modify Tools", tactic: "Evasão de Defesa"),
        "mac-missing":       .init(id: "T1562.001", name: "Impair Defenses: Disable/Modify Tools", tactic: "Evasão de Defesa"),
        "updates-security-pending": .init(id: "T1190", name: "Exploit Public-Facing Application", tactic: "Acesso Inicial"),
        "updates-pending":   .init(id: "T1190", name: "Exploit Public-Facing Application", tactic: "Acesso Inicial"),
        "os-eol":            .init(id: "T1190", name: "Exploit Public-Facing Application", tactic: "Acesso Inicial"),
        "reboot-required":   .init(id: "T1211", name: "Exploitation for Defense Evasion", tactic: "Evasão de Defesa"),
        "sudo-nopasswd":     .init(id: "T1548.003", name: "Sudo and Sudo Caching", tactic: "Escalonamento de Privilégio"),
        "shadow-perms":      .init(id: "T1003.008", name: "OS Credential Dumping: /etc/passwd & /etc/shadow", tactic: "Acesso a Credenciais"),
        "kernel-aslr":       .init(id: "T1068", name: "Exploitation for Privilege Escalation", tactic: "Escalonamento de Privilégio"),
        "rootkit-tool-missing": .init(id: "T1014", name: "Rootkit", tactic: "Evasão de Defesa"),
        "time-not-synced":   .init(id: "T1070.006", name: "Indicator Removal: Timestomp", tactic: "Evasão de Defesa"),
        "ssh-idle-timeout":  .init(id: "T1563.001", name: "Remote Service Session Hijacking: SSH", tactic: "Movimento Lateral"),
        "ssh-logingrace":    .init(id: "T1499", name: "Endpoint Denial of Service", tactic: "Impacto"),
        "kernel-syncookies": .init(id: "T1499.001", name: "OS Exhaustion Flood", tactic: "Impacto"),
        "logs-persistent":   .init(id: "T1070", name: "Indicator Removal", tactic: "Evasão de Defesa"),
        "kernel-suid-dumpable": .init(id: "T1068", name: "Exploitation for Privilege Escalation", tactic: "Escalonamento de Privilégio"),
        "pass-hash":         .init(id: "T1110.002", name: "Password Cracking", tactic: "Acesso a Credenciais"),
        "ssh-tcp-forward":   .init(id: "T1572", name: "Protocol Tunneling", tactic: "Comando e Controle"),
        "kernel-net-hardening": .init(id: "T1557", name: "Adversary-in-the-Middle", tactic: "Acesso a Credenciais"),
        "kernel-info-leak":  .init(id: "T1082", name: "System Information Discovery", tactic: "Descoberta"),
        "etc-passwd-perms":  .init(id: "T1098", name: "Account Manipulation", tactic: "Persistência"),
        "pass-complexity":   .init(id: "T1110.002", name: "Password Cracking", tactic: "Acesso a Credenciais"),
        "sensitive-file-perms": .init(id: "T1222", name: "File and Directory Permissions Modification", tactic: "Evasão de Defesa"),
        "pam-lockout":       .init(id: "T1110", name: "Brute Force", tactic: "Acesso a Credenciais"),
        "tls-config":        .init(id: "T1557", name: "Adversary-in-the-Middle", tactic: "Acesso a Credenciais"),
    ]

    public static func technique(for finding: AuditFinding) -> MitreTechnique? {
        table[ComplianceMap.baseKey(finding.id)]
    }

    public static func hasTechnique(_ f: AuditFinding) -> Bool { technique(for: f) != nil }
}
