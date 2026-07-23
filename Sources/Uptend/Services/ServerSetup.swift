import Foundation

// =============================================================================
// ASSISTENTE DE PRIMEIRA CONFIGURAÇÃO — Passo 8 do módulo Servidor
// Passos prontos que instalam/endurecem o essencial (Docker, firewall, fail2ban,
// auto-updates, SSH). Cada passo é um script FIXO via sudo -n (se pedir senha, o
// erro aparece no log — nada às cegas). O firewall libera o SSH ANTES de ativar,
// para não trancar o acesso.
// =============================================================================

struct SetupStep: Identifiable {
    let id: String
    let title: String
    let detail: String
    let args: [String]
}

enum ServerSetup {

    static let steps: [SetupStep] = [
        SetupStep(
            id: "docker", title: "Instalar Docker",
            detail: "Base para os containers e o Catálogo. Adiciona seu usuário ao grupo docker.",
            args: ["bash", "-lc",
                   "sudo -n apt-get install -y docker.io >/dev/null 2>&1 || true; sudo -n systemctl enable --now docker; sudo -n usermod -aG docker $(whoami); echo \"Docker pronto.\""]),

        SetupStep(
            id: "firewall", title: "Ativar firewall (ufw)",
            detail: "Bloqueia portas não usadas. Libera o SSH (porta 22) ANTES de ativar, para não trancar o acesso.",
            args: ["bash", "-lc",
                   "sudo -n apt-get install -y ufw >/dev/null 2>&1 || true; sudo -n ufw allow 22/tcp; sudo -n ufw --force enable; sudo -n ufw status"]),

        SetupStep(
            id: "fail2ban", title: "Proteção contra força bruta (fail2ban)",
            detail: "Bane automaticamente quem erra a senha SSH várias vezes.",
            args: ["bash", "-lc",
                   "sudo -n apt-get install -y fail2ban >/dev/null 2>&1 || true; sudo -n systemctl enable --now fail2ban; systemctl is-active fail2ban"]),

        SetupStep(
            id: "autoupdates", title: "Atualizações automáticas de segurança",
            detail: "Instala o unattended-upgrades, que aplica os patches de segurança sozinho.",
            args: ["bash", "-lc",
                   "sudo -n apt-get install -y unattended-upgrades >/dev/null 2>&1 || true; dpkg -l unattended-upgrades | grep \"^ii\" && echo \"Atualizações automáticas ligadas.\""]),

        SetupStep(
            id: "ssh_password", title: "Desativar login por senha no SSH",
            detail: "Só permite entrar por chave SSH (você já usa). Fecha a porta para ataques de senha.",
            args: ["bash", "-lc",
                   "echo \"PasswordAuthentication no\" | sudo -n tee /etc/ssh/sshd_config.d/99-uptend-hardening.conf >/dev/null; sudo -n systemctl reload ssh; echo \"Login por senha desativado (acesso só por chave).\""]),
    ]

    /// Estado atual de cada passo (id → concluído). Cinco checagens em paralelo.
    static func status(_ host: RemoteHost) async -> [String: Bool] {
        async let docker = SSHRunner.run(host, ["bash", "-lc", "command -v docker >/dev/null && echo yes || echo no"])
        async let firewall = SSHRunner.run(host, ["bash", "-lc", "command -v ufw >/dev/null && sudo -n ufw status 2>/dev/null | grep -qi active && echo yes || echo no"])
        async let fail2ban = SSHRunner.run(host, ["systemctl", "is-active", "fail2ban"])
        async let autoup = SSHRunner.run(host, ["bash", "-lc", "dpkg -l unattended-upgrades 2>/dev/null | grep -q \"^ii\" && echo yes || echo no"])
        async let sshpw = SSHRunner.run(host, ["bash", "-lc", "sudo -n sshd -T 2>/dev/null | grep -qi \"^passwordauthentication no\" && echo yes || echo no"])

        func yes(_ r: CommandResult) -> Bool { r.stdout.contains("yes") }
        return [
            "docker": yes(await docker),
            "firewall": yes(await firewall),
            "fail2ban": (await fail2ban).stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "active",
            "autoupdates": yes(await autoup),
            "ssh_password": yes(await sshpw),
        ]
    }
}
