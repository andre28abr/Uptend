import Foundation

// =============================================================================
// AUDITORIA EXTERNA — geração de relatórios (Fase 3)
// Funções PURAS que transformam um ExternalAudit em:
//   • Markdown — documentação crua/estruturada (arquivo/IA).
//   • HTML     — relatório autocontido (CSS + gráficos SVG inline, offline, base do PDF).
// Sem rede, sem estado → testável isoladamente.
// =============================================================================

public enum AuditReport {

    // MARK: Utilidades de formatação

    static func bytesLabel(_ bytes: Int64?) -> String {
        guard let bytes, bytes > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func uptimeLabel(_ seconds: Double?) -> String {
        guard let seconds else { return "—" }
        let total = Int(seconds)
        let d = total / 86400, h = (total % 86400) / 3600, m = (total % 3600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    static func lightLabel(_ light: AuditLight) -> String {
        switch light {
        case .green: "Bom"
        case .yellow: "Atenção"
        case .red: "Crítico"
        }
    }

    /// Descrição amigável de um container pela imagem (para o resumo executivo).
    /// Reconhece as imagens mais comuns; senão, devolve nil.
    public static func containerPurpose(image: String) -> String? {
        let i = image.lowercased()
        let map: [(String, String)] = [
            ("postgres", "Banco de dados PostgreSQL"),
            ("mysql", "Banco de dados MySQL"),
            ("mariadb", "Banco de dados MariaDB"),
            ("mongo", "Banco de dados MongoDB"),
            ("redis", "Cache / fila (Redis)"),
            ("nginx", "Servidor web / proxy (nginx)"),
            ("caddy", "Servidor web / proxy (Caddy)"),
            ("traefik", "Proxy reverso (Traefik)"),
            ("httpd", "Servidor web (Apache)"),
            ("metabase", "Painéis e BI (Metabase)"),
            ("grafana", "Dashboards de métricas (Grafana)"),
            ("prometheus", "Coleta de métricas (Prometheus)"),
            ("uptime-kuma", "Monitor de disponibilidade"),
            ("dozzle", "Visualizador de logs de containers"),
            ("portainer", "Painel de gerência do Docker"),
            ("vaultwarden", "Cofre de senhas (Vaultwarden)"),
            ("gitea", "Servidor Git (Gitea)"),
            ("n8n", "Automação de fluxos (n8n)"),
            ("wazuh", "SIEM / segurança (Wazuh)"),
            ("pihole", "Bloqueio de anúncios (Pi-hole)"),
            ("nextcloud", "Nuvem de arquivos (Nextcloud)"),
        ]
        for (k, v) in map where i.contains(k) { return v }
        return nil
    }

    private static let severeFirst: [AuditSeverity] = [.critical, .high, .medium, .low, .ok]

    // =========================================================================
    // MARKDOWN — cru/estruturado (para arquivo e leitura por IA)
    // =========================================================================

    public static func markdown(_ audit: ExternalAudit, branding: ReportBranding? = nil) -> String {
        let s = AuditScoring.evaluate(audit, topN: 100)
        var out = ""
        func line(_ t: String = "") { out += t + "\n" }

        line("# Auditoria de segurança — \(audit.host.hostname)")
        line()
        if let b = branding, b.isConfigured {
            if !b.company.isEmpty { line("- **Auditor(a):** \(b.company)") }
            if !b.auditor.isEmpty { line("- **Responsável:** \(b.auditor)\(b.auditorTitle.isEmpty ? "" : " — \(b.auditorTitle)")") }
            if !b.client.isEmpty { line("- **Cliente:** \(b.client)") }
            if !b.reportNumber.isEmpty { line("- **Relatório nº:** \(b.reportNumber)") }
        }
        line("- **Nota geral:** \(s.score)/100 (\(lightLabel(s.light)))")
        line("- **Coletado em:** \(audit.collectedAt)")
        line("- **Modo do coletor:** \(audit.collector.mode)")
        line("- **Coletor:** \(audit.collector.name) \(audit.collector.version)")
        if let m = audit.host.machineId { line("- **ID da máquina:** \(m)") }
        line()

        // Resumo por severidade
        line("## Resumo por severidade")
        line()
        line("| Severidade | Achados |")
        line("|---|---|")
        for sev in severeFirst { line("| \(sev.label) | \(s.counts[sev] ?? 0) |") }
        line()

        // Pontuação por área
        let domains = AuditDomains.scores(audit)
        if !domains.isEmpty {
            line("## Pontuação por área")
            line()
            line("| Área | Nota | Verificações |")
            line("|---|---|---|")
            for d in domains { line("| \(d.name) | \(d.score)/100 | \(d.findings) |") }
            line()
        }

        // Principais riscos
        let risks = s.topRisks
        if !risks.isEmpty {
            line("## Principais riscos")
            line()
            for f in risks {
                line("### [\(f.severity.label.uppercased())] \(f.title)\(f.cis.map { " (CIS \($0))" } ?? "")")
                line("- **Categoria:** \(f.category)")
                if let e = f.evidence, !e.isEmpty { line("- **Evidência:** \(e)") }
                if let i = f.businessImpact, !i.isEmpty { line("- **Impacto de negócio:** \(i)") }
                if let r = f.recommendation, !r.isEmpty { line("- **Recomendação:** \(r)") }
                line()
            }
        }

        // Máquina e sistema
        line("## Máquina e sistema")
        line()
        if let m = audit.machine {
            line("- **Tipo:** \(m.virtual == true ? "Virtual" : "Física")")
            let vendorModel = [m.vendor, m.model].compactMap { $0 }.joined(separator: " ")
            if !vendorModel.isEmpty { line("- **Fabricante/modelo:** \(vendorModel)") }
            if let cpu = m.cpuModel { line("- **CPU:** \(cpu)\(m.cpuCores.map { " (\($0) núcleos)" } ?? "")") }
            line("- **Memória:** \(bytesLabel(m.ramBytes))")
            let bios = [m.biosVendor, m.biosVersion, m.biosDate].compactMap { $0 }.joined(separator: " · ")
            if !bios.isEmpty { line("- **BIOS/UEFI:** \(bios)") }
        }
        if let os = audit.os {
            line("- **Sistema:** \(os.pretty ?? [os.distro, os.version].compactMap { $0 }.joined(separator: " "))")
            if let k = os.kernel { line("- **Kernel:** \(k)") }
            if let eol = os.eolDate { line("- **Fim de suporte (EOL):** \(eol)") }
            if let up = os.uptimeSeconds { line("- **Ligado há:** \(uptimeLabel(up))") }
            if let t = os.updatesTotal { line("- **Atualizações pendentes:** \(t)\(os.updatesSecurity.map { " (\($0) de segurança)" } ?? "")") }
        }
        if let r = audit.resources {
            if let pct = r.diskRootPercent { line("- **Uso do disco raiz:** \(pct)%\(r.diskRootFreeBytes.map { " (\(bytesLabel($0)) livres)" } ?? "")") }
            if let sw = r.swapTotalBytes { line("- **Swap:** \(sw > 0 ? bytesLabel(sw) : "desativado")") }
            if r.rebootRequired == true { line("- **Reinício pendente:** sim") }
            if let ts = r.timeSynced { line("- **Relógio sincronizado (NTP):** \(ts ? "sim" : "não")") }
        }
        if let u = audit.users {
            if let n = u.loginUsers { line("- **Contas com login:** \(n)") }
            if !u.sudoUsers.isEmpty { line("- **Acesso administrativo (sudo):** \(u.sudoUsers.joined(separator: ", "))") }
            if !u.emptyPasswordUsers.isEmpty { line("- **Contas SEM senha:** \(u.emptyPasswordUsers.joined(separator: ", "))") }
        }
        line()

        // Discos
        if !audit.disks.isEmpty {
            line("## Discos")
            line()
            line("| Dispositivo | Modelo | Tamanho | Tipo | SMART | Horas |")
            line("|---|---|---|---|---|---|")
            for d in audit.disks {
                let smart = d.smartAvailable == true ? (d.smartHealthy == true ? "OK" : "FALHA") : "—"
                line("| /dev/\(mdCell(d.name)) | \(mdCell(d.model ?? "—")) | \(bytesLabel(d.sizeBytes)) | \(d.rotational == true ? "HDD" : "SSD") | \(smart) | \(d.powerOnHours.map(String.init) ?? "—") |")
            }
            line()
        }

        // Perfil do servidor (para que serve)
        if let p = audit.profile, !p.purposes.isEmpty {
            line("## Perfil do servidor")
            line()
            if let primary = p.primary { line("Propósito predominante: **\(primary)**.") ; line() }
            line("| Finalidade | Prontidão |")
            line("|---|---|")
            for pu in p.purposes.sorted(by: { $0.score > $1.score }) { line("| \(mdCell(pu.label)) | \(pu.score)% |") }
            line()
        }

        // Docker / containers
        if let dk = audit.docker, dk.installed {
            line("## Docker / containers (\(dk.running ?? 0)/\(dk.total ?? 0) ativos)")
            line()
            if !dk.containers.isEmpty {
                line("| Container | Imagem | Estado | Função |")
                line("|---|---|---|---|")
                for c in dk.containers {
                    line("| \(mdCell(c.name)) | \(mdCell(c.image)) | \(mdCell(c.state ?? "—")) | \(containerPurpose(image: c.image) ?? "—") |")
                }
                line()
            }
        }

        // Semáforo por categoria
        line("## Situação por categoria")
        line()
        line("| Categoria | Situação | Achados |")
        line("|---|---|---|")
        for c in s.categories { line("| \(c.category) | \(lightLabel(c.light)) | \(c.count) |") }
        line()

        // Conformidade (frameworks)
        let cov = ComplianceMap.coverage(audit)
        if !cov.isEmpty {
            line("## Conformidade (frameworks)")
            line()
            line("> \(complianceDisclaimer)")
            line()
            line("| Framework | Aderência | Controles |")
            line("|---|---|---|")
            for c in cov { line("| \(c.framework.rawValue) | \(c.percent)% | \(c.met)/\(c.checked) |") }
            line()
            line("| Achado | Status | CIS | ISO 27001 | NIST CSF | OWASP |")
            line("|---|---|---|---|---|---|")
            for f in audit.findings.filter({ ComplianceMap.hasAnyRef($0) }).sorted(by: { $0.severity > $1.severity }) {
                let r = ComplianceMap.refs(for: f)
                line("| \(mdCell(f.title)) | \(f.severity == .ok ? "Atendido" : "Não atendido") | \(mdCell(r.cis ?? "—")) | \(r.iso27001 ?? "—") | \(r.nist ?? "—") | \(r.owasp ?? "—") |")
            }
            line()
        }

        // Plano de remediação (comandos) — para os achados abertos
        let openFindings = audit.findings.filter { $0.severity > .ok }.sorted { $0.severity > $1.severity }
        if !openFindings.isEmpty {
            line("## Plano de remediação")
            line()
            let famMD = OSFamily.from(audit.os?.distro)
            for f in openFindings {
                let rem = RemediationMap.remediation(for: f, family: famMD)
                let mitre = MitreMap.technique(for: f).map { " · ATT&CK \($0.id) \($0.name)" } ?? ""
                line("### [\(f.severity.label)] \(f.title)\(mitre)")
                line("- **Esforço:** \(rem.effort == .quick ? "ganho rápido" : "projeto")")
                if let c = rem.command { line("- **Correção:**"); line(); line("```bash"); line(c); line("```") }
                if let raw = f.evidenceRaw, !raw.isEmpty {
                    let fence = mdFence(for: raw)
                    line("- **Evidência:**"); line(); line(fence); line(raw); line(fence)
                }
                line()
            }
        }

        // Todos os achados
        line("## Todos os achados (\(audit.findings.count))")
        line()
        for f in audit.findings.sorted(by: { $0.severity > $1.severity }) {
            line("- **[\(f.severity.label)]** \(f.title) — \(f.category)\(f.cis.map { " · CIS \($0)" } ?? "")")
        }
        line()

        // Lynis
        if let l = audit.lynis, l.available {
            line("## Lynis")
            line()
            line("- **Índice de endurecimento:** \(l.hardeningIndex.map { "\($0)/100" } ?? "não executado")")
            if !l.warnings.isEmpty {
                line("- **Avisos:**")
                for w in l.warnings { line("  - \(w)") }
            }
            if !l.suggestions.isEmpty {
                line("- **Sugestões:**")
                for sug in l.suggestions { line("  - \(sug)") }
            }
            line()
        }

        line("---")
        line("_Relatório gerado pelo Uptend a partir do coletor de Auditoria Externa (schema v\(audit.schemaVersion))._")
        return out
    }

    // =========================================================================
    // HTML — autocontido (CSS + SVG inline). Base para o PDF (Fase 4).
    // =========================================================================

    public static func html(_ audit: ExternalAudit, branding: ReportBranding? = nil, signature: ReportSignature? = nil) -> String {
        let s = AuditScoring.evaluate(audit, topN: 100)
        let accent = colorHex(s.light)

        var body = ""
        func add(_ t: String) { body += t + "\n" }

        add(classificationBanner(branding))
        add(brandingCover(branding, reportTitle: "Relatório Técnico de Auditoria de Segurança"))
        // Cabeçalho + nota (gauge SVG)
        add("<header class='head'>")
        add("<div><h1>Relatório Técnico de Auditoria</h1>")
        add("<p class='sub'>\(esc(audit.host.hostname)) · \(esc(audit.os?.pretty ?? "Sistema desconhecido")) · coletado \(esc(String(audit.collectedAt.prefix(10)))) · modo \(esc(audit.collector.mode))</p></div>")
        add(gaugeSVG(score: s.score, color: accent))
        add("</header>")

        add(metaBlock(audit, scope: "Inventário técnico e verificação de configuração (read-only)"))
        add("<section>\(severityLegend())</section>")

        // Pontuação por área
        let dbT = domainBars(audit)
        if !dbT.isEmpty { add("<section><h2>Pontuação por área</h2>\(dbT)</section>") }

        // Resumo por severidade (barras)
        add("<section><h2>Resumo por severidade</h2>")
        add(severityBars(s))
        add("</section>")

        // Semáforo por categoria
        add("<section><h2>Situação por categoria</h2><div class='cats'>")
        for c in s.categories {
            add("<div class='cat'><span class='dot' style='background:\(colorHex(c.light))'></span><span>\(esc(c.category))</span><span class='muted'>\(c.count)</span></div>")
        }
        add("</div></section>")

        // Principais riscos
        if !s.topRisks.isEmpty {
            add("<section><h2>Principais riscos</h2>")
            for f in s.topRisks { add(findingCard(f, full: true)) }
            add("</section>")
        }

        // Máquina e sistema
        add("<section><h2>Máquina e sistema</h2><div class='grid'>")
        if let m = audit.machine {
            add(infoCard("Máquina", m.virtual == true ? "Virtual" : "Física",
                         [m.vendor, m.model].compactMap { $0 }.joined(separator: " ")))
            add(infoCard("CPU", m.cpuModel ?? "—", m.cpuCores.map { "\($0) núcleos" } ?? ""))
            add(infoCard("Memória", bytesLabel(m.ramBytes), ""))
        }
        if let os = audit.os {
            add(infoCard("Sistema", os.distro ?? "—", os.version ?? ""))
            add(infoCard("Kernel", os.kernel ?? "—", ""))
            if let eol = os.eolDate {
                let past = eol < todayISO()
                add(infoCard("Fim de suporte", eol, past ? "FORA DE SUPORTE" : "com suporte", danger: past))
            }
            if let up = os.uptimeSeconds { add(infoCard("Ligado há", uptimeLabel(up), "")) }
        }
        if let r = audit.resources {
            if let pct = r.diskRootPercent {
                add(infoCard("Uso do disco (/)", "\(pct)%", r.diskRootFreeBytes.map { "\(bytesLabel($0)) livres" } ?? "", danger: pct >= 85))
            }
            if let sw = r.swapTotalBytes { add(infoCard("Swap", sw > 0 ? bytesLabel(sw) : "desativado", "")) }
            if r.rebootRequired == true { add(infoCard("Reinício", "Pendente", "atualizações aguardando", danger: true)) }
            if let ts = r.timeSynced { add(infoCard("Relógio (NTP)", ts ? "Sincronizado" : "Fora de sincronia", "", danger: !ts)) }
        }
        if let u = audit.users {
            if let n = u.loginUsers { add(infoCard("Contas com login", "\(n)", "")) }
            if !u.sudoUsers.isEmpty { add(infoCard("Acesso admin (sudo)", u.sudoUsers.joined(separator: ", "), "")) }
        }
        add("</div></section>")

        // Discos
        if !audit.disks.isEmpty {
            add("<section><h2>Discos</h2><table><thead><tr><th>Dispositivo</th><th>Modelo</th><th>Tamanho</th><th>Tipo</th><th>SMART</th><th>Horas</th></tr></thead><tbody>")
            for d in audit.disks {
                let smart = d.smartAvailable == true ? (d.smartHealthy == true ? "OK" : "FALHA") : "—"
                add("<tr><td>/dev/\(esc(d.name))</td><td>\(esc(d.model ?? "—"))</td><td>\(bytesLabel(d.sizeBytes))</td><td>\(d.rotational == true ? "HDD" : "SSD")</td><td>\(smart)</td><td>\(d.powerOnHours.map(String.init) ?? "—")</td></tr>")
            }
            add("</tbody></table></section>")
        }

        // Perfil do servidor
        if let p = audit.profile, !p.purposes.isEmpty {
            add("<section><h2>Perfil do servidor</h2>")
            if let primary = p.primary { add("<p class='lead'>Propósito predominante: <b>\(esc(primary))</b></p>") }
            add("<div class='bars'>")
            for pu in p.purposes.sorted(by: { $0.score > $1.score }) {
                add("<div class='barrow'><span class='lbl' style='width:150px'>\(esc(pu.label))</span><span class='track'><span class='fill' style='width:\(max(pu.score == 0 ? 0 : 4, pu.score))%;background:var(--accent)'></span></span><span class='n'>\(pu.score)%</span></div>")
            }
            add("</div></section>")
        }

        // Docker / containers
        if let dk = audit.docker, dk.installed {
            add("<section><h2>Docker · \(dk.running ?? 0)/\(dk.total ?? 0) containers ativos</h2>")
            if !dk.containers.isEmpty {
                add("<table><thead><tr><th>Container</th><th>Imagem</th><th>Estado</th><th>Função</th></tr></thead><tbody>")
                for c in dk.containers {
                    add("<tr><td>\(esc(c.name))</td><td>\(esc(c.image))</td><td>\(esc(c.state ?? "—"))</td><td>\(esc(containerPurpose(image: c.image) ?? "—"))</td></tr>")
                }
                add("</tbody></table>")
            }
            add("</section>")
        }

        // Todos os achados (com tags de framework + comando de correção exato)
        add("<section><h2>Todos os achados (\(audit.findings.count))</h2>")
        let famT = OSFamily.from(audit.os?.distro)
        for f in audit.findings.sorted(by: { $0.severity > $1.severity }) { add(findingCard(f, full: false, frameworks: true, command: true, family: famT)) }
        add("</section>")

        // Apêndice de conformidade
        let map = mappingTable(audit)
        if !map.isEmpty {
            add("<section><h2>Apêndice — mapeamento de conformidade</h2>")
            add("<p class='sub'>\(esc(complianceDisclaimer))</p>")
            add(complianceBars(audit))
            add(map)
            add("</section>")
        }

        // Lynis
        if let l = audit.lynis, l.available {
            add("<section><h2>Lynis</h2>")
            add("<p><b>Índice de endurecimento:</b> \(l.hardeningIndex.map { "\($0)/100" } ?? "não executado")</p>")
            if !l.warnings.isEmpty {
                add("<p><b>Avisos:</b></p><ul>")
                for w in l.warnings { add("<li>\(esc(w))</li>") }
                add("</ul>")
            }
            add("</section>")
        }

        add(signatureBlock(signature))
        add(methodologyHTML())
        add("<footer>CONFIDENCIAL · Relatório técnico gerado pelo Uptend · Auditoria Externa (schema v\(audit.schemaVersion)) · \(esc(humanDate(audit.collectedAt)))</footer>")

        return page(title: "Auditoria — \(audit.host.hostname)", accent: accent, body: body)
    }

    // =========================================================================
    // HTML EXECUTIVO — para diretoria/stakeholders (linguagem de negócio, sem jargão)
    // Mesma coleta, outra leitura: veredito, o que significa p/ o negócio, plano de
    // ação priorizado (o que corrigir primeiro e por quê) e pontos já protegidos.
    // =========================================================================

    public static func executiveHTML(_ audit: ExternalAudit, branding: ReportBranding? = nil, signature: ReportSignature? = nil) -> String {
        let s = AuditScoring.evaluate(audit, topN: 100)
        let accent = colorHex(s.light)
        let verdict = businessVerdict(score: s.score, light: s.light)

        var body = ""
        func add(_ t: String) { body += t + "\n" }

        add(classificationBanner(branding))
        add(brandingCover(branding, reportTitle: "Relatório Executivo de Segurança"))

        // Veredito
        add("<header class='ehead'>")
        add("<div class='etitle'><h1>Relatório Executivo de Segurança</h1>")
        add("<p class='esub'>\(esc(audit.host.hostname)) · \(esc(audit.os?.pretty ?? "servidor")) · \(esc(String(audit.collectedAt.prefix(10))))</p></div>")
        add(gaugeSVG(score: s.score, color: accent))
        add("</header>")

        add(metaBlock(audit, scope: "Configuração de segurança e boas práticas do servidor (auditoria automatizada read-only)"))

        let mat = maturity(s.score)
        add("<div class='verdict' style='border-color:\(accent)'>")
        add("<div class='vtag' style='background:\(accent)'>\(esc(verdict.title))</div>")
        add("<p>\(esc(verdict.sentence))</p>")
        add("<p style='margin:8px 0 0;font-size:14px'><b>Nível de maturidade:</b> \(esc(mat.level)) — \(esc(mat.note)).</p></div>")

        // Números que a diretoria entende
        let crit = s.counts[.critical] ?? 0, high = s.counts[.high] ?? 0
        let med = s.counts[.medium] ?? 0, ok = s.counts[.ok] ?? 0
        add("<section><h2>Sumário executivo</h2><p class='lead'>\(esc(execSummaryText(audit, s)))</p></section>")
        add("<section><h2>Panorama de risco</h2><div class='kpis'>")
        add(kpi("\(crit + high)", "riscos relevantes", danger: crit + high > 0))
        add(kpi("\(med)", "pontos de atenção", danger: false))
        add(kpi("\(ok)", "boas práticas confirmadas", danger: false))
        add(kpi("\(s.score)/100", "índice de saúde", danger: s.light == .red))
        add("</div></section>")

        // Pontuação por área
        let db = domainBars(audit)
        if !db.isEmpty { add("<section><h2>Pontuação por área</h2>\(db)</section>") }

        // Matriz de risco (visão de diretoria)
        let risks = RiskRegister.risks(from: audit)
        if !risks.isEmpty {
            add("<section><h2>Matriz de risco</h2>")
            add("<p class='lead'>Distribuição dos riscos por probabilidade × impacto. O registro de risco completo está no relatório dedicado.</p>")
            add(riskMatrix(risks))
            add("</section>")
        }

        // O que está em jogo (impacto de negócio consolidado)
        let stakes = businessStakes(audit, score: s)
        if !stakes.isEmpty {
            add("<section><h2>O que está em jogo</h2><div class='strengths'>")
            for st in stakes { add("<div class='svc'>\(st)</div>") }   // usa .svc (cartão neutro)
            add("</div></section>")
        }

        // Para que serve este servidor (perfil + o que ele hospeda)
        if let p = audit.profile, !p.purposes.isEmpty {
            add("<section><h2>Para que serve este servidor</h2>")
            if let primary = p.primary {
                add("<p class='lead'>Pelos programas e serviços instalados, este servidor está preparado principalmente para: <b>\(esc(primary))</b>.</p>")
            }
            add("<div class='bars'>")
            for pu in p.purposes.sorted(by: { $0.score > $1.score }) where pu.score > 0 {
                add("<div class='barrow'><span class='lbl' style='width:170px'>\(esc(pu.label))</span><span class='track'><span class='fill' style='width:\(max(4, pu.score))%;background:\(readinessColor(pu.score))'></span></span><span class='n'>\(pu.score)%</span></div>")
            }
            add("</div>")
            if let dk = audit.docker, dk.installed, !dk.containers.isEmpty {
                add("<p class='lead' style='margin-top:16px'>Serviços em execução (\(dk.running ?? 0)):</p><div class='strengths'>")
                for c in dk.containers {
                    let desc = containerPurpose(image: c.image) ?? c.image
                    add("<div class='svc'><b>\(esc(c.name))</b> — \(esc(desc))</div>")
                }
                add("</div>")
            }
            add("</section>")
        }

        // Alerta de obsolescência / continuidade
        var alerts: [String] = []
        if let eol = audit.os?.eolDate, eol < todayISO() {
            alerts.append("O sistema operacional está <b>fora de suporte</b> (desde \(esc(eol))): não recebe mais correções de segurança. Isso significa risco crescente de invasão e possível <b>não-conformidade</b> — recomenda-se planejar a atualização/substituição.")
        }
        if let sec = audit.os?.updatesSecurity, sec > 0 {
            alerts.append("Há <b>\(sec) atualização(ões) de segurança</b> pendente(s) — cada uma corrige uma falha já conhecida e publicamente divulgada.")
        }
        for d in audit.disks where d.smartHealthy == false {
            alerts.append("O disco <b>/dev/\(esc(d.name))</b> apresenta sinais de falha (SMART) — risco de <b>perda de dados</b> e parada não planejada. Backup e troca recomendados.")
        }
        if !alerts.isEmpty {
            add("<section><h2>Continuidade do negócio</h2>")
            for a in alerts { add("<div class='alert'>\(a)</div>") }
            add("</section>")
        }

        // Plano de ação priorizado (com esforço: ganho rápido × projeto)
        let actions = audit.findings.filter { $0.severity > .ok }.sorted { $0.severity > $1.severity }
        if !actions.isEmpty {
            let quick = actions.filter { RemediationMap.remediation(for: $0).effort == .quick }.count
            let proj = actions.count - quick
            add("<section><h2>Plano de ação recomendado</h2>")
            add("<p class='lead'><b>\(quick) ganho(s) rápido(s)</b> (ajustes de configuração, minutos cada) e <b>\(proj) projeto(s)</b> (exigem planejamento — dias a semanas). Priorize de cima para baixo — os primeiros itens reduzem mais o risco.</p>")
            var i = 1
            for f in actions {
                let effort = RemediationMap.remediation(for: f).effort
                let etag = effort == .quick
                    ? "<span class='prio' style='background:#30a46c'>Ganho rápido</span>"
                    : "<span class='prio' style='background:#8e44ad'>Projeto</span>"
                add("<div class='action'>")
                add("<div class='anum'>\(i)</div><div class='abody'>")
                add("<div class='atitle'>\(esc(f.title)) <span class='prio' style='background:\(colorHex(f.severity))'>\(esc(businessPriority(f.severity)))</span> \(etag)</div>")
                if let r = f.recommendation, !r.isEmpty { add("<div class='arec'><b>O que fazer:</b> \(esc(r))</div>") }
                if let b = f.businessImpact, !b.isEmpty { add("<div class='awhy'><b>Por que importa:</b> \(esc(b))</div>") }
                add("</div></div>")
                i += 1
            }
            add("</section>")
        }

        // O que já está protegido
        let strengths = audit.findings.filter { $0.severity == .ok }
        if !strengths.isEmpty {
            add("<section><h2>O que já está protegido</h2><div class='strengths'>")
            for f in strengths { add("<div class='strong'>✓ \(esc(f.title))</div>") }
            add("</div></section>")
        }

        // Conformidade e reputação (visão de negócio)
        let cov = ComplianceMap.coverage(audit)
        if !cov.isEmpty {
            add("<section><h2>Conformidade e boas práticas</h2>")
            add("<p class='lead'>Quanto o servidor já atende dos controles reconhecidos pelo mercado (dos que esta auditoria verifica):</p>")
            add(complianceBars(audit))
            let worst = cov.min { $0.percent < $1.percent }
            var reg = "Padrões como <b>ISO/IEC 27001</b> e <b>NIST CSF</b> são referência em contratos e certificações; estar aderente reduz risco e facilita fechar negócios com clientes exigentes."
            if let w = worst, w.percent < 70 {
                reg += " O ponto mais fraco hoje é <b>\(esc(w.framework.rawValue))</b> (\(w.percent)%) — vale priorizar."
            }
            add("<div class='alert' style='background:rgba(58,123,213,.08);border-color:rgba(58,123,213,.3)'>\(reg)</div>")
            if audit.findings.contains(where: { $0.severity > .ok && ($0.category.contains("Contas") || $0.category.contains("SSH") || $0.id.contains("shadow")) }) {
                add("<div class='alert'>⚠️ Há falhas ligadas a <b>controle de acesso e credenciais</b>. Em caso de vazamento de dados pessoais, isso é agravante perante a <b>LGPD</b> (Lei 13.709/2018) — que prevê multas de até 2% do faturamento.</div>")
            }
            add("<p class='lead' style='font-size:13px'>\(esc(complianceDisclaimer))</p>")
            add("</section>")
        }

        add(signatureBlock(signature))
        add(methodologyHTML())
        add("<footer>CONFIDENCIAL · Relatório executivo gerado pelo Uptend · Auditoria Externa · \(esc(humanDate(audit.collectedAt))). Para o detalhamento técnico, consulte o relatório técnico completo.</footer>")

        return execPage(title: "Relatório Executivo — \(audit.host.hostname)", accent: accent, body: body)
    }

    // =========================================================================
    // HTML SOC — relatório de segurança (postura, achados por severidade, CIS, Lynis)
    // Foco operacional de segurança (para o time/SOC), não a diretoria.
    // =========================================================================

    public static func socHTML(_ audit: ExternalAudit, branding: ReportBranding? = nil, signature: ReportSignature? = nil) -> String {
        let s = AuditScoring.evaluate(audit, topN: 100)
        let accent = colorHex(s.light)
        var body = ""
        func add(_ t: String) { body += t + "\n" }

        add(classificationBanner(branding))
        add(brandingCover(branding, reportTitle: "Relatório de Segurança (SOC)"))
        // Cabeçalho + postura
        add("<header class='head'>")
        add("<div><h1>Relatório de Segurança (SOC)</h1>")
        add("<p class='sub'>\(esc(audit.host.hostname)) · \(esc(audit.os?.pretty ?? "—")) · \(esc(String(audit.collectedAt.prefix(10)))) · modo \(esc(audit.collector.mode))</p></div>")
        add(gaugeSVG(score: s.score, color: accent))
        add("</header>")

        add(metaBlock(audit, scope: "Postura de segurança operacional, mapeamento de controles e ameaças (read-only)"))
        add("<section>\(severityLegend())</section>")

        // Pontuação por área
        let dbS = domainBars(audit)
        if !dbS.isEmpty { add("<section><h2>Pontuação por área</h2>\(dbS)</section>") }

        // Postura resumida
        add("<section><h2>Postura de segurança</h2><div class='grid'>")
        add(infoCard("Índice de saúde", "\(s.score)/100", lightLabel(s.light), danger: s.light == .red))
        if let l = audit.lynis, l.available {
            add(infoCard("Endurecimento (Lynis)", l.hardeningIndex.map { "\($0)/100" } ?? "n/d", "", danger: (l.hardeningIndex ?? 100) < 60))
        }
        add(infoCard("Críticos", "\(s.counts[.critical] ?? 0)", "", danger: (s.counts[.critical] ?? 0) > 0))
        add(infoCard("Altos", "\(s.counts[.high] ?? 0)", "", danger: (s.counts[.high] ?? 0) > 0))
        add("</div></section>")

        // Superfície de exposição
        add("<section><h2>Superfície de exposição</h2><div class='grid'>")
        if let u = audit.users {
            add(infoCard("Contas com login", u.loginUsers.map(String.init) ?? "—", ""))
            if !u.sudoUsers.isEmpty { add(infoCard("Acesso privilegiado", "\(u.sudoUsers.count)", u.sudoUsers.joined(separator: ", "))) }
            if !u.emptyPasswordUsers.isEmpty { add(infoCard("Contas sem senha", "\(u.emptyPasswordUsers.count)", u.emptyPasswordUsers.joined(separator: ", "), danger: true)) }
        }
        if let dk = audit.docker, dk.installed { add(infoCard("Containers", "\(dk.running ?? 0)/\(dk.total ?? 0)", "expostos conforme portas")) }
        add("</div></section>")

        // Aderência por framework + funções do NIST CSF (assinatura do SOC)
        let bars = complianceBars(audit)
        if !bars.isEmpty {
            add("<section><h2>Aderência por framework</h2>")
            add("<p class='sub'>\(esc(complianceDisclaimer))</p>")
            add(bars)
            let nist = nistFunctionBars(audit)
            if !nist.isEmpty {
                add("<h2>Cobertura por função (NIST CSF)</h2>")
                add("<p class='sub'>Identificar · Proteger · Detectar · Responder · Recuperar</p>")
                add(nist)
            }
            add("</section>")
        }

        // MITRE ATT&CK — o que um atacante exploraria
        let mitre = mitreTable(audit)
        if !mitre.isEmpty {
            add("<section><h2>Mapeamento MITRE ATT&CK</h2>")
            add("<p class='sub'>Técnicas que os achados abertos habilitam — priorize detecção e resposta.</p>")
            add(mitre)
            add("</section>")
        }

        // Achados por severidade (crítico → baixo; "ok" fora) — com tags de framework
        for sev in [AuditSeverity.critical, .high, .medium, .low] {
            let items = audit.findings.filter { $0.severity == sev }
            guard !items.isEmpty else { continue }
            add("<section><h2>Achados — severidade \(esc(sev.label)) (\(items.count))</h2>")
            for f in items { add(findingCard(f, full: true, frameworks: true)) }
            add("</section>")
        }

        // Mapeamento de controles (achado → CIS / ISO 27001 / NIST CSF / OWASP)
        let map = mappingTable(audit)
        if !map.isEmpty {
            add("<section><h2>Mapeamento de controles</h2>")
            add(map)
            add("</section>")
        }

        // Recomendações de detecção e resposta
        let det = detectionTips(audit)
        if !det.isEmpty {
            add("<section><h2>Detecção e resposta recomendadas</h2><ul>")
            for t in det { add("<li>\(esc(t))</li>") }
            add("</ul></section>")
        }

        // Anexo Lynis
        if let l = audit.lynis, l.available, (!l.warnings.isEmpty || !l.suggestions.isEmpty) {
            add("<section><h2>Lynis — avisos e sugestões</h2>")
            if !l.warnings.isEmpty {
                add("<p><b>Avisos:</b></p><ul>")
                for w in l.warnings { add("<li>\(esc(w))</li>") }
                add("</ul>")
            }
            if !l.suggestions.isEmpty {
                add("<p><b>Sugestões:</b></p><ul>")
                for sug in l.suggestions.prefix(20) { add("<li>\(esc(sug))</li>") }
                add("</ul>")
            }
            add("</section>")
        }

        add(methodologyHTML())
        add(signatureBlock(signature))
        add("<footer>CONFIDENCIAL · Relatório SOC gerado pelo Uptend · Auditoria Externa (schema v\(audit.schemaVersion)) · \(esc(humanDate(audit.collectedAt)))</footer>")
        return page(title: "SOC — \(audit.host.hostname)", accent: accent, body: body)
    }

    // =========================================================================
    // HTML REGISTRO DE RISCO (risk register) — matriz 5×5 + tabela de riscos
    // =========================================================================

    static func riskLevelColor(_ l: RiskLevel) -> String {
        switch l { case .baixo: "#30a46c"; case .medio: "#e2a336"; case .alto: "#e5711a"; case .critico: "#e5484d" }
    }

    /// Matriz de calor 5×5 (impacto × probabilidade) com a contagem de riscos por célula.
    /// A grade toda é colorida pelo nível (verde=baixo → vermelho=crítico); o número mostra
    /// quantos riscos caíram naquela combinação.
    static func riskMatrix(_ risks: [Risk]) -> String {
        let counts = RiskRegister.matrixCounts(risks)
        var html = "<table class='riskmx'><thead><tr><th class='axis'>Impacto ↓ / Prob. →</th>"
        for l in 1...5 { html += "<th class='axis'>\(l)</th>" }
        html += "</tr></thead><tbody>"
        for (rowIdx, imp) in stride(from: 5, through: 1, by: -1).enumerated() {
            html += "<tr><th class='axis'>\(imp)</th>"
            for likelihood in 1...5 {
                let n = counts[rowIdx][likelihood - 1]
                let bg = riskLevelColor(RiskRegister.cellLevel(likelihood: likelihood, impact: imp))
                // grade inteira colorida (empty um pouco mais fraca, mas o degradê aparece)
                html += "<td style='background:\(bg)\(n == 0 ? "9e" : "")'>\(n == 0 ? "" : "<span class='rn'>\(n)</span>")</td>"
            }
            html += "</tr>"
        }
        html += "</tbody></table>"
        // Legenda de níveis
        html += "<div class='rlegend'>"
        for lvl in [RiskLevel.baixo, .medio, .alto, .critico] {
            html += "<span><span class='rsw' style='background:\(riskLevelColor(lvl))'></span>\(esc(lvl.rawValue))</span>"
        }
        html += "</div>"
        return html
    }

    public static func riskRegisterHTML(_ audit: ExternalAudit, branding: ReportBranding? = nil,
                                        signature: ReportSignature? = nil,
                                        accepted: [RiskException] = []) -> String {
        let risks = RiskRegister.risks(from: audit)
        let accent = colorHex(AuditScoring.evaluate(audit).light)
        var body = ""
        func add(_ t: String) { body += t + "\n" }

        add(classificationBanner(branding))
        add(brandingCover(branding, reportTitle: "Registro de Risco (Risk Register)"))
        add("<header class='head'><div><h1>Registro de Risco</h1>")
        add("<p class='sub'>\(esc(audit.host.hostname)) · \(esc(String(audit.collectedAt.prefix(10)))) · \(risks.count) risco(s)</p></div></header>")
        add(metaBlock(audit, scope: "Riscos derivados dos achados (probabilidade × impacto)"))

        add("<section><h2>Matriz de risco (probabilidade × impacto)</h2>")
        add("<p class='sub'>Como ler: cada quadrado é uma combinação de <b>Probabilidade</b> (chance de o problema ser explorado, colunas 1→5) × <b>Impacto</b> (dano se acontecer, linhas 5→1). A <b>cor</b> mostra a gravidade dessa combinação (verde = baixo, vermelho = crítico) e o <b>número</b> é quantos riscos caíram ali. Sem número = nenhum risco naquela faixa.</p>")
        add(riskMatrix(risks))
        add("</section>")

        if !risks.isEmpty {
            add("<section><h2>Riscos priorizados</h2>")
            add("<table><thead><tr><th>ID</th><th>Risco</th><th>Categoria</th><th>Prob.</th><th>Impacto</th><th>Pontuação</th><th>Nível</th><th>Tratamento</th></tr></thead><tbody>")
            for r in risks {
                add("<tr><td>\(esc(r.id))</td><td>\(esc(r.title))</td><td>\(esc(r.category))</td><td>\(r.likelihood)</td><td>\(r.impact)</td><td><b>\(r.score)</b></td><td style='color:\(riskLevelColor(r.level));font-weight:600'>\(esc(r.level.rawValue))</td><td>\(esc(r.treatment))</td></tr>")
            }
            add("</tbody></table></section>")
        } else {
            add("<section><p class='lead'>Nenhum risco aberto — todos os controles verificados estão conformes. 🎉</p></section>")
        }

        if !accepted.isEmpty {
            add("<section><h2>Riscos aceitos (exceções formais)</h2>")
            add("<p class='sub'>Achados com aceitação de risco válida — <b>fora da matriz e da nota</b>, mas registrados para auditoria. Voltam a contar quando a validade expira.</p>")
            add("<table><thead><tr><th>Achado</th><th>Justificativa</th><th>Responsável</th><th>Aceito em</th><th>Válido até</th><th>Referência</th></tr></thead><tbody>")
            for e in accepted {
                add("<tr><td>\(esc(e.title))</td><td>\(esc(e.justification))</td><td>\(esc(e.responsible))</td><td>\(esc(e.acceptedAt))</td><td>\(esc(e.expiresAt))</td><td>\(esc(e.reference))</td></tr>")
            }
            add("</tbody></table></section>")
        }

        add(signatureBlock(signature))
        add("<footer>CONFIDENCIAL · Registro de risco gerado pelo Uptend · \(esc(humanDate(audit.collectedAt)))</footer>")
        return page(title: "Risk Register — \(audit.host.hostname)", accent: accent, body: body)
    }

    // =========================================================================
    // HTML SoA — Declaração de Aplicabilidade (ISO 27001:2022) — FASE B1
    // =========================================================================

    public static func soaHTML(_ audit: ExternalAudit, branding: ReportBranding? = nil,
                               signature: ReportSignature? = nil) -> String {
        let soa = ComplianceCatalog.soaISO27001(audit)
        let sum = ComplianceCatalog.summary(soa)
        let accent = sum.checkedPercent >= 80 ? "#30a46c" : (sum.checkedPercent >= 50 ? "#e2a336" : "#e5484d")
        var body = ""
        func add(_ t: String) { body += t + "\n" }

        add(classificationBanner(branding))
        add(brandingCover(branding, reportTitle: "Declaração de Aplicabilidade (SoA) — ISO/IEC 27001:2022"))
        add("<header class='head'><div><h1>Declaração de Aplicabilidade (SoA)</h1>")
        add("<p class='sub'>ISO/IEC 27001:2022 · Anexo A (\(sum.total) controles) · \(esc(audit.host.hostname)) · \(esc(String(audit.collectedAt.prefix(10))))</p></div></header>")
        add(metaBlock(audit, scope: "Cobertura de todos os controles do Anexo A (gap assessment)"))

        // Resumo por status
        add("<section><h2>Resumo</h2>")
        add("<p class='sub'>Conformidade sobre o que a auditoria verificou: <b>\(sum.checkedPercent)%</b> · Sobre todo o escopo automatizável: <b>\(sum.automatedPercent)%</b>. Os controles <b>Manuais</b> exigem processo/política e devem ser avaliados fora da coleta automática.</p>")
        add("<div class='soabar'>")
        for st in SoAStatus.allCases {
            let n = sum.counts[st] ?? 0
            add("<span class='soachip'><span class='sw' style='background:\(st.colorHex)'></span>\(esc(st.rawValue)): <b>\(n)</b></span>")
        }
        add("</div></section>")

        // Tabela completa por tema
        var themeOrder: [String] = []
        for c in soa where !themeOrder.contains(c.entry.theme) { themeOrder.append(c.entry.theme) }
        for theme in themeOrder {
            let rows = soa.filter { $0.entry.theme == theme }
            add("<section><h2>\(esc(theme)) (\(rows.count))</h2>")
            add("<table><thead><tr><th>Controle</th><th>Título</th><th>Natureza</th><th>Status</th><th>Achados</th></tr></thead><tbody>")
            for c in rows {
                let nat = c.entry.nature == .manual ? "Manual" : "Automatizável"
                let ach = c.findingIds.isEmpty ? "—" : c.findingIds.joined(separator: ", ")
                add("<tr><td><code>\(esc(c.entry.id))</code></td><td>\(esc(c.entry.title))</td><td>\(esc(nat))</td><td><span class='soast' style='background:\(c.status.colorHex)'>\(esc(c.status.rawValue))</span></td><td class='mut'>\(esc(ach))</td></tr>")
            }
            add("</tbody></table></section>")
        }

        add("<section class='note'><p><b>Como ler:</b> <b>Coberto</b> = a auditoria verifica e está conforme. <b>Não conforme</b> = a auditoria verifica e há achado aberto (gap a tratar). <b>Não avaliado</b> = controle técnico que a ferramenta poderia checar, mas esta coleta não cobriu. <b>Manual</b> = exige processo, política ou evidência organizacional — fora do alcance da coleta automática do host. Este SoA é um ponto de partida técnico; a aplicabilidade final e as justificativas são decisão do responsável pelo SGSI.</p></section>")

        add(signatureBlock(signature))
        add("<footer>CONFIDENCIAL · SoA ISO 27001:2022 gerado pelo Uptend · \(esc(humanDate(audit.collectedAt)))</footer>")
        return page(title: "SoA ISO 27001 — \(audit.host.hostname)", accent: accent, body: body)
    }

    // =========================================================================
    // HTML BASELINE — conformidade ao padrão definido (policy-as-code) — FASE B4
    // =========================================================================

    public static func baselineHTML(_ audit: ExternalAudit, baseline: Baseline,
                                    branding: ReportBranding? = nil, signature: ReportSignature? = nil) -> String {
        let results = BaselineEngine.assess(audit, against: baseline)
        let sum = BaselineEngine.summary(results)
        let accent = sum.passed ? "#30a46c" : "#e5484d"
        var body = ""
        func add(_ t: String) { body += t + "\n" }

        add(classificationBanner(branding))
        add(brandingCover(branding, reportTitle: "Conformidade ao Baseline — \(baseline.name)"))
        add("<header class='head'><div><h1>Conformidade ao Baseline</h1>")
        add("<p class='sub'>\(esc(baseline.name)) v\(esc(baseline.version)) · \(esc(audit.host.hostname)) · \(esc(String(audit.collectedAt.prefix(10))))</p></div></header>")
        add(metaBlock(audit, scope: "Desvio da máquina em relação ao baseline definido (\(baseline.items.count) controles)"))

        // Veredito
        let verdict = sum.passed
            ? "<b style='color:#30a46c'>APROVADO</b> — nenhum desvio em controle obrigatório."
            : "<b style='color:#e5484d'>REPROVADO</b> — \(sum.mandatoryDesvio) desvio(s) em controle(s) obrigatório(s)."
        add("<section><h2>Resultado</h2>")
        add("<p class='lead'>\(verdict)</p>")
        add("<p class='sub'>Conformidade sobre o avaliado: <b>\(sum.percent)%</b> · Conforme: <b>\(sum.conforme)</b> · Desvio: <b>\(sum.desvio)</b> · Não avaliado: <b>\(sum.naoAvaliado)</b> de \(sum.total) controles.</p>")
        add("<div class='soabar'>")
        for st in BaselineStatus.allCases {
            let n = results.filter { $0.status == st }.count
            add("<span class='soachip'><span class='sw' style='background:\(st.colorHex)'></span>\(esc(st.rawValue)): <b>\(n)</b></span>")
        }
        add("</div></section>")

        // Tabela completa
        add("<section><h2>Controles do baseline</h2>")
        add("<table><thead><tr><th>Controle</th><th>Obrigatório</th><th>Status</th><th>Severidade</th><th>Achado</th></tr></thead><tbody>")
        for r in results {
            let sev = r.severity.map { $0.label } ?? "—"
            let ach = r.findingId ?? "—"
            add("<tr><td>\(esc(r.item.title))<br><code class='mut'>\(esc(r.item.key))</code></td><td>\(r.item.mandatory ? "Sim" : "Não")</td><td><span class='soast' style='background:\(r.status.colorHex)'>\(esc(r.status.rawValue))</span></td><td>\(esc(sev))</td><td class='mut'>\(esc(ach))</td></tr>")
        }
        add("</tbody></table></section>")

        add("<section class='note'><p><b>Como ler:</b> <b>Conforme</b> = o controle foi verificado e atende ao padrão. <b>Desvio</b> = verificado e fora do padrão (não conformidade). <b>Não avaliado</b> = o baseline exige o controle, mas esta coleta não o mediu nesta máquina (lacuna de cobertura a investigar). Um desvio em item <b>obrigatório</b> reprova a máquina no baseline.</p></section>")

        add(signatureBlock(signature))
        add("<footer>CONFIDENCIAL · Conformidade ao baseline gerada pelo Uptend · \(esc(humanDate(audit.collectedAt)))</footer>")
        return page(title: "Baseline — \(audit.host.hostname)", accent: accent, body: body)
    }

    // =========================================================================
    // HTML LGPD — lente de conformidade (segurança da LGPD) — FASE E4
    // =========================================================================

    public static func lgpdHTML(_ audit: ExternalAudit, branding: ReportBranding? = nil, signature: ReportSignature? = nil) -> String {
        let items = LGPDLens.items(audit)
        let sum = LGPDLens.summary(items)
        let accent = sum.critical > 0 ? "#e5484d" : (sum.high > 0 ? "#e5711a" : (items.isEmpty ? "#30a46c" : "#e2a336"))
        var body = ""
        func add(_ t: String) { body += t + "\n" }

        add(classificationBanner(branding))
        add(brandingCover(branding, reportTitle: "Relatório LGPD — Segurança de Dados Pessoais"))
        add("<header class='head'><div><h1>Relatório LGPD (segurança)</h1>")
        add("<p class='sub'>\(esc(audit.host.hostname)) · \(esc(String(audit.collectedAt.prefix(10)))) · \(items.count) ponto(s) de atenção</p></div></header>")
        add(metaBlock(audit, scope: "Mapeamento dos achados às obrigações de SEGURANÇA da LGPD"))

        add("<section class='warn'><p><b>⚠️ Escopo:</b> esta é uma <b>avaliação técnica</b> que mapeia os achados às obrigações de <b>segurança</b> da LGPD (art. 46, 6º-VII e 37) — <b>não é parecer jurídico</b>. Conformidade plena à LGPD envolve também base legal, finalidade, DPO, RIPD, direitos do titular e governança, fora do escopo desta ferramenta.</p></section>")

        if items.isEmpty {
            add("<section><p class='lead'>Nenhum ponto de atenção de segurança relevante à LGPD nos achados abertos. 🎉</p></section>")
        } else {
            add("<section><h2>Resumo</h2><p class='sub'>Total: <b>\(sum.total)</b> · Críticos: <b>\(sum.critical)</b> · Altos: <b>\(sum.high)</b>.</p></section>")
            // Agrupa por artigo
            var order: [String] = []
            for it in items where !order.contains(it.article.code) { order.append(it.article.code) }
            for code in order {
                let group = items.filter { $0.article.code == code }
                let tema = group.first?.article.theme ?? ""
                add("<section><h2>\(esc(code)) — \(esc(tema)) (\(group.count))</h2>")
                add("<table><thead><tr><th>Severidade</th><th>Achado</th><th>Recomendação</th></tr></thead><tbody>")
                for it in group {
                    let rec = it.finding.recommendation ?? "—"
                    add("<tr><td><span class='soast' style='background:\(riskColorForSeverity(it.finding.severity))'>\(esc(it.finding.severity.label))</span></td><td>\(esc(it.finding.title))</td><td class='mut'>\(esc(rec))</td></tr>")
                }
                add("</tbody></table></section>")
            }
        }

        add(signatureBlock(signature))
        add("<footer>CONFIDENCIAL · Relatório LGPD (segurança) gerado pelo Uptend · \(esc(humanDate(audit.collectedAt)))</footer>")
        return page(title: "LGPD — \(audit.host.hostname)", accent: accent, body: body)
    }

    // =========================================================================
    // HTML DETECÇÃO — regras Sigma/Falco (controles compensatórios) — FASE C2
    // =========================================================================

    public static func detectionRulesHTML(_ audit: ExternalAudit, branding: ReportBranding? = nil, signature: ReportSignature? = nil) -> String {
        let rules = DetectionRules.rules(for: audit)
        let accent = rules.isEmpty ? "#30a46c" : "#4a90d9"
        var body = ""
        func add(_ t: String) { body += t + "\n" }

        add(classificationBanner(branding))
        add(brandingCover(branding, reportTitle: "Regras de Detecção (Sigma / Falco)"))
        add("<header class='head'><div><h1>Regras de Detecção</h1>")
        add("<p class='sub'>\(esc(audit.host.hostname)) · \(esc(String(audit.collectedAt.prefix(10)))) · \(rules.count) regra(s) compensatória(s)</p></div></header>")
        add(metaBlock(audit, scope: "Detecções compensatórias derivadas das lacunas encontradas"))

        add("<section class='note'><p><b>Como usar:</b> estas regras <b>não substituem a correção</b> — servem para <b>detectar</b> o ataque enquanto a lacuna não é fechada. Carregue as regras <b>Sigma</b> no seu SIEM (via conversor sigma-cli) e as <b>Falco</b> no runtime do host/containers. Cada regra referencia a técnica <b>MITRE ATT&CK</b> correspondente.</p></section>")

        if rules.isEmpty {
            add("<section><p class='lead'>Sem lacunas que peçam detecção compensatória — a postura já cobre esses vetores. 🎉</p></section>")
        } else {
            for r in rules {
                add("<section><h2>[\(esc(r.format.uppercased())) · \(esc(r.mitre))] \(esc(r.title))</h2>")
                add("<p class='sub'>\(esc(r.reason))</p>")
                add("<pre class='rawev'>\(esc(r.yaml))</pre></section>")
            }
        }

        add(signatureBlock(signature))
        add("<footer>CONFIDENCIAL · Regras de detecção geradas pelo Uptend · \(esc(humanDate(audit.collectedAt)))</footer>")
        return page(title: "Detecção — \(audit.host.hostname)", accent: accent, body: body)
    }

    // =========================================================================
    // HTML PLAYBOOK — script de hardening (backup/rollback) — FASE D2
    // =========================================================================

    public static func playbookHTML(_ audit: ExternalAudit, branding: ReportBranding? = nil, signature: ReportSignature? = nil) -> String {
        let script = HardeningPlaybook.generate(for: audit)
        let auto = HardeningPlaybook.autoCount(for: audit)
        var body = ""
        func add(_ t: String) { body += t + "\n" }

        add(classificationBanner(branding))
        add(brandingCover(branding, reportTitle: "Playbook de Hardening (correção)"))
        add("<header class='head'><div><h1>Playbook de Hardening</h1>")
        add("<p class='sub'>\(esc(audit.host.hostname)) · \(esc(String(audit.collectedAt.prefix(10)))) · \(auto) correção(ões) automática(s)</p></div></header>")
        add(metaBlock(audit, scope: "Script de correção gerado dos achados — para revisão e execução manual"))

        add("<section class='warn'><p><b>⚠️ Antes de rodar:</b> <b>revise</b> o script. Rode em <b>janela de manutenção</b> e com <b>acesso alternativo</b> ao servidor (o hardening de SSH pode derrubar sua sessão). Ele faz <b>backup</b> das configs antes e traz modo <code>rollback</code> para desfazer. O Uptend <b>nunca executa</b> este script — você aplica quando revisar.</p></section>")

        add("<section><h2>Como usar</h2><p class='sub'>Salve como <code>playbook.sh</code> e no servidor rode:</p>")
        add("<pre class='rawev'>sudo bash playbook.sh            # aplica (faz backup antes)\nsudo bash playbook.sh rollback   # desfaz (restaura o backup)</pre></section>")

        add("<section><h2>Script</h2><pre class='rawev'>\(esc(script))</pre></section>")

        add(signatureBlock(signature))
        add("<footer>CONFIDENCIAL · Playbook gerado pelo Uptend · \(esc(humanDate(audit.collectedAt)))</footer>")
        return page(title: "Playbook — \(audit.host.hostname)", accent: "#4a90d9", body: body)
    }

    // =========================================================================
    // HTML SUPERFÍCIE DE ATAQUE — o que está exposto e onde (diagrama) — FASE D3
    // =========================================================================

    public static func attackSurfaceHTML(_ audit: ExternalAudit, branding: ReportBranding? = nil, signature: ReportSignature? = nil) -> String {
        let surf = AttackSurfaceMap.from(audit)
        let accent = surf.redCount > 0 ? "#e5484d" : (surf.entries.count > 1 ? "#e2a336" : "#30a46c")
        var body = ""
        func add(_ t: String) { body += t + "\n" }

        add(classificationBanner(branding))
        add(brandingCover(branding, reportTitle: "Mapa de Superfície de Ataque"))
        add("<header class='head'><div><h1>Superfície de Ataque</h1>")
        add("<p class='sub'>\(esc(audit.host.hostname)) · \(esc(String(audit.collectedAt.prefix(10)))) · \(surf.entries.count) porta(s) exposta(s)</p></div></header>")
        add(metaBlock(audit, scope: "O que está acessível pela rede, com o risco de cada exposição"))

        add("<section class='note'><p><b>O que é isto:</b> o conjunto de portas/serviços que respondem pela rede — a <b>porta de entrada</b> de um atacante. Quanto menor a superfície, menor o risco. Feche no firewall tudo que não precisa estar público; o que precisar, restrinja por IP de origem.</p></section>")

        // Diagrama
        add("<section><h2>Diagrama de exposição</h2>")
        add("<div style='text-align:center;margin:14px 0'>\(AttackSurfaceMap.svg(surf))</div>")
        add("<p class='rlegend' style='justify-content:center'>")
        add("<span class='rsw' style='background:#e5484d'></span> Alto — não deveria estar público&nbsp;&nbsp;")
        add("<span class='rsw' style='background:#e2a336'></span> Médio — restrinja o acesso&nbsp;&nbsp;")
        add("<span class='rsw' style='background:#30a46c'></span> Ok — protegido (TLS)</p></section>")

        // Tabela
        if surf.entries.isEmpty {
            add("<section><p class='lead'>Nenhuma porta exposta detectada além do SSH. 🎉</p></section>")
        } else {
            add("<section><h2>Portas expostas</h2><table><thead><tr><th>Porta</th><th>Serviço</th><th>TLS</th><th>Avaliação</th></tr></thead><tbody>")
            for e in surf.entries {
                let col = AttackSurfaceMap.color(e.risk)
                let sev = e.risk == .red ? "Alto" : (e.risk == .yellow ? "Médio" : "Ok")
                add("<tr><td><b>\(e.port)</b></td><td>\(esc(e.service))</td><td>\(esc(e.tls ?? "—"))</td>"
                    + "<td><span style='color:\(col);font-weight:700'>\(sev)</span> — \(esc(AttackSurfaceMap.riskLabel(e.risk)))</td></tr>")
            }
            add("</tbody></table></section>")
        }

        if !surf.containers.isEmpty {
            add("<section><h2>Contêineres em execução (\(surf.containers.count))</h2>")
            add("<p class='sub'>Cada contêiner que publica portas amplia a superfície — confira os mapeamentos <code>-p</code>.</p><ul>")
            for img in surf.containers.prefix(40) { add("<li>\(esc(img))</li>") }
            add("</ul></section>")
        }

        add(signatureBlock(signature))
        add("<footer>CONFIDENCIAL · Superfície de ataque gerada pelo Uptend · \(esc(humanDate(audit.collectedAt)))</footer>")
        return page(title: "Superfície de Ataque — \(audit.host.hostname)", accent: accent, body: body)
    }

    // =========================================================================
    // HTML CVE — vulnerabilidades conhecidas por versão (enriquecimento) — FASE C1
    // =========================================================================

    public static func cveHTML(_ audit: ExternalAudit, branding: ReportBranding? = nil, signature: ReportSignature? = nil) -> String {
        let software = CVEMatcher.allSoftware(audit)
        let matches = CVEMatcher.matches(software)
        let crit = matches.filter { $0.cve.severity == .critical }.count
        let high = matches.filter { $0.cve.severity == .high }.count
        let accent = crit > 0 ? "#e5484d" : (high > 0 ? "#e5711a" : (matches.isEmpty ? "#30a46c" : "#e2a336"))
        var body = ""
        func add(_ t: String) { body += t + "\n" }

        add(classificationBanner(branding))
        add(brandingCover(branding, reportTitle: "Vulnerabilidades Conhecidas (CVE)"))
        add("<header class='head'><div><h1>Vulnerabilidades Conhecidas (CVE)</h1>")
        add("<p class='sub'>\(esc(audit.host.hostname)) · \(esc(String(audit.collectedAt.prefix(10)))) · \(matches.count) exposição(ões) potencial(is) em \(software.count) componente(s) analisado(s)</p></div></header>")
        add(metaBlock(audit, scope: "Cruzamento das versões colhidas com uma base curada de CVEs críticas"))

        // Aviso de método (honestidade)
        add("<section class='warn'><p><b>⚠️ Leia antes:</b> estes itens indicam <b>exposição potencial</b> com base na <b>versão upstream</b> do software. Distribuições Linux frequentemente aplicam <b>backport</b> da correção <b>sem mudar o número da versão</b> — então um item aqui <b>pode já estar corrigido</b>. Trate como pista para <b>verificar o patch da distro</b> (ex.: changelog do pacote), não como vulnerabilidade confirmada. Esta é uma base <b>curada de CVEs de alto impacto</b>, não um espelho completo do NVD.</p></section>")

        if matches.isEmpty {
            add("<section><p class='lead'>Nenhuma versão vulnerável conhecida encontrada na base curada. 🎉</p>")
            add("<p class='sub'>Isso não garante ausência de vulnerabilidades — só que nada da base curada bateu com as versões colhidas.</p></section>")
        } else {
            add("<section><h2>Resumo</h2><p class='sub'>Críticas: <b>\(crit)</b> · Altas: <b>\(high)</b> · Total: <b>\(matches.count)</b>.</p></section>")
            add("<section><h2>Exposições potenciais</h2>")
            add("<table><thead><tr><th>CVE</th><th>Componente</th><th>Versão</th><th>Origem</th><th>CVSS</th><th>Severidade</th><th>Descrição / verificação</th></tr></thead><tbody>")
            for m in matches {
                add("<tr><td><code>\(esc(m.cve.id))</code></td><td>\(esc(m.software.name))</td><td>\(esc(m.software.version))</td><td class='mut'>\(esc(m.software.source ?? "host"))</td><td><b>\(String(format: "%.1f", m.cve.cvss))</b></td><td><span class='soast' style='background:\(riskColorForSeverity(m.cve.severity))'>\(esc(m.cve.severity.label))</span></td><td>\(esc(m.cve.title))<br><span class='mut'>\(esc(m.cve.reference))</span></td></tr>")
            }
            add("</tbody></table></section>")
        }

        // Inventário do que foi analisado
        if !software.isEmpty {
            add("<section><h2>Componentes analisados</h2><table><thead><tr><th>Componente</th><th>Versão</th><th>Origem</th></tr></thead><tbody>")
            for s in software.sorted(by: { $0.name < $1.name }) {
                add("<tr><td>\(esc(s.name))</td><td>\(esc(s.version))</td><td class='mut'>\(esc(s.source ?? "host"))</td></tr>")
            }
            add("</tbody></table></section>")
        }

        add(signatureBlock(signature))
        add("<footer>CONFIDENCIAL · Enriquecimento de CVE gerado pelo Uptend · \(esc(humanDate(audit.collectedAt)))</footer>")
        return page(title: "CVE — \(audit.host.hostname)", accent: accent, body: body)
    }

    /// Cor por severidade (reaproveita a paleta dos níveis).
    static func riskColorForSeverity(_ s: AuditSeverity) -> String {
        switch s { case .critical: "#e5484d"; case .high: "#e5711a"; case .medium: "#e2a336"; case .low: "#4a90d9"; case .ok: "#30a46c" }
    }

    // =========================================================================
    // HTML FROTA — roll-up multi-host consolidado — FASE D1
    // =========================================================================

    static func scoreColor(_ score: Int) -> String {
        score >= 80 ? "#30a46c" : (score >= 50 ? "#e2a336" : "#e5484d")
    }

    public static func fleetHTML(_ fleet: Fleet, branding: ReportBranding? = nil, signature: ReportSignature? = nil) -> String {
        let accent = scoreColor(fleet.avgScore)
        let asOf = fleet.hosts.map(\.collectedAt).max() ?? ""
        var body = ""
        func add(_ t: String) { body += t + "\n" }

        add(classificationBanner(branding))
        add(brandingCover(branding, reportTitle: "Relatório de Frota (Multi-host)"))
        add("<header class='head'><div><h1>Relatório de Frota</h1>")
        add("<p class='sub'>\(fleet.hostCount) host(s) · nota média <b>\(fleet.avgScore)</b> · atualizado \(esc(String(asOf.prefix(10))))</p></div></header>")

        // Resumo por semáforo
        add("<section><h2>Panorama</h2><div class='soabar'>")
        add("<span class='soachip'><span class='sw' style='background:#e5484d'></span>Crítico (nota&lt;50): <b>\(fleet.redCount)</b></span>")
        add("<span class='soachip'><span class='sw' style='background:#e2a336'></span>Atenção (50–79): <b>\(fleet.yellowCount)</b></span>")
        add("<span class='soachip'><span class='sw' style='background:#30a46c'></span>Bom (≥80): <b>\(fleet.greenCount)</b></span>")
        add("</div></section>")

        // Heatmap host × área
        if !fleet.domains.isEmpty {
            add("<section><h2>Mapa de conformidade (host × área)</h2>")
            add("<p class='sub'>Cada célula é a nota da área naquele host: verde ≥80, amarelo 50–79, vermelho &lt;50.</p>")
            add("<table class='heat'><thead><tr><th>Host</th><th>Nota</th>")
            for d in fleet.domains { add("<th class='rot'>\(esc(d))</th>") }
            add("</tr></thead><tbody>")
            for h in fleet.hosts {
                add("<tr><td class='hn'>\(esc(h.hostname))</td><td style='background:\(scoreColor(h.score));color:#fff;text-align:center;font-weight:700'>\(h.score)</td>")
                for d in fleet.domains {
                    if let sc = h.domainScores[d] {
                        add("<td style='background:\(scoreColor(sc));color:#fff;text-align:center'>\(sc)</td>")
                    } else {
                        add("<td class='na'>—</td>")
                    }
                }
                add("</tr>")
            }
            add("</tbody></table></section>")
        }

        // Tabela de hosts (piores primeiro)
        add("<section><h2>Hosts (do mais fraco ao mais forte)</h2>")
        add("<table><thead><tr><th>Host</th><th>SO</th><th>Coletado</th><th>Nota</th><th>Críticos</th><th>Altos</th><th>Abertos</th></tr></thead><tbody>")
        for h in fleet.hosts {
            add("<tr><td>\(esc(h.hostname))</td><td class='mut'>\(esc(h.os))</td><td class='mut'>\(esc(String(h.collectedAt.prefix(10))))</td><td style='color:\(scoreColor(h.score));font-weight:700'>\(h.score)</td><td>\(h.criticalCount)</td><td>\(h.highCount)</td><td>\(h.openCount)</td></tr>")
        }
        add("</tbody></table></section>")

        // Achados mais comuns na frota
        if !fleet.topFindings.isEmpty {
            add("<section><h2>Achados mais comuns na frota</h2>")
            add("<table><thead><tr><th>Achado</th><th>Severidade</th><th>Hosts afetados</th></tr></thead><tbody>")
            for f in fleet.topFindings.prefix(20) {
                add("<tr><td>\(esc(f.title))</td><td><span class='soast' style='background:\(riskColorForSeverity(f.severity))'>\(esc(f.severity.label))</span></td><td><b>\(f.hostCount)</b> de \(fleet.hostCount)</td></tr>")
            }
            add("</tbody></table></section>")
        }

        add(signatureBlock(signature))
        add("<footer>CONFIDENCIAL · Relatório de frota gerado pelo Uptend · \(esc(humanDate(asOf)))</footer>")
        return page(title: "Frota — \(fleet.hostCount) hosts", accent: accent, body: body)
    }

    // =========================================================================
    // HTML COMPARAÇÃO — evolução entre duas auditorias
    // =========================================================================

    public static func comparisonHTML(previous: ExternalAudit, current: ExternalAudit,
                                      branding: ReportBranding? = nil, signature: ReportSignature? = nil) -> String {
        let c = AuditCompare.compare(previous: previous, current: current)
        let accent = c.scoreDelta > 0 ? "#30a46c" : (c.scoreDelta < 0 ? "#e5484d" : "#8a8a8f")
        var body = ""
        func add(_ t: String) { body += t + "\n" }

        add(classificationBanner(branding))
        add(brandingCover(branding, reportTitle: "Evolução da Auditoria"))
        add("<header class='head'><div><h1>Evolução da Auditoria</h1>")
        add("<p class='sub'>\(esc(c.host)) · \(esc(humanDate(c.prevDate))) → \(esc(humanDate(c.curDate)))</p></div></header>")

        // Delta de nota
        let arrow = c.scoreDelta > 0 ? "▲" : (c.scoreDelta < 0 ? "▼" : "=")
        add("<section><h2>Nota geral</h2><div class='kpis' style='grid-template-columns:repeat(3,1fr)'>")
        add("<div class='card'><div class='v'>\(c.prevScore)</div><div class='k'>antes</div></div>")
        add("<div class='card'><div class='v' style='color:\(accent)'>\(c.curScore)</div><div class='k'>agora</div></div>")
        add("<div class='card'><div class='v' style='color:\(accent)'>\(arrow) \(abs(c.scoreDelta))</div><div class='k'>variação</div></div>")
        add("</div></section>")

        // Resumo
        add("<section><h2>Resumo</h2><div class='bars'>")
        add("<div class='barrow'><span class='lbl' style='width:200px'>Resolvidos</span><span class='n' style='color:#30a46c'>\(c.resolved.count)</span></div>")
        add("<div class='barrow'><span class='lbl' style='width:200px'>Novos problemas</span><span class='n' style='color:#e5484d'>\(c.newIssues.count)</span></div>")
        add("<div class='barrow'><span class='lbl' style='width:200px'>Persistentes</span><span class='n' style='color:#e2a336'>\(c.persistent.count)</span></div>")
        add("</div></section>")

        // Variação por área
        if !c.domainDeltas.isEmpty {
            add("<section><h2>Variação por área</h2><table><thead><tr><th>Área</th><th>Antes</th><th>Agora</th><th>Variação</th></tr></thead><tbody>")
            for d in c.domainDeltas {
                let col = d.delta > 0 ? "#30a46c" : (d.delta < 0 ? "#e5484d" : "var(--muted)")
                let sgn = d.delta > 0 ? "+" : ""
                add("<tr><td>\(esc(d.name))</td><td>\(d.prev)</td><td>\(d.cur)</td><td style='color:\(col);font-weight:600'>\(sgn)\(d.delta)</td></tr>")
            }
            add("</tbody></table></section>")
        }

        if !c.resolved.isEmpty {
            add("<section><h2>✓ Resolvidos (\(c.resolved.count))</h2><div class='strengths'>")
            for f in c.resolved { add("<div class='strong'>✓ \(esc(f.title))</div>") }
            add("</div></section>")
        }
        if !c.newIssues.isEmpty {
            add("<section><h2>⚠ Novos problemas (\(c.newIssues.count))</h2>")
            for f in c.newIssues { add(findingCard(f, full: true, frameworks: true)) }
            add("</section>")
        }
        if !c.persistent.isEmpty {
            add("<section><h2>Persistentes (\(c.persistent.count))</h2>")
            for f in c.persistent { add(findingCard(f, full: false, frameworks: true)) }
            add("</section>")
        }

        add(signatureBlock(signature))
        add("<footer>CONFIDENCIAL · Comparação gerada pelo Uptend · Auditoria Externa · \(esc(humanDate(c.curDate)))</footer>")
        return page(title: "Evolução — \(c.host)", accent: accent, body: body)
    }

    // MARK: Peças HTML

    private static func page(title: String, accent: String, body: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="pt-BR"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(esc(title))</title>
        <style>
        :root { --bg:#ffffff; --fg:#1d1d1f; --muted:#6b6b70; --card:#f5f5f7; --border:#e2e2e6; --accent:\(accent); }
        @media (prefers-color-scheme: dark) { :root { --bg:#1c1c1e; --fg:#f2f2f7; --muted:#98989f; --card:#2c2c2e; --border:#3a3a3c; } }
        * { box-sizing: border-box; }
        body { margin:0; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif; background:var(--bg); color:var(--fg); line-height:1.5; }
        .wrap { max-width:1080px; margin:0 auto; padding:32px 30px; }
        .head { display:flex; align-items:center; justify-content:space-between; gap:24px; border-bottom:1px solid var(--border); padding-bottom:20px; margin-bottom:8px; }
        h1 { font-size:26px; margin:0; }
        h2 { font-size:17px; margin:28px 0 12px; }
        .sub { color:var(--muted); margin:6px 0 0; font-size:14px; }
        section { margin-top:8px; }
        .grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(200px,1fr)); gap:10px; }
        .card { background:var(--card); border:1px solid var(--border); border-radius:10px; padding:12px 14px; }
        .card .k { color:var(--muted); font-size:12px; }
        .card .v { font-size:16px; font-weight:600; margin-top:3px; }
        .card .d { font-size:12px; color:var(--muted); margin-top:2px; }
        .card .d.danger { color:#e5484d; font-weight:600; }
        .cats { display:grid; grid-template-columns:repeat(auto-fill,minmax(200px,1fr)); gap:8px; }
        .cat { display:flex; align-items:center; gap:8px; background:var(--card); border:1px solid var(--border); border-radius:8px; padding:8px 12px; font-size:14px; }
        .cat .muted { margin-left:auto; color:var(--muted); font-size:12px; }
        .dot { width:10px; height:10px; border-radius:50%; display:inline-block; flex:0 0 auto; }
        .finding { background:var(--card); border:1px solid var(--border); border-left:4px solid var(--fbar); border-radius:8px; padding:12px 14px; margin-bottom:8px; }
        .finding .ft { font-weight:600; }
        .finding .fe { color:var(--muted); font-size:13px; margin-top:3px; }
        .finding .fi { color:#c56a1a; font-size:13px; margin-top:4px; }
        .finding .fr { color:var(--muted); font-size:13px; margin-top:4px; }
        .finding .cmd { margin:8px 0 0; padding:9px 11px; background:#11131a; color:#d6e2ff; border-radius:7px; font-family:ui-monospace,SFMono-Regular,Menlo,monospace; font-size:12px; overflow-x:auto; white-space:pre-wrap; word-break:break-word; }
        .finding .ev { margin-top:8px; }
        .finding .ev summary { cursor:pointer; font-size:12px; color:var(--muted); }
        .finding .rawev { margin:6px 0 0; padding:9px 11px; background:#1a1c22; color:#c9d1d9; border:1px solid var(--border); border-radius:7px; font-family:ui-monospace,SFMono-Regular,Menlo,monospace; font-size:11.5px; overflow-x:auto; white-space:pre-wrap; word-break:break-word; max-height:280px; }
        .chips { margin-top:5px; display:flex; flex-wrap:wrap; gap:5px; }
        .fw { font-size:11px; padding:1px 7px; border-radius:20px; white-space:nowrap; }
        .fw.cis { background:rgba(10,90,200,.14); color:#3a7bd5; }
        .fw.iso { background:rgba(48,164,108,.14); color:#2b8a5e; }
        .fw.nist { background:rgba(155,89,182,.16); color:#8e44ad; }
        .fw.owasp { background:rgba(229,113,26,.16); color:#c56a1a; }
        .fw.pci { background:rgba(52,152,219,.16); color:#2471a3; }
        .barrow .muted { color:var(--muted); font-size:12px; width:44px; text-align:right; }
        .sev { font-size:12px; font-weight:600; float:right; }
        table { width:100%; border-collapse:collapse; font-size:13px; }
        th,td { text-align:left; padding:7px 10px; border-bottom:1px solid var(--border); }
        th { color:var(--muted); font-weight:600; }
        .bars { display:flex; flex-direction:column; gap:6px; }
        .barrow { display:flex; align-items:center; gap:10px; font-size:13px; }
        .barrow .lbl { width:70px; color:var(--muted); }
        .barrow .track { flex:1; background:var(--border); border-radius:6px; height:14px; overflow:hidden; }
        .barrow .fill { display:block; height:100%; border-radius:6px; }
        .barrow .n { width:28px; text-align:right; font-variant-numeric:tabular-nums; }
        footer { margin-top:32px; padding-top:16px; border-top:1px solid var(--border); color:var(--muted); font-size:12px; }
        .classif { background:#e5484d; color:#fff; font-size:12px; font-weight:700; letter-spacing:.3px; padding:6px 12px; border-radius:6px; text-align:center; margin-bottom:16px; }
        .meta { display:grid; grid-template-columns:repeat(auto-fit,minmax(240px,1fr)); gap:6px 20px; background:var(--card); border:1px solid var(--border); border-radius:10px; padding:14px 16px; margin-top:6px; }
        .meta > div { display:flex; justify-content:space-between; gap:12px; font-size:13px; border-bottom:1px dotted var(--border); padding:3px 0; }
        .meta .mk { color:var(--muted); }
        .meta .mv { font-weight:600; text-align:right; }
        .legend { display:flex; flex-wrap:wrap; gap:14px; font-size:12px; color:var(--muted); margin-top:6px; }
        .legend span { display:inline-flex; align-items:center; gap:5px; }
        .cover { display:flex; align-items:center; justify-content:space-between; gap:20px; border:1px solid var(--border); border-radius:12px; padding:18px 20px; margin-bottom:14px; background:var(--card); }
        .cover .bco { font-size:18px; font-weight:700; }
        .cover .brt { font-size:15px; color:var(--muted); margin-top:2px; }
        .cover .bmeta { font-size:13px; margin-top:8px; }
        .cover .blogo { max-height:64px; max-width:200px; object-fit:contain; }
        .riskmx { border-collapse:separate; border-spacing:3px; margin-top:10px; }
        .riskmx td { width:52px; height:40px; text-align:center; border-radius:6px; font-size:13px; }
        .riskmx td .rn { display:inline-block; min-width:22px; padding:1px 5px; border-radius:11px; background:rgba(0,0,0,.42); color:#fff; font-weight:700; font-size:13px; }
        .riskmx th.axis { background:transparent; color:var(--muted); font-weight:600; font-size:12px; padding:0 6px; }
        .rlegend { display:flex; gap:16px; flex-wrap:wrap; margin:10px 0 2px; color:var(--muted); font-size:12.5px; align-items:center; }
        .rlegend span { display:inline-flex; align-items:center; gap:6px; }
        .rlegend .rsw { width:14px; height:14px; border-radius:4px; display:inline-block; }
        .soabar { display:flex; gap:10px 18px; flex-wrap:wrap; margin:6px 0 2px; }
        .soachip { display:inline-flex; align-items:center; gap:7px; font-size:13px; color:var(--fg); }
        .soachip .sw { width:13px; height:13px; border-radius:3px; display:inline-block; }
        .soast { display:inline-block; padding:1px 9px; border-radius:11px; color:#fff; font-size:12px; font-weight:600; white-space:nowrap; }
        td.mut { color:var(--muted); font-size:12px; }
        section.note p { font-size:12.5px; color:var(--muted); line-height:1.55; }
        section.warn { background:rgba(226,163,54,.12); border:1px solid rgba(226,163,54,.4); border-radius:10px; padding:2px 14px; margin:14px 0; }
        section.warn p { font-size:12.5px; line-height:1.55; }
        .heat { border-collapse:separate; border-spacing:2px; }
        .heat th, .heat td { padding:6px 8px; font-size:12px; }
        .heat th.rot { max-width:64px; font-size:11px; color:var(--muted); vertical-align:bottom; }
        .heat td.hn { font-weight:600; white-space:nowrap; }
        .heat td.na { background:var(--card); color:var(--muted); text-align:center; }
        @media print { body { background:#fff; } .card,.cat,.finding,.meta,.cover,.riskmx { break-inside:avoid; } .riskmx td,.soast { print-color-adjust:exact; -webkit-print-color-adjust:exact; } }
        </style></head>
        <body><div class="wrap">
        \(body)
        </div></body></html>
        """
    }

    private static func gaugeSVG(score: Int, color: String) -> String {
        let r = 52.0, c = 2 * Double.pi * r
        let dash = c * Double(score) / 100.0
        return """
        <svg width="128" height="128" viewBox="0 0 128 128" style="flex:0 0 auto">
          <circle cx="64" cy="64" r="52" fill="none" stroke="var(--border)" stroke-width="10"/>
          <circle cx="64" cy="64" r="52" fill="none" stroke="\(color)" stroke-width="10" stroke-linecap="round"
            stroke-dasharray="\(fmt(dash)) \(fmt(c))" transform="rotate(-90 64 64)"/>
          <text x="64" y="60" text-anchor="middle" font-size="30" font-weight="700" fill="var(--fg)">\(score)</text>
          <text x="64" y="82" text-anchor="middle" font-size="12" fill="var(--muted)">de 100</text>
        </svg>
        """
    }

    private static func severityBars(_ s: AuditScore) -> String {
        let maxN = max(1, severeFirst.map { s.counts[$0] ?? 0 }.max() ?? 1)
        var rows = "<div class='bars'>"
        for sev in severeFirst {
            let n = s.counts[sev] ?? 0
            // Barra vazia quando não há achados; senão largura proporcional (mín. 6% p/ ficar visível).
            let pct = n == 0 ? 0 : max(6, Int(Double(n) / Double(maxN) * 100))
            rows += "<div class='barrow'><span class='lbl'>\(sev.label)</span><span class='track'><span class='fill' style='width:\(pct)%;background:\(colorHex(sev))'></span></span><span class='n'>\(n)</span></div>"
        }
        rows += "</div>"
        return rows
    }

    private static func findingCard(_ f: AuditFinding, full: Bool, frameworks: Bool = false, command: Bool = false, family: OSFamily = .apt) -> String {
        var html = "<div class='finding' style='--fbar:\(colorHex(f.severity))'>"
        html += "<span class='sev' style='color:\(colorHex(f.severity))'>\(f.severity.label)</span>"
        html += "<div class='ft'>\(esc(f.title))</div>"
        if frameworks { html += frameworkChips(ComplianceMap.refs(for: f)) }
        else if let cis = f.cis { html += "<div class='chips'><span class='fw cis'>CIS \(esc(cis))</span></div>" }
        if let e = f.evidence, !e.isEmpty { html += "<div class='fe'>\(esc(e))</div>" }
        if full || command, f.severity > .ok {
            if let i = f.businessImpact, !i.isEmpty { html += "<div class='fi'>\(esc(i))</div>" }
            if let r = f.recommendation, !r.isEmpty { html += "<div class='fr'>➜ \(esc(r))</div>" }
        }
        if command, f.severity > .ok, let cmd = RemediationMap.remediation(for: f, family: family).command {
            html += "<pre class='cmd'>\(esc(cmd))</pre>"
        }
        if command, let raw = f.evidenceRaw, !raw.isEmpty {
            html += "<details class='ev'><summary>Ver evidência (saída bruta)</summary><pre class='rawev'>\(esc(raw))</pre></details>"
        }
        html += "</div>"
        return html
    }

    // MARK: Conformidade (frameworks) — peças compartilhadas

    /// Chips de framework (CIS / ISO / NIST / OWASP) de um achado.
    static func frameworkChips(_ r: FrameworkRefs) -> String {
        var chips: [String] = []
        if let c = r.cis { chips.append("<span class='fw cis'>CIS \(esc(c))</span>") }
        if let i = r.iso27001 { chips.append("<span class='fw iso'>ISO 27001 \(esc(i))</span>") }
        if let n = r.nist { chips.append("<span class='fw nist'>NIST \(esc(n))</span>") }
        if let o = r.owasp { chips.append("<span class='fw owasp'>OWASP \(esc(o))</span>") }
        if let p = r.pci { chips.append("<span class='fw pci'>PCI-DSS \(esc(p))</span>") }
        return chips.isEmpty ? "" : "<div class='chips'>\(chips.joined())</div>"
    }

    /// Barras de aderência por framework (para executivo/SOC).
    static func complianceBars(_ audit: ExternalAudit) -> String {
        let cov = ComplianceMap.coverage(audit)
        guard !cov.isEmpty else { return "" }
        var rows = "<div class='bars'>"
        for c in cov {
            let color = c.percent >= 80 ? "#30a46c" : (c.percent >= 50 ? "#e2a336" : "#e5484d")
            rows += "<div class='barrow'><span class='lbl' style='width:150px'>\(esc(c.framework.rawValue))</span><span class='track'><span class='fill' style='width:\(max(4, c.percent))%;background:\(color)'></span></span><span class='n'>\(c.percent)%</span><span class='muted'>\(c.met)/\(c.checked)</span></div>"
        }
        rows += "</div>"
        return rows
    }

    /// Nota honesta: o mapeamento é parcial (só os controles que a auditoria verifica).
    static let complianceDisclaimer = "Aderência parcial: cobre apenas os controles que esta auditoria automatizada verifica — não substitui uma certificação formal (ISO 27001) nem um pentest completo."

    /// Recomendações de detecção/resposta derivadas dos achados (SOC).
    static func detectionTips(_ audit: ExternalAudit) -> [String] {
        let ids = Set(audit.findings.filter { $0.severity > .ok }.map { ComplianceMap.baseKey($0.id) })
        var tips: [String] = []
        if ids.contains("auditd-missing") { tips.append("Ative o auditd e centralize os logs (SIEM) para ter trilha de auditoria e alertas.") }
        if ids.contains("fail2ban-missing") || ids.contains("ssh-password-auth") || ids.contains("ssh-maxauthtries") {
            tips.append("Monitore tentativas de login SSH mal-sucedidas (T1110) e configure bloqueio automático (fail2ban/crowdsec).")
        }
        if ids.contains("exposed-ports") || ids.contains("firewall-inactive") || ids.contains("fw-default-allow") {
            tips.append("Monitore conexões de entrada nas portas expostas e alerte para novas portas abrindo (T1046/T1133).")
        }
        if ids.contains("mac-inactive") || ids.contains("mac-missing") { tips.append("Coloque AppArmor/SELinux em enforcing e alerte quando um perfil for desabilitado (T1562).") }
        if ids.contains("sudo-nopasswd") || ids.contains("uid0-multiple") || ids.contains("shadow-perms") {
            tips.append("Audite uso de sudo e mudanças em contas privilegiadas; alerte para acesso a /etc/shadow (T1003).")
        }
        if ids.contains("updates-security-pending") || ids.contains("os-eol") { tips.append("Acompanhe boletins de CVE dos serviços expostos e priorize patch dos itens críticos (T1190).") }
        if tips.isEmpty { tips.append("Mantenha coleta de logs centralizada e revisão periódica de acessos e alterações de configuração.") }
        return tips
    }

    /// "O que está em jogo" — consequências de negócio consolidadas (executivo).
    static func businessStakes(_ audit: ExternalAudit, score: AuditScore) -> [String] {
        let ids = Set(audit.findings.filter { $0.severity > .ok }.map { ComplianceMap.baseKey($0.id) })
        var out: [String] = []
        let accessIds: Set = ["ssh-root-login", "ssh-password-auth", "ssh-permit-empty", "empty-passwords", "sudo-nopasswd", "shadow-perms", "uid0-multiple"]
        if !ids.isDisjoint(with: accessIds) || (score.counts[.critical] ?? 0) > 0 {
            out.append("<b>Invasão e vazamento de dados</b> — falhas de acesso/credenciais podem permitir que um atacante entre no servidor e roube informações.")
        }
        if !ids.isDisjoint(with: ["os-eol", "updates-security-pending", "updates-pending", "reboot-required"]) {
            out.append("<b>Exploração de falhas conhecidas</b> — software desatualizado/sem suporte é alvo fácil de ataques automatizados.")
        }
        if !ids.isDisjoint(with: ["disk-space", "disk-smart", "disk-realloc"]) {
            out.append("<b>Indisponibilidade e perda de dados</b> — problemas de disco podem derrubar serviços e corromper informações.")
        }
        if !ids.isDisjoint(with: ["firewall-inactive", "fw-default-allow", "exposed-ports"]) {
            out.append("<b>Superfície de ataque ampla</b> — serviços expostos sem proteção adequada aumentam a chance de invasão.")
        }
        if !ids.isDisjoint(with: ["auditd-missing", "mac-inactive", "fail2ban-missing"]) {
            out.append("<b>Baixa visibilidade</b> — sem registro/proteção adequados, um incidente pode passar despercebido e ser difícil de investigar.")
        }
        return out
    }

    /// Rótulo humano para o modo do coletor. O coletor de sistema emite
    /// "admin"/"user"; o de banco, "completo"/"estrutura" — valores fora
    /// desses aparecem crus em vez de virarem "Usuário (parcial)" por engano.
    static func modeLabel(_ mode: String) -> String {
        switch mode {
        case "admin": "Administrativo (completo)"
        case "user": "Usuário (parcial)"
        case "completo": "Banco — completo (com amostras)"
        case "estrutura": "Banco — estrutura (sem dados)"
        default: mode
        }
    }

    /// "AAAA-MM-DDThh:mm:ssZ" → "DD/MM/AAAA às HH:mm (UTC)". Aceita fração de segundo.
    static func humanDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        let ff = ISO8601DateFormatter()
        ff.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let d = f.date(from: iso) ?? ff.date(from: iso) else { return String(iso.prefix(10)) }
        let out = DateFormatter()
        out.locale = Locale(identifier: "pt_BR")
        out.timeZone = TimeZone(identifier: "UTC")
        out.dateFormat = "dd/MM/yyyy 'às' HH:mm"
        return out.string(from: d) + " (UTC)"
    }

    // MARK: Acabamento profissional (compartilhado)

    /// Faixa de classificação do documento (nível empresarial). Usa o aviso da marca
    /// quando configurado; senão, o padrão.
    static func classificationBanner(_ b: ReportBranding? = nil) -> String {
        let text = (b?.confidentiality.isEmpty == false) ? b!.confidentiality
            : "CONFIDENCIAL · Uso interno / cliente — não distribuir sem autorização"
        return "<div class='classif'>\(esc(text))</div>"
    }

    /// Capa/marca (white-label): logo + empresa auditora + auditor + cliente + nº do relatório.
    /// Vazio quando não há marca configurada (mantém o layout antigo).
    static func brandingCover(_ b: ReportBranding?, reportTitle: String) -> String {
        guard let b, b.isConfigured else { return "" }
        var left = ""
        if !b.company.isEmpty { left += "<div class='bco'>\(esc(b.company))</div>" }
        left += "<div class='brt'>\(esc(reportTitle))</div>"
        var rows: [String] = []
        if !b.client.isEmpty { rows.append("<b>Cliente:</b> \(esc(b.client))") }
        if !b.auditor.isEmpty {
            let who = b.auditorTitle.isEmpty ? esc(b.auditor) : "\(esc(b.auditor)) — \(esc(b.auditorTitle))"
            rows.append("<b>Auditor:</b> \(who)")
        }
        if !b.contact.isEmpty { rows.append("<b>Contato:</b> \(esc(b.contact))") }
        if !b.reportNumber.isEmpty { rows.append("<b>Relatório nº:</b> \(esc(b.reportNumber))") }
        if !rows.isEmpty { left += "<div class='bmeta'>" + rows.joined(separator: " · ") + "</div>" }
        let logo = b.logoDataURI.map { "<img class='blogo' src='\(esc($0))' alt='logo'>" } ?? ""
        return "<div class='cover'><div class='cleft'>\(left)</div>\(logo)</div>"
    }

    /// Bloco de metadados do relatório (quem/quando/escopo).
    static func metaBlock(_ audit: ExternalAudit, scope: String) -> String {
        var rows: [(String, String)] = [
            ("Servidor auditado", audit.host.hostname),
            ("Sistema", audit.os?.pretty ?? "—"),
            ("Data da coleta", humanDate(audit.collectedAt)),
            ("Modo de coleta", modeLabel(audit.collector.mode)),
            ("Escopo", scope),
            ("Ferramenta", "\(audit.collector.name) \(audit.collector.version) (Uptend)"),
        ]
        if let id = audit.host.machineId { rows.append(("ID da máquina", id)) }
        var html = "<div class='meta'>"
        for (k, v) in rows { html += "<div><span class='mk'>\(esc(k))</span><span class='mv'>\(esc(v))</span></div>" }
        html += "</div>"
        return html
    }

    /// Pontuação por área (domínio de risco).
    static func domainBars(_ audit: ExternalAudit) -> String {
        let ds = AuditDomains.scores(audit)
        guard !ds.isEmpty else { return "" }
        var rows = "<div class='bars'>"
        for d in ds {
            let color = colorHex(d.light)
            rows += "<div class='barrow'><span class='lbl' style='width:190px'>\(esc(d.name))</span><span class='track'><span class='fill' style='width:\(max(4, d.score))%;background:\(color)'></span></span><span class='n'>\(d.score)</span><span class='muted'>\(d.findings) chk</span></div>"
        }
        rows += "</div>"
        return rows
    }

    static func severityLegend() -> String {
        let items: [(AuditSeverity, String)] = [
            (.critical, "risco imediato"), (.high, "risco relevante"), (.medium, "atenção"),
            (.low, "melhoria"), (.ok, "conforme"),
        ]
        var html = "<div class='legend'>"
        for (s, d) in items { html += "<span><span class='dot' style='background:\(colorHex(s))'></span>\(s.label) — \(esc(d))</span>" }
        html += "</div>"
        return html
    }

    /// Bloco de assinatura digital (rodapé) — cadeia de custódia.
    static func signatureBlock(_ s: ReportSignature?) -> String {
        guard let s else { return "" }
        return """
        <section><h2>Assinatura digital</h2>
        <div class='meta'>
          <div><span class='mk'>Assinado por</span><span class='mv'>\(esc(s.auditor.isEmpty ? "—" : s.auditor))</span></div>
          <div><span class='mk'>Impressão digital (P-256)</span><span class='mv'>\(esc(s.prettyFingerprint))</span></div>
          <div><span class='mk'>Assinado em</span><span class='mv'>\(esc(humanDate(s.signedAt)))</span></div>
          <div><span class='mk'>Hash do conteúdo (SHA-256)</span><span class='mv'>\(esc(String(s.contentHash.prefix(24))))…</span></div>
        </div>
        <p class='sub'>Este relatório é assinado digitalmente (ECDSA P-256). Qualquer alteração no conteúdo da auditoria invalida a verificação. Salve o arquivo <code>.sig</code> para permitir a conferência por terceiros.</p>
        </section>
        """
    }

    static func methodologyHTML() -> String {
        """
        <section><h2>Metodologia e frameworks</h2>
        <p class='sub'>Auditoria automatizada e <b>somente-leitura</b>: um coletor portátil lê a configuração do servidor (sem alterar nada, sem acesso à internet) e o Uptend processa localmente. Os achados são mapeados aos frameworks reconhecidos pelo mercado:</p>
        <ul>
        <li><b>CIS Benchmarks</b> — linha de base de configuração segura.</li>
        <li><b>ISO/IEC 27001 (Anexo A)</b> — controles de gestão de segurança da informação.</li>
        <li><b>NIST Cybersecurity Framework</b> — funções Identificar/Proteger/Detectar/Responder/Recuperar.</li>
        <li><b>OWASP Top 10 (2021)</b> — categorias de risco mais comuns.</li>
        <li><b>PCI-DSS</b> — requisitos para ambientes que tratam dados de cartão.</li>
        </ul>
        <p class='sub'>\(esc(complianceDisclaimer))</p>
        </section>
        """
    }

    /// Parágrafo de sumário executivo.
    static func execSummaryText(_ audit: ExternalAudit, _ s: AuditScore) -> String {
        let crit = s.counts[.critical] ?? 0, high = s.counts[.high] ?? 0
        let mat = maturity(s.score)
        let checked = audit.findings.count
        var t = "Esta auditoria avaliou o servidor \(audit.host.hostname) em \(checked) pontos de segurança e boas práticas. "
        t += "O índice de saúde é \(s.score)/100, correspondendo a uma postura \"\(lightLabel(s.light))\" e a um nível de maturidade \(mat.level). "
        if crit + high > 0 {
            t += "Foram identificados \(crit) achado(s) crítico(s) e \(high) de severidade alta, que devem ser tratados com prioridade. "
        } else {
            t += "Não há achados críticos ou de severidade alta em aberto. "
        }
        t += "As seções a seguir apresentam o plano de ação priorizado, a aderência aos frameworks de mercado e o que está em jogo para o negócio."
        return t
    }

    /// Nível de maturidade de segurança (para o executivo).
    static func maturity(_ score: Int) -> (level: String, note: String) {
        switch score {
        case 80...: ("Otimizado", "boas práticas consolidadas")
        case 60..<80: ("Gerenciado", "controles presentes, com pontos a reforçar")
        case 40..<60: ("Básico", "faltam controles essenciais")
        default: ("Inicial", "postura frágil — requer ação estruturada")
        }
    }

    /// Cobertura por função do NIST CSF, em barras (SOC).
    static func nistFunctionBars(_ audit: ExternalAudit) -> String {
        let cov = ComplianceMap.nistFunctionCoverage(audit)
        guard !cov.isEmpty else { return "" }
        var rows = "<div class='bars'>"
        for c in cov {
            let color = c.percent >= 80 ? "#30a46c" : (c.percent >= 50 ? "#e2a336" : "#e5484d")
            rows += "<div class='barrow'><span class='lbl' style='width:120px'>\(esc(c.function))</span><span class='track'><span class='fill' style='width:\(max(4, c.percent))%;background:\(color)'></span></span><span class='n'>\(c.percent)%</span><span class='muted'>\(c.met)/\(c.checked)</span></div>"
        }
        rows += "</div>"
        return rows
    }

    /// Tabela MITRE ATT&CK (assinatura do SOC) — só achados que são risco ativo.
    static func mitreTable(_ audit: ExternalAudit) -> String {
        let items = audit.findings.filter { $0.severity > .ok && MitreMap.hasTechnique($0) }
            .sorted { $0.severity > $1.severity }
        guard !items.isEmpty else { return "" }
        var html = "<table><thead><tr><th>Achado</th><th>Severidade</th><th>Técnica ATT&amp;CK</th><th>Tática</th></tr></thead><tbody>"
        for f in items {
            guard let t = MitreMap.technique(for: f) else { continue }
            html += "<tr><td>\(esc(f.title))</td><td style='color:\(colorHex(f.severity));font-weight:600'>\(f.severity.label)</td><td><b>\(esc(t.id))</b> \(esc(t.name))</td><td>\(esc(t.tactic))</td></tr>"
        }
        html += "</tbody></table>"
        return html
    }

    /// Tabela de mapeamento achado → frameworks (assinatura do relatório SOC).
    static func mappingTable(_ audit: ExternalAudit) -> String {
        let items = audit.findings.filter { ComplianceMap.hasAnyRef($0) }
            .sorted { $0.severity > $1.severity }
        guard !items.isEmpty else { return "" }
        var html = "<table><thead><tr><th>Achado</th><th>Status</th><th>CIS</th><th>ISO 27001</th><th>NIST CSF</th><th>OWASP</th><th>PCI-DSS</th></tr></thead><tbody>"
        for f in items {
            let r = ComplianceMap.refs(for: f)
            let ok = f.severity == .ok
            let status = ok ? "Atendido" : "Não atendido"
            let color = ok ? "#30a46c" : colorHex(f.severity)
            html += "<tr><td>\(esc(f.title))</td><td style='color:\(color);font-weight:600'>\(status)</td>"
            // r.cis pode vir do JSON do coletor (host adversarial) → SEMPRE escapar.
            // Os demais refs vêm de tabelas estáticas internas do ComplianceMap.
            html += "<td>\(esc(r.cis ?? "—"))</td><td>\(esc(r.iso27001 ?? "—"))</td>"
            html += "<td>\(r.nist.map { "\($0) · \(ComplianceMap.nistFunction($0))" } ?? "—")</td>"
            html += "<td>\(r.owasp.map { "\($0)" } ?? "—")</td><td>\(r.pci.map { "Req \($0)" } ?? "—")</td></tr>"
        }
        html += "</tbody></table>"
        return html
    }

    private static func infoCard(_ k: String, _ v: String, _ d: String, danger: Bool = false) -> String {
        var html = "<div class='card'><div class='k'>\(esc(k))</div><div class='v'>\(esc(v.isEmpty ? "—" : v))</div>"
        if !d.isEmpty { html += "<div class='d\(danger ? " danger" : "")'>\(esc(d))</div>" }
        html += "</div>"
        return html
    }

    // MARK: Executivo — textos de negócio

    private static func businessVerdict(score: Int, light: AuditLight) -> (title: String, sentence: String) {
        switch light {
        case .green:
            return ("Postura de segurança boa",
                    "O servidor segue as boas práticas na maior parte dos pontos avaliados. Os riscos que restam são de baixo impacto e podem ser tratados no fluxo normal de manutenção.")
        case .yellow:
            return ("Requer atenção",
                    "Foram encontrados pontos que aumentam a chance de um incidente (invasão, indisponibilidade ou vazamento). Recomenda-se tratar as prioridades listadas nas próximas semanas.")
        case .red:
            return ("Situação crítica",
                    "Foram encontradas falhas relevantes que expõem o negócio a risco imediato. Recomenda-se ação urgente sobre os primeiros itens do plano de ação.")
        }
    }

    private static func businessPriority(_ sev: AuditSeverity) -> String {
        switch sev {
        case .critical: "Urgente"
        case .high: "Prioridade alta"
        case .medium: "Prioridade média"
        case .low: "Baixa"
        case .ok: "OK"
        }
    }

    private static func kpi(_ value: String, _ label: String, danger: Bool) -> String {
        "<div class='kpi\(danger ? " danger" : "")'><div class='kv'>\(esc(value))</div><div class='kl'>\(esc(label))</div></div>"
    }

    /// Cor da barra de prontidão do perfil: verde forte, ok, fraco.
    private static func readinessColor(_ score: Int) -> String {
        if score >= 70 { return "#30a46c" }
        if score >= 40 { return "#e2a336" }
        return "#8a8a8f"
    }

    private static func execPage(title: String, accent: String, body: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="pt-BR"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(esc(title))</title>
        <style>
        :root { --bg:#ffffff; --fg:#1d1d1f; --muted:#6b6b70; --card:#f5f5f7; --border:#e2e2e6; --accent:\(accent); }
        @media (prefers-color-scheme: dark) { :root { --bg:#1c1c1e; --fg:#f2f2f7; --muted:#98989f; --card:#2c2c2e; --border:#3a3a3c; } }
        * { box-sizing:border-box; }
        body { margin:0; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif; background:var(--bg); color:var(--fg); line-height:1.55; }
        .wrap { max-width:1080px; margin:0 auto; padding:40px 32px; }
        .ehead { display:flex; align-items:center; justify-content:space-between; gap:24px; }
        h1 { font-size:28px; margin:0; letter-spacing:-.4px; }
        h2 { font-size:19px; margin:34px 0 14px; }
        .esub { color:var(--muted); margin:8px 0 0; font-size:15px; }
        .verdict { border:1px solid; border-left-width:5px; border-radius:12px; padding:16px 18px; margin-top:22px; background:var(--card); }
        .verdict .vtag { display:inline-block; color:#fff; font-weight:700; font-size:13px; padding:3px 12px; border-radius:20px; margin-bottom:8px; }
        .verdict p { margin:0; font-size:16px; }
        .kpis { display:grid; grid-template-columns:repeat(auto-fit,minmax(150px,1fr)); gap:12px; }
        .kpi { background:var(--card); border:1px solid var(--border); border-radius:12px; padding:16px; text-align:center; }
        .kpi.danger { border-color:#e5484d55; }
        .kpi .kv { font-size:28px; font-weight:700; }
        .kpi .kl { font-size:13px; color:var(--muted); margin-top:4px; }
        .alert { background:rgba(229,72,77,.08); border:1px solid rgba(229,72,77,.3); border-radius:10px; padding:12px 14px; margin-bottom:8px; font-size:15px; }
        .lead { color:var(--muted); margin:0 0 14px; }
        .action { display:flex; gap:14px; background:var(--card); border:1px solid var(--border); border-radius:12px; padding:14px 16px; margin-bottom:10px; }
        .action .anum { flex:0 0 30px; height:30px; width:30px; border-radius:50%; background:var(--accent); color:#fff; font-weight:700; display:flex; align-items:center; justify-content:center; }
        .action .atitle { font-weight:600; font-size:16px; }
        .action .prio { color:#fff; font-size:11px; font-weight:700; padding:2px 8px; border-radius:20px; margin-left:6px; white-space:nowrap; }
        .action .arec { margin-top:6px; font-size:15px; }
        .action .awhy { margin-top:4px; font-size:14px; color:var(--muted); }
        .strengths { display:grid; grid-template-columns:repeat(auto-fill,minmax(240px,1fr)); gap:8px; }
        .strong { background:rgba(48,164,108,.10); border:1px solid rgba(48,164,108,.3); border-radius:8px; padding:9px 12px; font-size:14px; color:#2b8a5e; }
        .svc { background:var(--card); border:1px solid var(--border); border-radius:8px; padding:9px 12px; font-size:14px; }
        .bars { display:flex; flex-direction:column; gap:7px; }
        .barrow { display:flex; align-items:center; gap:10px; font-size:14px; }
        .barrow .lbl { color:var(--muted); }
        .barrow .track { flex:1; background:var(--border); border-radius:6px; height:16px; overflow:hidden; }
        .barrow .fill { display:block; height:100%; border-radius:6px; }
        .barrow .n { width:44px; text-align:right; font-variant-numeric:tabular-nums; font-weight:600; }
        .barrow .muted { color:var(--muted); font-size:12px; width:44px; text-align:right; }
        footer { margin-top:36px; padding-top:16px; border-top:1px solid var(--border); color:var(--muted); font-size:12px; }
        .classif { background:#e5484d; color:#fff; font-size:12px; font-weight:700; letter-spacing:.3px; padding:6px 12px; border-radius:6px; text-align:center; margin-bottom:16px; }
        .meta { display:grid; grid-template-columns:repeat(auto-fit,minmax(240px,1fr)); gap:6px 20px; background:var(--card); border:1px solid var(--border); border-radius:10px; padding:14px 16px; margin-top:14px; }
        .meta > div { display:flex; justify-content:space-between; gap:12px; font-size:13px; border-bottom:1px dotted var(--border); padding:3px 0; }
        .meta .mk { color:var(--muted); }
        .meta .mv { font-weight:600; text-align:right; }
        .sub { color:var(--muted); font-size:14px; }
        ul { padding-left:20px; } li { margin:3px 0; }
        .cover { display:flex; align-items:center; justify-content:space-between; gap:20px; border:1px solid var(--border); border-radius:12px; padding:18px 20px; margin-bottom:14px; background:var(--card); }
        .cover .bco { font-size:19px; font-weight:700; }
        .cover .brt { font-size:16px; color:var(--muted); margin-top:2px; }
        .cover .bmeta { font-size:13px; margin-top:8px; }
        .cover .blogo { max-height:70px; max-width:220px; object-fit:contain; }
        .riskmx { border-collapse:separate; border-spacing:3px; margin-top:10px; }
        .riskmx td { width:52px; height:40px; text-align:center; border-radius:6px; font-size:13px; }
        .riskmx td .rn { display:inline-block; min-width:22px; padding:1px 5px; border-radius:11px; background:rgba(0,0,0,.42); color:#fff; font-weight:700; font-size:13px; }
        .riskmx th.axis { background:transparent; color:var(--muted); font-weight:600; font-size:12px; padding:0 6px; }
        .rlegend { display:flex; gap:16px; flex-wrap:wrap; margin:10px 0 2px; color:var(--muted); font-size:12.5px; align-items:center; }
        .rlegend span { display:inline-flex; align-items:center; gap:6px; }
        .rlegend .rsw { width:14px; height:14px; border-radius:4px; display:inline-block; }
        @media print { body { background:#fff; } .action,.kpi,.strong,.verdict,.meta,.cover,.riskmx { break-inside:avoid; } .riskmx td { print-color-adjust:exact; -webkit-print-color-adjust:exact; } }
        </style></head>
        <body><div class="wrap">
        \(body)
        </div></body></html>
        """
    }

    // MARK: Cores + escaping

    private static func colorHex(_ light: AuditLight) -> String {
        switch light {
        case .green: "#30a46c"
        case .yellow: "#e2a336"
        case .red: "#e5484d"
        }
    }
    private static func colorHex(_ sev: AuditSeverity) -> String {
        switch sev {
        case .ok: "#30a46c"
        case .low: "#3a7bd5"
        case .medium: "#e2a336"
        case .high: "#e5711a"
        case .critical: "#e5484d"
        }
    }

    private static func fmt(_ d: Double) -> String { String(format: "%.1f", d) }

    private static func todayISO() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// Escapa texto para caber com segurança em HTML (nunca injeta markup do dado coletado).
    static func esc(_ s: String) -> String {
        var r = s
        r = r.replacingOccurrences(of: "&", with: "&amp;")
        r = r.replacingOccurrences(of: "<", with: "&lt;")
        r = r.replacingOccurrences(of: ">", with: "&gt;")
        r = r.replacingOccurrences(of: "\"", with: "&quot;")
        r = r.replacingOccurrences(of: "'", with: "&#39;")   // também aspa simples: cobre atributos com '...'
        return r
    }

    /// Escapa uma célula de tabela Markdown: a `|` quebraria a coluna; a quebra de
    /// linha, a linha inteira. Para a saída .md (relatórios "para IA").
    static func mdCell(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "|", with: "\\|")
         .replacingOccurrences(of: "\n", with: " ")
         .replacingOccurrences(of: "\r", with: " ")
    }

    /// Cerca de código maior que qualquer sequência de crases do conteúdo — uma
    /// evidência contendo ``` escaparia do bloco e injetaria Markdown no relatório.
    static func mdFence(for raw: String) -> String {
        var maxRun = 0, run = 0
        for ch in raw {
            if ch == "`" { run += 1; maxRun = max(maxRun, run) } else { run = 0 }
        }
        return String(repeating: "`", count: max(3, maxRun + 1))
    }
}
