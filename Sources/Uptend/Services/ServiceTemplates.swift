import Foundation

// =============================================================================
// TEMPLATES DE SERVIÇOS — Passo 2 do módulo Servidor
// Catálogo de serviços self-hosted que instalam com 1 clique via `docker run`.
// Cada template declara imagem, portas, volumes e campos de config editáveis.
// Comando montado com args validados (SSHRunner ainda envolve cada um em aspas).
// =============================================================================

struct TemplateField: Identifiable, Hashable {
    enum Kind: Hashable { case port, password, text }
    let key: String
    let label: String
    let kind: Kind
    var value: String
    var containerPort: Int? = nil   // para campos de porta
    var udp: Bool = false
    var envVar: String? = nil       // para password/text
    var id: String { key }
}

struct ServiceTemplate: Identifiable {
    let id: String                  // nome padrão do container
    let name: String
    let category: String
    let description: String
    let image: String
    let icon: String
    var fields: [TemplateField]
    var volumes: [VolumeMount] = []
    var extraArgs: [String] = []
    var webContainerPort: Int? = nil   // porta interna a abrir no navegador

    struct VolumeMount: Hashable { let name: String; let mount: String }

    /// Monta o `docker run` a partir do nome e dos campos preenchidos.
    func dockerRunArgs(name: String, fields: [TemplateField]) -> [String] {
        var args = ["docker", "run", "-d", "--name", name, "--restart", "unless-stopped"]
        for f in fields where f.kind == .port {
            let mapping = "\(f.value):\(f.containerPort ?? 0)" + (f.udp ? "/udp" : "")
            args += ["-p", mapping]
        }
        for f in fields where f.kind != .port {
            if let env = f.envVar, !f.value.isEmpty { args += ["-e", "\(env)=\(f.value)"] }
        }
        for v in volumes { args += ["-v", "\(name)-\(v.name):\(v.mount)"] }
        args += extraArgs
        args += [image]
        return args
    }

    /// Porta do host mapeada para a porta web (para montar a URL de acesso).
    func webHostPort(_ fields: [TemplateField]) -> String? {
        guard let wp = webContainerPort else { return nil }
        return fields.first { $0.kind == .port && $0.containerPort == wp && !$0.udp }?.value
    }

    /// Extrai a porta do host mapeada para `cp` a partir da string de portas do docker.
    /// Ex.: hostPort(forContainerPort: 3001, in: "0.0.0.0:3001->3001/tcp, [::]:…") == "3001".
    static func hostPort(forContainerPort cp: Int, in ports: String) -> String? {
        for raw in ports.split(separator: ",") {
            let part = raw.trimmingCharacters(in: .whitespaces)
            guard let arrow = part.range(of: "->") else { continue }
            let after = part[arrow.upperBound...]                  // "3001/tcp"
            guard Int(after.prefix { $0.isNumber }) == cp else { continue }
            let before = part[..<arrow.lowerBound]                 // "0.0.0.0:3001"
            if let colon = before.lastIndex(of: ":") {
                return String(before[before.index(after: colon)...])
            }
        }
        return nil
    }

    /// Valida nome e portas antes do deploy. Retorna a mensagem de erro, ou nil se ok.
    func validate(name: String, fields: [TemplateField]) -> String? {
        guard InputValidator.isValidContainerName(name) else { return "Nome de container inválido." }
        for f in fields where f.kind == .port {
            guard let p = Int(f.value), (1...65535).contains(p) else { return "Porta inválida em \"\(f.label)\"." }
        }
        return nil
    }
}

enum ServiceCatalog {
    static func port(_ key: String, _ label: String, _ host: String, _ container: Int, udp: Bool = false) -> TemplateField {
        TemplateField(key: key, label: label, kind: .port, value: host, containerPort: container, udp: udp)
    }

    static let templates: [ServiceTemplate] = [
        ServiceTemplate(
            id: "uptime-kuma", name: "Uptime Kuma", category: "Monitoramento",
            description: "Monitor de disponibilidade dos seus serviços, com alertas.",
            image: "louislam/uptime-kuma:1", icon: "waveform.path.ecg",
            fields: [port("web", "Porta (web)", "3001", 3001)],
            volumes: [.init(name: "data", mount: "/app/data")], webContainerPort: 3001),

        ServiceTemplate(
            id: "portainer", name: "Portainer", category: "Docker",
            description: "Painel web para gerenciar Docker (containers, imagens, volumes).",
            image: "portainer/portainer-ce:latest", icon: "shippingbox",
            fields: [port("web", "Porta (web)", "9000", 9000)],
            volumes: [.init(name: "data", mount: "/data")],
            extraArgs: ["-v", "/var/run/docker.sock:/var/run/docker.sock"], webContainerPort: 9000),

        ServiceTemplate(
            id: "dozzle", name: "Dozzle", category: "Monitoramento",
            description: "Visualizador de logs dos containers em tempo real, no navegador.",
            image: "amir20/dozzle:latest", icon: "doc.plaintext",
            fields: [port("web", "Porta (web)", "8888", 8080)],
            extraArgs: ["-v", "/var/run/docker.sock:/var/run/docker.sock:ro"], webContainerPort: 8080),

        ServiceTemplate(
            id: "vaultwarden", name: "Vaultwarden", category: "Segurança",
            description: "Cofre de senhas self-hosted, compatível com os apps do Bitwarden.",
            image: "vaultwarden/server:latest", icon: "key.horizontal",
            fields: [port("web", "Porta (web)", "8083", 80)],
            volumes: [.init(name: "data", mount: "/data")], webContainerPort: 80),

        ServiceTemplate(
            id: "gitea", name: "Gitea", category: "Dev",
            description: "Servidor Git leve — um GitHub próprio na sua rede.",
            image: "gitea/gitea:latest", icon: "arrow.triangle.branch",
            fields: [port("web", "Porta (web)", "3000", 3000)],
            volumes: [.init(name: "data", mount: "/data")], webContainerPort: 3000),

        ServiceTemplate(
            id: "n8n", name: "n8n", category: "Automação",
            description: "Automação de fluxos entre apps (tipo Zapier), self-hosted.",
            image: "docker.n8n.io/n8nio/n8n", icon: "point.3.filled.connected.trianglepath.dotted",
            fields: [port("web", "Porta (web)", "5678", 5678)],
            volumes: [.init(name: "data", mount: "/home/node/.n8n")], webContainerPort: 5678),

        ServiceTemplate(
            id: "metabase", name: "Metabase", category: "Análise (BI)",
            description: "Dashboards e relatórios no-code, self-hosted — ótimo para apresentar dados sem depender de nuvem.",
            image: "metabase/metabase:latest", icon: "chart.bar.xaxis",
            fields: [port("web", "Porta (web)", "3010", 3000)],
            volumes: [.init(name: "data", mount: "/metabase-data")],
            extraArgs: ["-e", "MB_DB_FILE=/metabase-data/metabase.db"], webContainerPort: 3000),

        ServiceTemplate(
            id: "pihole", name: "Pi-hole", category: "Rede",
            description: "Bloqueio de anúncios e rastreadores para toda a rede, via DNS.",
            image: "pihole/pihole:latest", icon: "shield.lefthalf.filled",
            fields: [
                port("dns_tcp", "DNS (TCP)", "53", 53),
                port("dns_udp", "DNS (UDP)", "53", 53, udp: true),
                port("web", "Porta (web)", "8089", 80),
                TemplateField(key: "pass", label: "Senha do painel", kind: .password, value: "", envVar: "WEBPASSWORD"),
            ],
            volumes: [.init(name: "data", mount: "/etc/pihole"), .init(name: "dnsmasq", mount: "/etc/dnsmasq.d")],
            webContainerPort: 80),
    ]

    static var categories: [String] {
        var seen: [String] = []
        for t in templates where !seen.contains(t.category) { seen.append(t.category) }
        return seen
    }

    // Stacks pesados (docker-compose / multi-container) — opcionais, só instalam quando
    // o usuário clicar (para não sobrecarregar máquinas com pouca RAM).
    static let stacks: [ServiceStack] = [
        ServiceStack(
            id: "wazuh", name: "Wazuh (SIEM/XDR)", category: "Segurança",
            description: "SIEM/XDR completo: análise de logs, integridade de arquivos, detecção de vulnerabilidades. Instala o stack oficial (single-node).",
            icon: "shield.checkerboard",
            ramNote: "Pesado — requer ~4 GB de RAM livres. Recomendado só em servidor com folga.",
            openNote: "Depois de subir (leva alguns minutos), abra em https://<ip do servidor> — aceite o certificado; usuário admin.",
            deployArgs: ["bash", "-lc",
                "sudo -n apt-get install -y git >/dev/null 2>&1 || true; " +
                "mkdir -p \"$HOME/uptend-deploys\"; cd \"$HOME/uptend-deploys\"; " +
                "[ -d wazuh-docker ] || git clone https://github.com/wazuh/wazuh-docker.git -b v4.9.2 --depth 1; " +
                "cd wazuh-docker/single-node; " +
                "docker compose -f generate-indexer-certs.yml run --rm generator; " +
                "docker compose up -d; " +
                "echo \"Wazuh subindo — pode levar vários minutos. Dashboard: https://<ip> (usuario admin).\""]),
    ]
}

/// Um stack pesado (multi-container) instalado por um script fixo, sob demanda.
struct ServiceStack: Identifiable {
    let id: String
    let name: String
    let category: String
    let description: String
    let icon: String
    let ramNote: String
    let openNote: String
    let deployArgs: [String]
}

/// Controlador de uma tarefa remota com log ao vivo (deploy de template).
@MainActor
final class RemoteTask: ObservableObject {
    @Published var log = ""
    @Published var running = false
    @Published var finished = false
    @Published var success = false

    /// Esconde valores de variáveis sensíveis (senha/token/segredo) ao EXIBIR o comando
    /// no log — o segredo não pode aparecer na tela (PADRÃO: segredo nunca em log).
    nonisolated static func redactedDisplay(_ args: [String]) -> String {
        args.map { arg -> String in
            guard let eq = arg.firstIndex(of: "="),
                  arg[..<eq].range(of: "(?i)password|passwd|token|secret", options: .regularExpression) != nil
            else { return arg }
            return String(arg[..<eq]) + "=•••"
        }.joined(separator: " ")
    }

    func run(host: RemoteHost, args: [String]) {
        running = true
        finished = false
        success = false
        log = "$ " + Self.redactedDisplay(args) + "\n\n"
        Task {
            let code = await SSHRunner.stream(host, args) { chunk in
                Task { @MainActor in self.log += chunk }
            }
            success = code == 0
            log += "\n\n== \(success ? "Concluído" : "Erro (código \(code))") ==\n"
            running = false
            finished = true
        }
    }
}
