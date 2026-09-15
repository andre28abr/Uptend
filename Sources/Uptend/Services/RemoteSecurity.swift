import Foundation
import UptendCore

// =============================================================================
// SEGURANÇA DO SERVIDOR — Passo 4 do módulo Servidor
// Status (firewall, SSH, fail2ban, auto-updates, updates de segurança) e a
// auditoria Lynis (reaproveita o parser do Mac: AuditService.parseReport).
// Leitura; comandos privilegiados via sudo -n. Scripts fixos (sem entrada do usuário).
// =============================================================================

struct ServerSecurityCheck: Identifiable, Hashable {
    let title: String
    let detail: String
    let level: Int          // 0 ok · 1 atenção · 2 problema
    var id: String { title }
}

enum RemoteSecurity {

    /// Roda todas as verificações em paralelo e devolve os cartões de status.
    static func status(_ host: RemoteHost) async -> [ServerSecurityCheck] {
        async let ufw = SSHRunner.run(host, ["bash", "-lc",
            "command -v ufw >/dev/null && sudo -n ufw status 2>/dev/null | head -1 || echo NOTINSTALLED"])
        async let ssh = SSHRunner.run(host, ["bash", "-lc",
            "sudo -n sshd -T 2>/dev/null | grep -E \"^permitrootlogin|^passwordauthentication\" || echo UNKNOWN"])
        async let f2b = SSHRunner.run(host, ["systemctl", "is-active", "fail2ban"])
        async let unat = SSHRunner.run(host, ["bash", "-lc",
            "dpkg -l unattended-upgrades 2>/dev/null | grep -q \"^ii\" && echo yes || echo no"])
        async let sec = SSHRunner.run(host, ["bash", "-lc",
            "apt list --upgradable 2>/dev/null | grep -c security"])

        var checks: [ServerSecurityCheck] = []
        checks.append(firewallCheck((await ufw).stdout))
        checks.append(contentsOf: sshChecks((await ssh).stdout))
        checks.append(fail2banCheck((await f2b).stdout))
        checks.append(unattendedCheck((await unat).stdout))
        checks.append(securityUpdatesCheck((await sec).stdout))
        return checks
    }

    // MARK: Parsers puros

    static func firewallCheck(_ out: String) -> ServerSecurityCheck {
        let o = out.lowercased()
        if o.contains("notinstalled") {
            return ServerSecurityCheck(title: "Firewall (ufw)", detail: "Não instalado — sua máquina está sem firewall.", level: 1)
        }
        if o.contains("status: active") || o.contains("status:active") {
            return ServerSecurityCheck(title: "Firewall (ufw)", detail: "Ativo.", level: 0)
        }
        return ServerSecurityCheck(title: "Firewall (ufw)", detail: "Instalado, mas inativo.", level: 1)
    }

    static func sshChecks(_ out: String) -> [ServerSecurityCheck] {
        var root = "desconhecido"
        var password = "desconhecido"
        for raw in out.split(whereSeparator: \.isNewline) {
            let parts = raw.split(separator: " ", omittingEmptySubsequences: true).map { String($0).lowercased() }
            guard parts.count >= 2 else { continue }
            if parts[0] == "permitrootlogin" { root = parts[1] }
            else if parts[0] == "passwordauthentication" { password = parts[1] }
        }
        var checks: [ServerSecurityCheck] = []
        switch root {
        case "no": checks.append(ServerSecurityCheck(title: "Login root por SSH", detail: "Bloqueado.", level: 0))
        case "yes": checks.append(ServerSecurityCheck(title: "Login root por SSH", detail: "Permitido — risco. Bloqueie o login direto como root.", level: 2))
        case "desconhecido": checks.append(ServerSecurityCheck(title: "Login root por SSH", detail: "Não foi possível verificar.", level: 1))
        default: checks.append(ServerSecurityCheck(title: "Login root por SSH", detail: "Só por chave (\(root)).", level: 0))
        }
        switch password {
        case "no": checks.append(ServerSecurityCheck(title: "Login por senha (SSH)", detail: "Desativado — só por chave. Ótimo.", level: 0))
        case "yes": checks.append(ServerSecurityCheck(title: "Login por senha (SSH)", detail: "Ativado — prefira apenas chave SSH.", level: 1))
        default: checks.append(ServerSecurityCheck(title: "Login por senha (SSH)", detail: "Não foi possível verificar.", level: 1))
        }
        return checks
    }

    static func fail2banCheck(_ out: String) -> ServerSecurityCheck {
        out.trimmingCharacters(in: .whitespacesAndNewlines) == "active"
            ? ServerSecurityCheck(title: "fail2ban", detail: "Ativo — protege contra ataques de força bruta.", level: 0)
            : ServerSecurityCheck(title: "fail2ban", detail: "Não instalado ou inativo.", level: 1)
    }

    static func unattendedCheck(_ out: String) -> ServerSecurityCheck {
        out.trimmingCharacters(in: .whitespacesAndNewlines) == "yes"
            ? ServerSecurityCheck(title: "Atualizações automáticas", detail: "Ligadas (unattended-upgrades).", level: 0)
            : ServerSecurityCheck(title: "Atualizações automáticas", detail: "Desligadas — patches de segurança não se aplicam sozinhos.", level: 1)
    }

    static func securityUpdatesCheck(_ out: String) -> ServerSecurityCheck {
        let n = Int(out.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        return n == 0
            ? ServerSecurityCheck(title: "Updates de segurança", detail: "Nenhum pendente.", level: 0)
            : ServerSecurityCheck(title: "Updates de segurança", detail: "\(n) pendente(s) — atualize na aba Atualizações.", level: 2)
    }

    // MARK: Auditoria Lynis

    /// Instala o Lynis (se preciso) e roda a auditoria. O relatório fica nos
    /// caminhos padrão do Lynis em /var/log (gravável só por root) — em /tmp,
    /// outro usuário local do servidor poderia plantar um symlink no caminho
    /// previsível e fazer o root sobrescrever um arquivo arbitrário.
    static let auditArgs = ["bash", "-lc",
        "(command -v lynis >/dev/null || sudo -n apt-get install -y lynis >/dev/null 2>&1); " +
        "sudo -n lynis audit system --quick --no-colors --report-file /var/log/uptend-lynis-report.dat --logfile /var/log/uptend-lynis.log"]

    /// Lê o relatório gravado (o Lynis grava como root → `sudo -n cat`) e reaproveita
    /// o parser do Mac.
    static func readAudit(_ host: RemoteHost) async -> (index: Int?, warnings: [LynisFinding], suggestions: [LynisFinding]) {
        let r = await SSHRunner.run(host, ["sudo", "-n", "cat", "/var/log/uptend-lynis-report.dat"])
        return AuditService.parseReport(r.stdout)
    }
}
