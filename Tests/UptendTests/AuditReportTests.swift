import Testing
import Foundation
@testable import UptendCore

/// Geração de relatórios (Markdown + HTML) da Auditoria Externa.
struct AuditReportTests {

    private func loadFixture() throws -> ExternalAudit {
        let url = try #require(Bundle.module.url(forResource: "lab-audit", withExtension: "json", subdirectory: "Fixtures"))
        return try ExternalAuditParser.parse(Data(contentsOf: url))
    }

    @Test func markdownHasKeySections() throws {
        let audit = try loadFixture()
        let md = AuditReport.markdown(audit)
        #expect(md.contains("# Auditoria de segurança — uptend-lab"))
        #expect(md.contains("## Resumo por severidade"))
        #expect(md.contains("## Máquina e sistema"))
        #expect(md.contains("## Todos os achados"))
        // Um achado conhecido da fixture aparece.
        #expect(md.contains("atualização") || md.contains("Firewall") || md.contains("SSH"))
        #expect(md.contains("Nota geral:"))
    }

    @Test func htmlIsSelfContainedAndEscaped() throws {
        let audit = try loadFixture()
        let html = AuditReport.html(audit)
        #expect(html.hasPrefix("<!DOCTYPE html>"))
        #expect(html.contains("<style>"))              // CSS embutido
        #expect(html.contains("<svg"))                 // gauge inline
        #expect(html.contains("uptend-lab"))
        // Nada de recurso externo (relatório abre offline).
        #expect(html.contains("http://") == false)
        #expect(html.contains("https://") == false)
        #expect(html.lowercased().contains("<script") == false)
    }

    @Test func htmlEscapesDangerousText() {
        // Um título com HTML não deve injetar markup no relatório.
        let audit = ExternalAudit(
            schemaVersion: 1,
            collector: .init(name: "x", version: "1", mode: "user"),
            collectedAt: "2026-07-17T00:00:00Z",
            host: .init(hostname: "<b>evil</b>", machineId: nil),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: [.init(id: "x", title: "<script>alert(1)</script>", severity: .high, category: "X")],
            lynis: nil)
        let html = AuditReport.html(audit)
        #expect(html.contains("<script>alert(1)</script>") == false)
        #expect(html.contains("&lt;script&gt;"))
        #expect(html.contains("&lt;b&gt;evil&lt;/b&gt;"))
    }

    @Test func markdownEscapesPipeInTableCell() {
        // B6: um título com `|` quebraria a coluna da tabela Markdown.
        let audit = ExternalAudit(
            schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "user"),
            collectedAt: "2026-07-17T00:00:00Z", host: .init(hostname: "srv", machineId: nil),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: [.init(id: "ssh-root-login", title: "SSH root | admin", severity: .high, category: "Segurança / SSH")],
            lynis: nil)
        let md = AuditReport.markdown(audit)
        // Na tabela de conformidade, a célula sai com o pipe escapado (não quebra a coluna).
        #expect(md.contains("| SSH root \\| admin |"))
    }

    @Test func mappingTableEscapesCisField() {
        // Regressão A3: o campo `cis` vem do JSON do coletor (host adversarial) e
        // era interpolado sem esc() na tabela de mapeamento (relatório Técnico + SOC).
        let payload = "<img src=x onerror=alert(1)>"
        let audit = ExternalAudit(
            schemaVersion: 1,
            collector: .init(name: "x", version: "1", mode: "user"),
            collectedAt: "2026-07-17T00:00:00Z",
            host: .init(hostname: "srv", machineId: nil),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            // id mapeado (hasAnyRef) para entrar na mappingTable; cis malicioso.
            findings: [.init(id: "ssh-root-login", title: "SSH root", severity: .high,
                             category: "Segurança / SSH", cis: payload)],
            lynis: nil)
        #expect(AuditReport.html(audit).contains(payload) == false)
        #expect(AuditReport.socHTML(audit).contains(payload) == false)
    }

    @Test func markdownReflectsScore() throws {
        let audit = try loadFixture()
        let s = AuditScoring.evaluate(audit)
        let md = AuditReport.markdown(audit)
        #expect(md.contains("\(s.score)/100"))
    }

    @Test func reportsIncludeExpandedResourcesAndUsers() throws {
        let audit = try loadFixture()
        let md = AuditReport.markdown(audit)
        #expect(md.contains("Uso do disco raiz:"))
        #expect(md.contains("Acesso administrativo (sudo):"))
        let html = AuditReport.html(audit)
        #expect(html.contains("Uso do disco (/)"))
        #expect(html.contains("Acesso admin (sudo)"))
    }

    @Test func reportsIncludeDockerAndProfile() throws {
        let audit = try loadFixture()   // lab tem 6 containers + perfil
        let md = AuditReport.markdown(audit)
        #expect(md.contains("## Perfil do servidor"))
        #expect(md.contains("## Docker / containers"))
        #expect(md.contains("postgres"))
        let tech = AuditReport.html(audit)
        #expect(tech.contains("Perfil do servidor"))
        #expect(tech.contains("Docker ·"))
        let exec = AuditReport.executiveHTML(audit)
        #expect(exec.contains("Para que serve este servidor"))
        #expect(exec.contains("Serviços em execução"))
        // Descrição amigável de container aparece no executivo.
        #expect(exec.contains("PostgreSQL"))
    }

    @Test func socReportHasSecurityStructure() throws {
        let audit = try loadFixture()
        let html = AuditReport.socHTML(audit)
        #expect(html.hasPrefix("<!DOCTYPE html>"))
        #expect(html.contains("Relatório de Segurança (SOC)"))
        #expect(html.contains("Postura de segurança"))
        #expect(html.contains("Mapeamento de controles"))   // achados → CIS/ISO/NIST/OWASP
        #expect(html.contains("Endurecimento (Lynis)"))      // fixture tem Lynis
        // Autocontido/offline.
        #expect(html.contains("http://") == false && html.contains("https://") == false)
        #expect(html.lowercased().contains("<script") == false)
    }

    @Test func reportsIncludeComplianceFrameworks() throws {
        let audit = try loadFixture()
        // Executivo: aderência em linguagem de negócio + LGPD/ISO.
        let exec = AuditReport.executiveHTML(audit)
        #expect(exec.contains("Conformidade e boas práticas"))
        #expect(exec.contains("ISO/IEC 27001"))
        // SOC: aderência por framework + tabela de mapeamento.
        let soc = AuditReport.socHTML(audit)
        #expect(soc.contains("Aderência por framework"))
        #expect(soc.contains("Mapeamento de controles"))
        #expect(soc.contains("NIST"))
        #expect(soc.contains("OWASP"))
        // Técnico: apêndice de conformidade + chips.
        let tech = AuditReport.html(audit)
        #expect(tech.contains("mapeamento de conformidade"))
        #expect(tech.contains("fw iso") || tech.contains("ISO 27001"))
        // Markdown: seção de conformidade.
        let md = AuditReport.markdown(audit)
        #expect(md.contains("## Conformidade (frameworks)"))
    }

    @Test func eachReportHasItsSignature() throws {
        let audit = try loadFixture()
        // Executivo: maturidade + o que está em jogo + ganhos rápidos.
        let exec = AuditReport.executiveHTML(audit)
        #expect(exec.contains("Nível de maturidade"))
        #expect(exec.contains("O que está em jogo"))
        #expect(exec.contains("Ganho rápido") || exec.contains("Projeto"))
        // SOC: MITRE ATT&CK + NIST função + detecção.
        let soc = AuditReport.socHTML(audit)
        #expect(soc.contains("MITRE ATT&CK"))
        #expect(soc.contains("NIST CSF"))
        #expect(soc.contains("Detecção e resposta"))
        // Técnico: comando de correção exato (bloco cmd).
        let tech = AuditReport.html(audit)
        #expect(tech.contains("class='cmd'"))
        #expect(tech.contains("sudo"))
        // Markdown: plano de remediação com comando.
        let md = AuditReport.markdown(audit)
        #expect(md.contains("## Plano de remediação"))
        #expect(md.contains("```bash"))
    }

    @Test func containerPurposeRecognizesCommonImages() {
        #expect(AuditReport.containerPurpose(image: "postgres:16-alpine")?.contains("PostgreSQL") == true)
        #expect(AuditReport.containerPurpose(image: "nginx:alpine")?.contains("nginx") == true)
        #expect(AuditReport.containerPurpose(image: "louislam/uptime-kuma:1")?.contains("disponibilidade") == true)
        #expect(AuditReport.containerPurpose(image: "imagem-desconhecida:1") == nil)
    }

    @Test func executiveReportIsBusinessOrientedAndSelfContained() throws {
        let audit = try loadFixture()
        let html = AuditReport.executiveHTML(audit)
        #expect(html.hasPrefix("<!DOCTYPE html>"))
        #expect(html.contains("Relatório Executivo"))
        #expect(html.contains("Plano de ação recomendado"))     // sugestões de melhoria
        #expect(html.contains("O que já está protegido"))       // pontos fortes
        #expect(html.contains("Panorama de risco"))
        // Autocontido/offline e sem script.
        #expect(html.contains("http://") == false && html.contains("https://") == false)
        #expect(html.lowercased().contains("<script") == false)
    }

    @Test func executiveVerdictMatchesScoreBand() {
        // Nota alta → veredito "boa"; nota baixa → "crítica".
        func audit(findings: [AuditFinding]) -> ExternalAudit {
            ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "user"),
                          collectedAt: "2026-07-17T00:00:00Z", host: .init(hostname: "h", machineId: nil),
                          machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil, findings: findings, lynis: nil)
        }
        let good = AuditReport.executiveHTML(audit(findings: [.init(id: "a", title: "ok", severity: .ok, category: "X")]))
        #expect(good.contains("Postura de segurança boa"))
        let bad = AuditReport.executiveHTML(audit(findings: (0..<4).map {
            .init(id: "c\($0)", title: "t", severity: .critical, category: "X")
        }))
        #expect(bad.contains("Situação crítica"))
    }

    @Test func executiveEscapesText() {
        let audit = ExternalAudit(schemaVersion: 1, collector: .init(name: "x", version: "1", mode: "user"),
            collectedAt: "2026-07-17T00:00:00Z", host: .init(hostname: "<b>h</b>", machineId: nil),
            machine: nil, os: nil, disks: [], resources: nil, users: nil, docker: nil, profile: nil,
            findings: [.init(id: "x", title: "<img src=x>", severity: .high, category: "X",
                             recommendation: "faça <i>algo</i>", businessImpact: "risco")],
            lynis: nil)
        let html = AuditReport.executiveHTML(audit)
        #expect(html.contains("<img src=x>") == false)
        #expect(html.contains("&lt;img src=x&gt;"))
    }
}
