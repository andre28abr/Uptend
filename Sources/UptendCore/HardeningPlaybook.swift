import Foundation

// =============================================================================
// PLAYBOOK DE HARDENING (bash com backup/rollback) — FASE D2
// Gera um SCRIPT REVISÁVEL a partir dos achados abertos (via RemediationMap):
// faz backup dos arquivos de config antes, aplica as correções automatizáveis,
// e traz um modo `rollback` para desfazer. NUNCA é executado pelo app — é só
// gerado para o auditor/cliente revisar e rodar. Lógica pura → testável.
// =============================================================================

public enum HardeningPlaybook {

    /// Um comando é AUTO-aplicável se é um comando de shell direto, sem placeholder
    /// (`<...>`) e sem passo interativo (visudo). Os demais viram nota MANUAL.
    static func isAuto(_ cmd: String) -> Bool {
        let c = cmd.trimmingCharacters(in: .whitespaces)
        guard c.hasPrefix("sudo ") || c.hasPrefix("echo ") || c.hasPrefix("printf ") || c.hasPrefix("systemctl ") else { return false }
        return !c.contains("<") && !c.contains("visudo") && !c.contains("do-release-upgrade")
    }

    public static func generate(for audit: ExternalAudit) -> String {
        let family = OSFamily.from(audit.os?.distro)
        let osLabel = audit.os?.pretty ?? audit.os?.distro ?? "SO desconhecido"
        let famLabel = family == .dnf ? "família dnf (RHEL/Fedora/Rocky)"
                     : (family == .apt ? "família apt (Debian/Ubuntu)" : "família não identificada — comandos padrão apt, REVISE")
        // Achados abertos, únicos por controle, com comando de correção (ajustado à distro).
        var seen = Set<String>()
        var autoFixes: [(title: String, cmd: String)] = []
        var manual: [(title: String, note: String)] = []
        for f in audit.findings.filter({ $0.severity > .ok }).sorted(by: { $0.severity > $1.severity }) {
            let key = ComplianceMap.baseKey(f.id)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            guard let cmd = RemediationMap.remediation(for: f, family: family).command else { continue }
            if isAuto(cmd) { autoFixes.append((f.title, cmd)) }
            else { manual.append((f.title, cmd)) }
        }

        var s = """
        #!/usr/bin/env bash
        # =============================================================================
        # Playbook de hardening gerado pelo Uptend — host: \(audit.host.hostname)
        # SO auditado: \(osLabel) — \(famLabel)
        # REVISE antes de rodar. Rode em janela de manutenção, com acesso alternativo
        # ao servidor (o hardening de SSH pode derrubar sua sessão se algo der errado).
        #
        # Uso:  sudo bash playbook.sh            # aplica (faz backup antes)
        #       sudo bash playbook.sh rollback   # desfaz (restaura o backup)
        # =============================================================================
        set -u
        BK=/var/backups/uptend-hardening
        FILES="/etc/ssh/sshd_config /etc/login.defs /etc/security/pwquality.conf /etc/security/faillock.conf /etc/sudoers /etc/passwd /etc/group /etc/shadow"
        DIRS="/etc/sysctl.d /etc/ssh/sshd_config.d"

        reload_all() { systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null; sysctl --system >/dev/null 2>&1; }

        if [ "${1:-}" = "rollback" ]; then
            [ -d "$BK" ] || { echo "Sem backup em $BK — nada a desfazer."; exit 1; }
            cp -a "$BK/." / 2>/dev/null && reload_all
            echo "Rollback concluído (restaurado de $BK)."
            exit 0
        fi

        echo "== Backup de segurança =="
        if [ ! -d "$BK" ]; then
            mkdir -p "$BK"
            for f in $FILES; do [ -e "$f" ] && cp -a --parents "$f" "$BK/" 2>/dev/null; done
            for d in $DIRS;  do [ -d "$d" ] && cp -a --parents "$d" "$BK/" 2>/dev/null; done
            echo "Backup criado em $BK"
        else
            echo "Backup já existe em $BK (preservando o estado original)."
        fi

        echo "== Correções automáticas (\(autoFixes.count)) =="

        """

        if autoFixes.isEmpty {
            s += "echo 'Nenhuma correção automática aplicável — veja as notas manuais abaixo.'\n"
        } else {
            for fix in autoFixes {
                s += "echo '→ \(shSingleComment(fix.title))'\n\(fix.cmd)\n"
            }
        }

        s += "\nreload_all\n"
        s += "echo\n"
        s += "echo 'Concluído. Teste os serviços. Para desfazer tudo: sudo bash \\$0 rollback'\n"

        if !manual.isEmpty {
            s += "\n# =============================================================================\n"
            s += "# CORREÇÕES MANUAIS (\(manual.count)) — exigem revisão/decisão, NÃO automatizadas:\n"
            for m in manual {
                s += "#   • \(shComment(m.title))\n#       \(shComment(m.note))\n"
            }
            s += "# =============================================================================\n"
        }
        return s
    }

    // Sanitiza texto para dentro de um echo '...' (troca aspas simples).
    private static func shSingleComment(_ t: String) -> String {
        t.replacingOccurrences(of: "'", with: "’")
    }
    private static func shComment(_ t: String) -> String {
        t.replacingOccurrences(of: "\n", with: " ")
    }

    /// Contagem de correções automáticas (para a UI).
    public static func autoCount(for audit: ExternalAudit) -> Int {
        let family = OSFamily.from(audit.os?.distro)
        var seen = Set<String>(); var n = 0
        for f in audit.findings.filter({ $0.severity > .ok }) {
            let key = ComplianceMap.baseKey(f.id)
            guard !seen.contains(key) else { continue }; seen.insert(key)
            if let cmd = RemediationMap.remediation(for: f, family: family).command, isAuto(cmd) { n += 1 }
        }
        return n
    }
}
