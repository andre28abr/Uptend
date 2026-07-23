import Foundation

// =============================================================================
// CENTRAL DE SEGURANÇA / MONITORAMENTO (SIEM leve) — item A
// Junta num painel só o que estava espalhado (logins SSH falhos, fail2ban, serviços
// com falha, disco, config de segurança, updates) e transforma em EVENTOS em
// linguagem simples com "como corrigir". Só leitura; comandos privilegiados via sudo -n.
// Reaproveita RemoteSecurity.status() e RemoteDisks.usage().
// =============================================================================

struct SecurityEvent: Identifiable, Hashable {
    let id: String
    let category: String        // "Acesso", "Serviços", "Configuração", "Sistema"
    let title: String
    let detail: String          // evidência / o que aconteceu
    let remediation: String     // como corrigir
    let level: Int              // 0 ok · 1 atenção · 2 crítico
}

enum SecurityMonitor {

    static func scan(_ host: RemoteHost) async -> [SecurityEvent] {
        async let cfgC = RemoteSecurity.status(host)
        async let loginsC = SSHRunner.run(host, ["bash", "-lc",
            "sudo -n journalctl _COMM=sshd --since \"24 hours ago\" --no-pager 2>/dev/null | grep -icE \"failed password|invalid user|authentication failure\""])
        async let f2bC = SSHRunner.run(host, ["sudo", "-n", "fail2ban-client", "status", "sshd"])
        async let failedC = SSHRunner.run(host, ["systemctl", "--failed", "--no-legend", "--plain", "--no-pager"])
        async let diskC = RemoteDisks.usage(host)

        var events: [SecurityEvent] = []

        // Acesso — logins SSH falhos
        let nLogins = Int((await loginsC).stdout.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        events.append(loginEvent(nLogins))

        // Acesso — fail2ban
        let f2b = fail2banEvent((await f2bC).stdout)
        if let f2b { events.append(f2b) }

        // Serviços — unidades com falha
        events.append(contentsOf: failedServiceEvents((await failedC).stdout))

        // Sistema — disco cheio
        for u in await diskC where u.usedFraction > 0.85 {
            events.append(SecurityEvent(id: "disk-\(u.source)", category: "Sistema",
                title: "Disco quase cheio: \(u.mount)",
                detail: "\(Int((u.usedFraction * 100).rounded()))% usado (\(u.usedLabel) de \(u.sizeLabel)).",
                remediation: "Libere espaço ou aumente o disco. Veja em Discos e RAID.",
                level: u.usedFraction > 0.95 ? 2 : 1))
        }

        // Configuração / Sistema — reaproveita as checagens (pula fail2ban só se já tratado como instalado)
        for c in await cfgC {
            if c.title == "fail2ban", f2b != nil { continue }
            events.append(configEvent(c))
        }

        return events.sorted { $0.level > $1.level }
    }

    // MARK: Correções com 1 clique (transparentes + reversíveis quando seguro)

    /// Uma correção proposta para um evento: passos legíveis + comando de aplicar + (opcional)
    /// comando de reverter. `undoArgs == nil` significa "não reversível com segurança".
    struct Fix {
        let steps: [String]
        let applyArgs: [String]
        let undoArgs: [String]?
        var reversible: Bool { undoArgs != nil }
    }

    /// Correção conhecida para um evento (por id). Reaproveita os scripts do Assistente.
    static func fix(for id: String) -> Fix? {
        func setupArgs(_ stepID: String) -> [String] {
            ServerSetup.steps.first { $0.id == stepID }?.args ?? []
        }
        switch id {
        case "cfg-Firewall (ufw)":
            return Fix(steps: ["Instala o ufw (se preciso)",
                               "Libera a porta 22 (SSH) — para NÃO trancar seu acesso",
                               "Ativa o firewall"],
                       applyArgs: setupArgs("firewall"),
                       undoArgs: ["bash", "-lc", "sudo -n ufw disable"])
        case "cfg-Login por senha (SSH)":
            return Fix(steps: ["Cria uma regra que desativa o login por senha",
                               "Recarrega o SSH (você continua entrando por chave)"],
                       applyArgs: setupArgs("ssh_password"),
                       undoArgs: ["bash", "-lc", "sudo -n rm -f /etc/ssh/sshd_config.d/99-uptend-hardening.conf; sudo -n systemctl reload ssh; echo \"Login por senha reativado.\""])
        case "cfg-fail2ban":
            return Fix(steps: ["Instala o fail2ban", "Ativa e inicia o serviço"],
                       applyArgs: setupArgs("fail2ban"), undoArgs: nil)
        case "cfg-Atualizações automáticas":
            return Fix(steps: ["Instala o unattended-upgrades (aplica patches de segurança sozinho)"],
                       applyArgs: setupArgs("autoupdates"), undoArgs: nil)
        case "cfg-Updates de segurança":
            return Fix(steps: ["Baixa e instala os pacotes de segurança pendentes (apt upgrade)",
                               "Não é reversível"],
                       applyArgs: RemoteApt.upgradeArgs, undoArgs: nil)
        default:
            if id.hasPrefix("svc-") {
                let unit = String(id.dropFirst(4))
                guard InputValidator.isValidServiceName(unit) else { return nil }
                return Fix(steps: ["Reinicia o serviço \(unit)"],
                           applyArgs: ["bash", "-lc", "sudo -n systemctl restart \(unit); systemctl is-active \(unit)"],
                           undoArgs: nil)
            }
            return nil   // ex.: disco cheio — precisa de decisão humana
        }
    }

    // MARK: Builders / parsers puros

    static func loginEvent(_ n: Int) -> SecurityEvent {
        if n == 0 {
            return SecurityEvent(id: "logins", category: "Acesso", title: "Sem logins SSH falhos",
                detail: "Nenhuma tentativa de login SSH falha nas últimas 24h.",
                remediation: "", level: 0)
        }
        let critical = n >= 20
        return SecurityEvent(id: "logins", category: "Acesso",
            title: "\(n) tentativa(s) de login SSH falha(s) (24h)",
            detail: critical ? "Volume alto — possível ataque de força bruta." : "Algumas tentativas falharam.",
            remediation: "Ative o fail2ban e desative o login por senha (Configuração). Use só chave SSH.",
            level: critical ? 2 : 1)
    }

    /// Lê `fail2ban-client status sshd`. Retorna nil se não instalado (sem "Currently banned").
    static func fail2banEvent(_ out: String) -> SecurityEvent? {
        guard out.contains("Currently banned") else { return nil }
        let banned = number(after: "Currently banned:", in: out) ?? 0
        let total = number(after: "Total banned:", in: out) ?? 0
        if banned > 0 {
            return SecurityEvent(id: "fail2ban", category: "Acesso",
                title: "fail2ban bloqueando ataques",
                detail: "\(banned) IP(s) banido(s) agora · \(total) no total.",
                remediation: "Nada a fazer — o fail2ban está te protegendo.", level: 1)
        }
        return SecurityEvent(id: "fail2ban", category: "Acesso", title: "fail2ban ativo",
            detail: "Nenhum IP banido no momento.", remediation: "", level: 0)
    }

    static func failedServiceEvents(_ out: String) -> [SecurityEvent] {
        out.split(whereSeparator: \.isNewline).compactMap { raw in
            let unit = raw.split(separator: " ", omittingEmptySubsequences: true).first.map(String.init) ?? ""
            guard unit.hasSuffix(".service") || unit.hasSuffix(".socket") || unit.hasSuffix(".timer") else { return nil }
            return SecurityEvent(id: "svc-\(unit)", category: "Serviços",
                title: "Serviço com falha: \(unit)",
                detail: "A unidade está em estado \"failed\".",
                remediation: "Veja os logs e reinicie em Serviços (pode ser benigno em VM).",
                level: 2)
        }
    }

    static func configEvent(_ c: ServerSecurityCheck) -> SecurityEvent {
        let category = c.title.contains("Updates") ? "Sistema" : "Configuração"
        let remediation: String
        switch c.title {
        case "Firewall (ufw)": remediation = "Ative o firewall em Configuração."
        case "Login por senha (SSH)": remediation = "Desative o login por senha em Configuração (você usa chave)."
        case "Login root por SSH": remediation = "Bloqueie o login direto como root."
        case "Atualizações automáticas": remediation = "Ligue as atualizações automáticas em Configuração."
        case "Updates de segurança": remediation = "Aplique os patches na aba Atualizações."
        default: remediation = ""
        }
        return SecurityEvent(id: "cfg-\(c.title)", category: category, title: c.title,
                             detail: c.detail, remediation: c.level == 0 ? "" : remediation, level: c.level)
    }

    /// Extrai o número que aparece depois de um rótulo (ex.: "Currently banned:\t3" → 3).
    static func number(after label: String, in text: String) -> Int? {
        for raw in text.split(whereSeparator: \.isNewline) where raw.contains(label) {
            let tail = raw[(raw.range(of: label)!.upperBound)...]
            let digits = tail.drop { !$0.isNumber }.prefix { $0.isNumber }
            return Int(digits)
        }
        return nil
    }
}
