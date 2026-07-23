import Foundation

// =============================================================================
// FROTA / MULTI-HOST ROLL-UP — FASE D1
// Agrega a ÚLTIMA auditoria de cada host numa visão organizacional: quem está
// mais fraco, nota média, distribuição por semáforo, heatmap por área e os
// achados mais comuns na frota. Base para a tela "Frota" e o relatório
// consolidado. Lógica pura → testável.
// =============================================================================

public struct FleetHostRow: Identifiable, Sendable, Equatable {
    public let hostKey: String
    public let hostname: String
    public let os: String
    public let collectedAt: String
    public let score: Int
    public let light: AuditLight
    public let criticalCount: Int
    public let highCount: Int
    public let openCount: Int              // achados abertos (severidade > ok)
    public let domainScores: [String: Int] // área → nota (0–100)
    public var id: String { hostKey }
}

public struct FleetFinding: Identifiable, Sendable, Equatable {
    public let baseKey: String
    public let title: String
    public let severity: AuditSeverity
    public let hostCount: Int              // em quantos hosts está aberto
    public var id: String { baseKey }
}

public struct Fleet: Sendable, Equatable {
    public let hosts: [FleetHostRow]       // pior nota primeiro
    public let avgScore: Int
    public let domains: [String]           // áreas presentes (ordem canônica)
    public let redCount: Int
    public let yellowCount: Int
    public let greenCount: Int
    public let topFindings: [FleetFinding] // mais comuns na frota (por nº de hosts)

    public var hostCount: Int { hosts.count }
    public var isEmpty: Bool { hosts.isEmpty }
}

public enum FleetRollup {

    /// Identidade estável do host (machineId; cai para hostname).
    public static func hostKey(_ a: ExternalAudit) -> String {
        let mid = a.host.machineId ?? ""
        return mid.isEmpty ? a.host.hostname : mid
    }

    /// A última auditoria (por data de coleta) de cada host.
    public static func latestPerHost(_ audits: [ExternalAudit]) -> [ExternalAudit] {
        var byHost: [String: ExternalAudit] = [:]
        for a in audits {
            let k = hostKey(a)
            if let cur = byHost[k] {
                if a.collectedAt > cur.collectedAt { byHost[k] = a }
            } else {
                byHost[k] = a
            }
        }
        return Array(byHost.values)
    }

    public static func rollup(_ audits: [ExternalAudit]) -> Fleet {
        let latest = latestPerHost(audits)

        var rows: [FleetHostRow] = []
        for a in latest {
            let s = AuditScoring.evaluate(a)
            var dmap: [String: Int] = [:]
            for d in AuditDomains.scores(a) { dmap[d.name] = d.score }
            rows.append(FleetHostRow(
                hostKey: hostKey(a), hostname: a.host.hostname, os: a.os?.pretty ?? "—",
                collectedAt: a.collectedAt, score: s.score, light: s.light,
                criticalCount: a.findings.filter { $0.severity == .critical }.count,
                highCount: a.findings.filter { $0.severity == .high }.count,
                openCount: a.findings.filter { $0.severity > .ok }.count,
                domainScores: dmap))
        }
        rows.sort { $0.score != $1.score ? $0.score < $1.score
            : $0.hostname.localizedCaseInsensitiveCompare($1.hostname) == .orderedAscending }

        let avg = rows.isEmpty ? 0 : Int((rows.map(\.score).reduce(0, +) / rows.count))
        let domains = AuditDomains.order.filter { name in rows.contains { $0.domainScores[name] != nil } }

        // Achados mais comuns na frota (por chave-base canônica, contando hosts distintos)
        var agg: [String: (title: String, sev: AuditSeverity, hosts: Set<String>)] = [:]
        for a in latest {
            let k = hostKey(a)
            for f in a.findings where f.severity > .ok {
                let bk = ComplianceMap.controlKey(f.id)
                if var e = agg[bk] {
                    e.hosts.insert(k)
                    if f.severity > e.sev { e.sev = f.severity; e.title = f.title }
                    agg[bk] = e
                } else {
                    agg[bk] = (f.title, f.severity, [k])
                }
            }
        }
        var top: [FleetFinding] = agg.map {
            FleetFinding(baseKey: $0.key, title: $0.value.title,
                         severity: $0.value.sev, hostCount: $0.value.hosts.count)
        }
        top.sort { a, b in
            if a.hostCount != b.hostCount { return a.hostCount > b.hostCount }
            if a.severity != b.severity { return a.severity > b.severity }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }

        return Fleet(hosts: rows, avgScore: avg, domains: domains,
                     redCount: rows.filter { $0.light == .red }.count,
                     yellowCount: rows.filter { $0.light == .yellow }.count,
                     greenCount: rows.filter { $0.light == .green }.count,
                     topFindings: top)
    }

    // MARK: Export CSV

    public static func csv(_ fleet: Fleet) -> String {
        var out = "host,so,coletado_em,nota,semaforo,criticos,altos,abertos"
        for d in fleet.domains { out += ",\(d)" }
        out += "\n"
        for h in fleet.hosts {
            let cols: [String] = [h.hostname, h.os, String(h.collectedAt.prefix(10)), String(h.score),
                    lightLabel(h.light), String(h.criticalCount), String(h.highCount), String(h.openCount)]
            out += cols.map(csvEscape).joined(separator: ",")
            for d in fleet.domains {
                let v = h.domainScores[d].map(String.init) ?? ""
                out += ",\(v)"
            }
            out += "\n"
        }
        return out
    }

    static func lightLabel(_ l: AuditLight) -> String {
        switch l { case .red: "vermelho"; case .yellow: "amarelo"; case .green: "verde" }
    }

    private static func csvEscape(_ v: String) -> String {
        if v.contains(",") || v.contains("\"") || v.contains("\n") {
            return "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return v
    }
}
