import Foundation

// =============================================================================
// MAPA DE SUPERFÍCIE DE ATAQUE — FASE D3
// Deriva, do que a auditoria já colheu (portas expostas + TLS + Docker), o que
// está EXPOSTO e onde, com nível de risco por porta, e desenha um diagrama SVG
// autocontido. Lógica pura → testável.
// =============================================================================

public struct SurfaceEntry: Identifiable, Sendable, Equatable {
    public let port: Int
    public let service: String
    public let tls: String?       // "TLS", "TLS fraco" ou nil
    public let risk: AuditLight   // green/yellow/red
    public var id: Int { port }
}

public struct AttackSurface: Sendable, Equatable {
    public let hostname: String
    public let entries: [SurfaceEntry]     // pior risco primeiro
    public let containers: [String]        // imagens Docker
    public var redCount: Int { entries.filter { $0.risk == .red }.count }
    public var yellowCount: Int { entries.filter { $0.risk == .yellow }.count }
    public var greenCount: Int { entries.filter { $0.risk == .green }.count }
    public var isEmpty: Bool { entries.isEmpty }
}

public enum AttackSurfaceMap {

    static func service(_ port: Int) -> String {
        switch port {
        case 21: "FTP"; case 22: "SSH"; case 23: "Telnet"; case 25, 587: "SMTP"; case 465: "SMTPS"
        case 53: "DNS"; case 80: "HTTP"; case 110: "POP3"; case 143: "IMAP"; case 443: "HTTPS"
        case 993: "IMAPS"; case 995: "POP3S"; case 389: "LDAP"; case 636: "LDAPS"
        case 1433: "SQL Server"; case 3306: "MySQL"; case 5432: "PostgreSQL"; case 6379: "Redis"
        case 27017: "MongoDB"; case 11211: "Memcached"; case 9200: "Elasticsearch"; case 5601: "Kibana"
        case 3389: "RDP"; case 5900: "VNC"; case 8080: "HTTP (alt)"; case 8443: "HTTPS (alt)"
        case 3000: "App/Grafana"; case 9000: "App"; case 2049: "NFS"; case 445: "SMB"
        default: "Porta \(port)"
        }
    }

    /// Portas de dados/administração que NUNCA deveriam estar públicas.
    private static let neverPublic: Set<Int> = [23, 21, 3389, 5900, 445, 2049, 1433, 3306, 5432, 6379, 27017, 11211, 9200, 5601, 389]
    private static let tlsPorts: Set<Int> = [443, 8443, 993, 995, 465, 636]

    static func risk(port: Int, weakTLS: Bool) -> AuditLight {
        if neverPublic.contains(port) { return .red }
        if port == 22 { return .yellow }                       // SSH: restrinja por IP/firewall
        if tlsPorts.contains(port) { return weakTLS ? .yellow : .green }
        if port == 80 { return .yellow }                       // HTTP sem TLS
        return .yellow
    }

    public static func from(_ audit: ExternalAudit) -> AttackSurface {
        // Portas: extrai números do achado de portas expostas (+ SSH, sempre).
        var ports = Set<Int>([22])
        for f in audit.findings where ComplianceMap.baseKey(f.id) == "exposed-ports" {
            // Só tokens que SÃO uma porta: "80" ou "addr:8080". Capturar qualquer
            // sequência de dígitos fragmentaria um IP (192.168.1.10 → 4 "portas").
            for tok in (f.evidence ?? "").split(whereSeparator: { " ,\n\t".contains($0) }) {
                let cand = tok.contains(":") ? (tok.split(separator: ":").last ?? "") : tok
                if cand.allSatisfy(\.isNumber), let n = Int(cand), (1...65535).contains(n) {
                    ports.insert(n)
                }
            }
        }
        // TLS fraco/expirado detectado em qualquer serviço?
        let weakTLS = audit.findings.contains { $0.severity > .ok && ($0.id.hasPrefix("tls") || $0.id.hasPrefix("cert-tls")) }

        var entries = ports.map { p -> SurfaceEntry in
            let r = risk(port: p, weakTLS: weakTLS)
            let tls = tlsPorts.contains(p) ? (weakTLS ? "TLS fraco" : "TLS") : nil
            return SurfaceEntry(port: p, service: service(p), tls: tls, risk: r)
        }
        // pior risco primeiro; desempate por porta
        let order: [AuditLight: Int] = [.red: 0, .yellow: 1, .green: 2]
        entries.sort { (order[$0.risk] ?? 9, $0.port) < (order[$1.risk] ?? 9, $1.port) }

        let containers = (audit.docker?.containers ?? []).map(\.image)
        return AttackSurface(hostname: audit.host.hostname, entries: entries, containers: containers)
    }

    static func color(_ l: AuditLight) -> String {
        switch l { case .green: "#30a46c"; case .yellow: "#e2a336"; case .red: "#e5484d" }
    }

    /// Diagrama SVG autocontido: "Rede" no topo → chips de porta (por risco) → servidor.
    public static func svg(_ s: AttackSurface) -> String {
        guard !s.entries.isEmpty else { return "<p class='sub'>Nada exposto detectado.</p>" }
        let cols = min(s.entries.count, 4)
        let rows = (s.entries.count + cols - 1) / cols
        let chipW = 150, chipH = 58, gapX = 18, gapY = 20
        let topPad = 54, sidePad = 24
        let gridW = cols * chipW + (cols - 1) * gapX
        let W = gridW + sidePad * 2
        let gridH = rows * chipH + (rows - 1) * gapY
        let serverY = topPad + gridH + 46
        let H = serverY + 70
        let cx = W / 2

        var svg = "<svg viewBox='0 0 \(W) \(H)' width='100%' style='max-width:\(W)px'>"
        // Banda "Rede / Internet"
        svg += "<rect x='\(sidePad)' y='14' width='\(gridW)' height='26' rx='7' fill='#4a90d922' stroke='#4a90d955'/>"
        svg += "<text x='\(cx)' y='31' text-anchor='middle' font-size='13' fill='#4a90d9' font-weight='700'>🌐 Rede / Internet — superfície exposta</text>"

        // Servidor
        let sw = 220, sh = 44
        svg += "<rect x='\(cx - sw/2)' y='\(serverY)' width='\(sw)' height='\(sh)' rx='9' fill='var(--card)' stroke='var(--border)' stroke-width='1.5'/>"
        svg += "<text x='\(cx)' y='\(serverY + 27)' text-anchor='middle' font-size='14' font-weight='700' fill='var(--fg)'>🖥️ \(esc(s.hostname))</text>"

        // Chips + linhas até o servidor
        for (i, e) in s.entries.enumerated() {
            let r = i / cols, c = i % cols
            let colsInRow = (r == rows - 1) ? (s.entries.count - cols * (rows - 1)) : cols
            let rowW = colsInRow * chipW + (colsInRow - 1) * gapX
            let x0 = (W - rowW) / 2
            let x = x0 + c * (chipW + gapX)
            let y = topPad + r * (chipH + gapY)
            let col = color(e.risk)
            svg += "<line x1='\(x + chipW/2)' y1='\(y + chipH)' x2='\(cx)' y2='\(serverY)' stroke='\(col)55' stroke-width='1.5'/>"
            svg += "<rect x='\(x)' y='\(y)' width='\(chipW)' height='\(chipH)' rx='9' fill='\(col)22' stroke='\(col)' stroke-width='1.5'/>"
            svg += "<text x='\(x + 12)' y='\(y + 23)' font-size='14' font-weight='700' fill='\(col)'>\(e.port) · \(esc(e.service))</text>"
            let sub = e.tls ?? riskLabel(e.risk)
            svg += "<text x='\(x + 12)' y='\(y + 42)' font-size='11.5' fill='var(--muted)'>\(esc(sub))</text>"
        }
        svg += "</svg>"
        return svg
    }

    static func riskLabel(_ l: AuditLight) -> String {
        switch l { case .red: "risco alto — não deveria estar público"; case .yellow: "restrinja o acesso"; case .green: "ok" }
    }

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "'", with: "&#39;")
    }
}
