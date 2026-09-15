import Foundation

// =============================================================================
// AUDITORIA EXTERNA — remediação (comandos de correção) + esforço
// Para cada achado, o comando exato de correção (relatório TÉCNICO) e o esforço
// (ganho rápido × projeto), usado no relatório EXECUTIVO para separar
// "corrija hoje" de "planeje". Lógica pura.
// =============================================================================

public enum RemediationEffort: String, Sendable { case quick, project }

public struct Remediation: Equatable, Sendable {
    public let command: String?
    public let effort: RemediationEffort
}

/// Família de distribuição — decide o pacote/firewall/MAC certo (apt×dnf).
public enum OSFamily: String, Sendable {
    case apt, dnf, unknown

    public static func from(_ distro: String?) -> OSFamily {
        let d = (distro ?? "").lowercased()
        if d.contains("ubuntu") || d.contains("debian") || d.contains("mint") || d.contains("devuan") || d.contains("kali") { return .apt }
        if d.contains("fedora") || d.contains("rocky") || d.contains("alma") || d.contains("rhel") || d.contains("centos") || d.contains("oracle") || d.contains("red hat") || d.contains("openeuler") { return .dnf }
        return .unknown
    }
    /// Para escolher o comando: `unknown` cai no apt (mais comum) — o usuário revisa.
    var effective: OSFamily { self == .unknown ? .apt : self }
}

public enum RemediationMap {

    // Comandos ESPECÍFICOS de distro (pacote/firewall/MAC/auto-update). baseKey → (apt, dnf).
    private static let familyTable: [String: (apt: String, dnf: String)] = [
        "firewall-inactive": (
            "sudo ufw allow OpenSSH && sudo ufw --force enable",
            "sudo systemctl enable --now firewalld && sudo firewall-cmd --permanent --add-service=ssh && sudo firewall-cmd --reload"),
        "fw-default-allow": (
            "sudo ufw default deny incoming && sudo ufw reload",
            "sudo firewall-cmd --set-default-zone=drop && sudo firewall-cmd --permanent --zone=drop --add-service=ssh && sudo firewall-cmd --reload"),
        "fail2ban-missing": (
            "sudo apt-get install -y fail2ban && sudo systemctl enable --now fail2ban",
            "sudo dnf install -y fail2ban && sudo systemctl enable --now fail2ban"),
        "auto-updates-missing": (
            "sudo apt-get install -y unattended-upgrades && sudo dpkg-reconfigure -plow unattended-upgrades",
            "sudo dnf install -y dnf-automatic && sudo systemctl enable --now dnf-automatic.timer"),
        "updates-security-pending": (
            "sudo apt-get update && sudo apt-get upgrade -y",
            "sudo dnf upgrade -y --security"),
        "updates-pending": (
            "sudo apt-get update && sudo apt-get upgrade -y",
            "sudo dnf upgrade -y"),
        "auditd-missing": (
            "sudo apt-get install -y auditd && sudo systemctl enable --now auditd",
            "sudo dnf install -y audit && sudo systemctl enable --now auditd"),
        "rootkit-tool-missing": (
            "sudo apt-get install -y rkhunter && sudo rkhunter --update",
            "sudo dnf install -y rkhunter && sudo rkhunter --update"),
        "mac-inactive": (
            "sudo systemctl enable --now apparmor",
            "sudo setenforce 1 && sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config"),
        "pass-complexity": (
            "sudo apt-get install -y libpam-pwquality && echo 'minlen = 14' | sudo tee -a /etc/security/pwquality.conf",
            "sudo dnf install -y libpwquality && echo 'minlen = 14' | sudo tee -a /etc/security/pwquality.conf"),
    ]

    // baseKey → (comando, esforço). Comandos são exemplos seguros (o usuário revisa).
    private static let table: [String: (String?, RemediationEffort)] = [
        "ssh-root-login":       ("sudo sed -i 's/^#\\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config && sudo systemctl reload ssh", .quick),
        "ssh-password-auth":    ("sudo sed -i 's/^#\\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config && sudo systemctl reload ssh", .quick),
        "ssh-maxauthtries":     ("echo 'MaxAuthTries 4' | sudo tee /etc/ssh/sshd_config.d/60-uptend-authtries.conf && sudo systemctl reload ssh", .quick),
        "ssh-permit-empty":     ("sudo sed -i 's/^#\\?PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config && sudo systemctl reload ssh", .quick),
        "ssh-x11":              ("sudo sed -i 's/^#\\?X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config && sudo systemctl reload ssh", .quick),
        "ssh-idle-timeout":     ("printf 'ClientAliveInterval 300\\nClientAliveCountMax 3\\n' | sudo tee /etc/ssh/sshd_config.d/60-uptend-idle.conf && sudo systemctl reload ssh", .quick),
        "firewall-inactive":    ("sudo ufw allow OpenSSH && sudo ufw --force enable", .quick),
        "fw-default-allow":     ("sudo ufw default deny incoming && sudo ufw reload", .quick),
        "fail2ban-missing":     ("sudo apt-get install -y fail2ban && sudo systemctl enable --now fail2ban", .quick),
        "auto-updates-missing": ("sudo apt-get install -y unattended-upgrades && sudo dpkg-reconfigure -plow unattended-upgrades", .quick),
        "updates-security-pending": ("sudo apt-get update && sudo apt-get upgrade -y", .quick),
        "updates-pending":      ("sudo apt-get update && sudo apt-get upgrade -y", .quick),
        "os-eol":               ("Planeje a migração do SO (ex.: sudo do-release-upgrade ou reinstalação em versão suportada).", .project),
        "exposed-ports":        ("Restrinja no firewall as portas que não precisam estar públicas: sudo ufw deny <porta>", .quick),
        "disk-space":           ("Libere espaço (limpe logs/caches) ou aumente o volume do disco.", .quick),
        "disk-smart":           ("Faça backup imediato e substitua o disco com falha SMART.", .project),
        "disk-realloc":         ("Monitore o disco e programe a troca (setores realocados = desgaste).", .project),
        "reboot-required":      ("Agende uma reinicialização em janela de manutenção: sudo reboot", .quick),
        "time-not-synced":      ("sudo timedatectl set-ntp true", .quick),
        "empty-passwords":      ("sudo passwd -l <usuario>   # bloqueia a conta sem senha", .quick),
        "sudo-nopasswd":        ("sudo visudo   # remova as regras NOPASSWD desnecessárias", .quick),
        "shadow-perms":         ("sudo chown root:shadow /etc/shadow && sudo chmod 640 /etc/shadow", .quick),
        "mac-inactive":         ("sudo systemctl enable --now apparmor   # ou, em RHEL/Fedora: sudo setenforce 1", .quick),
        "mac-missing":          ("Habilite AppArmor (Debian/Ubuntu) ou SELinux (RHEL/Fedora).", .quick),
        "auditd-missing":       ("sudo apt-get install -y auditd && sudo systemctl enable --now auditd", .quick),
        "kernel-aslr":          ("echo 'kernel.randomize_va_space=2' | sudo tee /etc/sysctl.d/60-aslr.conf && sudo sysctl --system", .quick),
        "uid0-multiple":        ("Remova o UID 0 das contas extras (mantenha apenas root).", .quick),
        "pass-max-days":        ("sudo sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 365/' /etc/login.defs", .quick),
        "rootkit-tool-missing": ("sudo apt-get install -y rkhunter && sudo rkhunter --update", .quick),
        "ssh-logingrace":       ("echo 'LoginGraceTime 60' | sudo tee /etc/ssh/sshd_config.d/60-uptend-grace.conf && sudo systemctl reload ssh", .quick),
        "tmp-partition":        ("Configure /tmp como montagem separada (ou tmpfs) com noexec,nosuid,nodev.", .project),
        "kernel-suid-dumpable": ("echo 'fs.suid_dumpable=0' | sudo tee /etc/sysctl.d/60-suid.conf && sudo sysctl --system", .quick),
        "kernel-syncookies":    ("echo 'net.ipv4.tcp_syncookies=1' | sudo tee /etc/sysctl.d/60-net.conf && sudo sysctl --system", .quick),
        "logs-persistent":      ("sudo mkdir -p /var/log/journal && sudo systemctl restart systemd-journald", .quick),
        "pass-hash":            ("Defina ENCRYPT_METHOD SHA512 em /etc/login.defs e ajuste o PAM (pam_unix … sha512).", .quick),
        "umask-loose":          ("sudo sed -i 's/^UMASK.*/UMASK 027/' /etc/login.defs", .quick),
        "ssh-tcp-forward":      ("echo 'AllowTcpForwarding no' | sudo tee /etc/ssh/sshd_config.d/60-uptend-fwd.conf && sudo systemctl reload ssh", .quick),
        "kernel-net-hardening": ("printf 'net.ipv4.conf.all.accept_redirects=0\\nnet.ipv4.conf.all.send_redirects=0\\nnet.ipv4.conf.all.rp_filter=1\\n' | sudo tee /etc/sysctl.d/60-net-harden.conf && sudo sysctl --system", .quick),
        "kernel-info-leak":     ("printf 'kernel.kptr_restrict=1\\nkernel.dmesg_restrict=1\\n' | sudo tee /etc/sysctl.d/60-info.conf && sudo sysctl --system", .quick),
        "etc-passwd-perms":     ("sudo chown root:root /etc/passwd /etc/group && sudo chmod 644 /etc/passwd /etc/group", .quick),
        "pass-complexity":      ("sudo apt-get install -y libpam-pwquality && echo 'minlen = 14' | sudo tee -a /etc/security/pwquality.conf", .quick),
        "var-partition":        ("Considere montar /var em partição/volume próprio (planejamento de disco).", .project),
        "home-partition":       ("Considere montar /home em partição/volume próprio (planejamento de disco).", .project),
        "pam-lockout":          ("Configure pam_faillock (deny=5 unlock_time=900) em /etc/security/faillock.conf e no PAM.", .quick),
        "sensitive-file-perms": ("Ajuste as permissões: sudo chmod o-w <arquivo> (remova gravação por 'outros').", .quick),
        "cert-tls":             ("Renove o certificado (ex.: sudo certbot renew) e ative a renovação automática.", .quick),
        "tls-config":           ("Restrinja o serviço a TLS 1.2/1.3 (nginx: ssl_protocols TLSv1.2 TLSv1.3;) e recarregue.", .quick),
    ]

    /// Correção para o achado, ajustada à FAMÍLIA do SO (apt×dnf) quando o comando difere.
    public static func remediation(for finding: AuditFinding, family: OSFamily = .apt) -> Remediation {
        let key = ComplianceMap.baseKey(finding.id)
        if let fam = familyTable[key] {
            return Remediation(command: family.effective == .dnf ? fam.dnf : fam.apt, effort: .quick)
        }
        let (cmd, effort) = table[key] ?? (nil, .quick)
        return Remediation(command: cmd, effort: effort)
    }
}
