import Foundation

// =============================================================================
// ENRIQUECIMENTO DE CVE (versões → vulnerabilidades conhecidas) — FASE C1
// Cruza as versões de software colhidas (host + Docker) com uma base CURADA e
// OFFLINE de CVEs de alto impacto. O cruzamento roda no Mac (o coletor nunca faz
// rede). Lógica pura → testável.
//
// HONESTIDADE (essencial): distros aplicam BACKPORT da correção sem mudar a versão
// upstream. Logo isto indica EXPOSIÇÃO POTENCIAL ("confirme o patch da distro"),
// não vulnerabilidade categórica. E é um SUBCONJUNTO curado de CVEs críticas —
// não um espelho completo do NVD.
// =============================================================================

public struct CVE: Equatable, Sendable {
    public let id: String            // ex.: "CVE-2024-6387"
    public let package: String       // nome canônico do software (ex.: "openssh")
    public let ranges: [Range]       // [introduzida, corrigida) — pode ter vários trechos
    public let cvss: Double
    public let title: String         // resumo curto em PT
    public let reference: String     // pista de verificação/patch

    public struct Range: Equatable, Sendable {
        public let introduced: String   // inclusive
        public let fixed: String         // exclusive
        public init(_ introduced: String, _ fixed: String) { self.introduced = introduced; self.fixed = fixed }
    }

    public var severity: AuditSeverity {
        if cvss >= 9.0 { return .critical }
        if cvss >= 7.0 { return .high }
        if cvss >= 4.0 { return .medium }
        return .low
    }
}

public struct CVEMatch: Identifiable, Equatable, Sendable {
    public let cve: CVE
    public let software: ExternalAudit.SoftwarePackage
    public var id: String { "\(cve.id)#\(software.id)" }
}

public enum CVEDatabase {
    /// Subconjunto curado de CVEs de alto impacto, com faixas de versão claras.
    public static let all: [CVE] = [
        // OpenSSH
        CVE(id: "CVE-2024-6387", package: "openssh",
            ranges: [.init("8.5p1", "9.8p1")], cvss: 8.1,
            title: "regreSSHion — execução remota de código no sshd (condição de corrida no signal handler)",
            reference: "Atualize o OpenSSH ≥ 9.8p1 ou aplique o patch da distro."),
        CVE(id: "CVE-2023-38408", package: "openssh",
            ranges: [.init("5.5", "9.3p2")], cvss: 9.8,
            title: "Execução remota via encaminhamento do ssh-agent (PKCS#11)",
            reference: "Atualize para OpenSSH ≥ 9.3p2."),
        // OpenSSL
        CVE(id: "CVE-2014-0160", package: "openssl",
            ranges: [.init("1.0.1", "1.0.1g")], cvss: 7.5,
            title: "Heartbleed — vazamento de memória via extensão heartbeat do TLS",
            reference: "Atualize para OpenSSL ≥ 1.0.1g e reemita chaves/certificados."),
        CVE(id: "CVE-2022-3602", package: "openssl",
            ranges: [.init("3.0.0", "3.0.7")], cvss: 7.5,
            title: "Estouro de buffer na verificação de certificado (punycode)",
            reference: "Atualize para OpenSSL ≥ 3.0.7."),
        // sudo
        CVE(id: "CVE-2021-3156", package: "sudo",
            ranges: [.init("1.8.2", "1.8.32"), .init("1.9.0", "1.9.5p2")], cvss: 7.8,
            title: "Baron Samedit — escalonamento de privilégio (heap overflow no sudoedit)",
            reference: "Atualize para sudo ≥ 1.9.5p2."),
        CVE(id: "CVE-2023-22809", package: "sudo",
            ranges: [.init("1.8.0", "1.9.12p2")], cvss: 7.8,
            title: "Escalonamento via variável EDITOR no sudoedit",
            reference: "Atualize para sudo ≥ 1.9.12p2."),
        // nginx
        CVE(id: "CVE-2021-23017", package: "nginx",
            ranges: [.init("0.6.18", "1.21.0")], cvss: 7.7,
            title: "Off-by-one no resolvedor DNS (possível execução de código)",
            reference: "Atualize para nginx ≥ 1.21.0 (ou 1.20.1)."),
        // Apache httpd
        CVE(id: "CVE-2021-41773", package: "apache",
            ranges: [.init("2.4.49", "2.4.50")], cvss: 7.5,
            title: "Path traversal / RCE no Apache httpd 2.4.49",
            reference: "Atualize para Apache httpd ≥ 2.4.51."),
        CVE(id: "CVE-2021-42013", package: "apache",
            ranges: [.init("2.4.49", "2.4.51")], cvss: 9.8,
            title: "Path traversal / RCE (correção incompleta do 41773)",
            reference: "Atualize para Apache httpd ≥ 2.4.51."),
        // bash
        CVE(id: "CVE-2014-6271", package: "bash",
            ranges: [.init("3.0", "4.3.30")], cvss: 9.8,
            title: "Shellshock — execução de comandos via variáveis de ambiente",
            reference: "Atualize o bash (backport da distro costuma cobrir)."),
    ]
}

public enum CVEMatcher {

    /// Converte uma versão em componentes numéricos comparáveis.
    /// Trata `p` como separador (9.6p1 → 9.6.1) e letra final estilo OpenSSL (1.0.1f → 1.0.1.6).
    static func parse(_ version: String) -> [Int] {
        var v = version.lowercased().trimmingCharacters(in: .whitespaces)
        // "p" só é separador quando está entre dígitos (9.6p1) — trocar todo "p"
        // mutilaria sufixos como "-alpine".
        v = v.replacingOccurrences(of: #"(?<=\d)p(?=\d)"#, with: ".", options: .regularExpression)
        var out: [Int] = []
        for part in v.split(separator: ".") {
            let digits = part.prefix { $0.isNumber }
            out.append(Int(digits) ?? 0)
            // letra logo após os dígitos (openssl): "1f" ou "1g-r0" → a=1…z=26.
            // Olhar o fim do segmento erraria em sufixos de pacote ("1g-r0" termina em "0").
            let rest = part.dropFirst(digits.count)
            if let c = rest.first, c.isLetter, c.isASCII, let sc = c.unicodeScalars.first {
                out.append(Int(sc.value) - Int(Character("a").unicodeScalars.first!.value) + 1)
            }
        }
        return out
    }

    /// -1 se a<b, 0 se igual, 1 se a>b (comprimentos diferentes preenchidos com 0).
    static func compare(_ a: [Int], _ b: [Int]) -> Int {
        let n = max(a.count, b.count)
        for i in 0..<n {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x < y ? -1 : 1 }
        }
        return 0
    }

    static func inRange(_ version: String, _ r: CVE.Range) -> Bool {
        let v = parse(version)
        return compare(v, parse(r.introduced)) >= 0 && compare(v, parse(r.fixed)) < 0
    }

    /// Extrai software (nome canônico + versão) das imagens Docker (ex.: nginx:1.21 → nginx 1.21).
    public static func softwareFromDocker(_ audit: ExternalAudit) -> [ExternalAudit.SoftwarePackage] {
        guard let docker = audit.docker, docker.installed else { return [] }
        let known = Set(CVEDatabase.all.map(\.package)).union(["httpd", "postgres", "mysql", "redis"])
        var out: [ExternalAudit.SoftwarePackage] = []
        for c in docker.containers {
            // "repo/nome:tag" → nome, tag
            let noRepo = c.image.split(separator: "/").last.map(String.init) ?? c.image
            let parts = noRepo.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            var name = String(parts[0]).lowercased()
            let tag = String(parts[1])
            if name == "httpd" { name = "apache" }
            guard known.contains(name), tag.first?.isNumber == true else { continue }
            out.append(.init(name: name, version: tag, source: "docker:\(c.name)"))
        }
        return out
    }

    /// Todo o software conhecido da auditoria (host + Docker).
    public static func allSoftware(_ audit: ExternalAudit) -> [ExternalAudit.SoftwarePackage] {
        (audit.software ?? []) + softwareFromDocker(audit)
    }

    /// Cruza o software com a base de CVE. Cada par (versão dentro de faixa vulnerável) vira um match.
    public static func matches(_ software: [ExternalAudit.SoftwarePackage]) -> [CVEMatch] {
        var out: [CVEMatch] = []
        for pkg in software {
            for cve in CVEDatabase.all where cve.package == pkg.name.lowercased() {
                if cve.ranges.contains(where: { inRange(pkg.version, $0) }) {
                    out.append(CVEMatch(cve: cve, software: pkg))
                }
            }
        }
        // piores primeiro (CVSS desc), desempate estável
        return out.sorted {
            $0.cve.cvss != $1.cve.cvss ? $0.cve.cvss > $1.cve.cvss : $0.cve.id < $1.cve.id
        }
    }

    public static func matches(for audit: ExternalAudit) -> [CVEMatch] {
        matches(allSoftware(audit))
    }

    // MARK: Export CSV

    public static func csv(_ matches: [CVEMatch]) -> String {
        var out = "cve,software,versao,origem,cvss,severidade,titulo,referencia\n"
        for m in matches {
            out += [m.cve.id, m.software.name, m.software.version, m.software.source ?? "host",
                    String(m.cve.cvss), m.cve.severity.label, m.cve.title, m.cve.reference]
                .map(csvEscape).joined(separator: ",") + "\n"
        }
        return out
    }

    private static func csvEscape(_ v: String) -> String {
        if v.contains(",") || v.contains("\"") || v.contains("\n") {
            return "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return v
    }
}
