import Foundation

// MARK: - Renderização (pura, testável)

enum SystemReport {

    /// Decide se uma seção entra, conforme o escopo escolhido.
    static func includes(_ section: Section, scope: ReportScope) -> Bool {
        switch section {
        case .hardware: return [.complete, .hardware, .storage].contains(scope)
        case .system: return [.complete, .hardware].contains(scope)
        case .software: return [.complete, .apps, .storage].contains(scope)
        case .security: return [.complete, .security].contains(scope)
        case .personalization: return scope == .complete
        case .storage: return [.complete, .storage].contains(scope)
        }
    }
    enum Section { case hardware, system, software, security, personalization, storage }

    /// Ponto de entrada: renderiza no formato pedido.
    static func render(_ data: ReportData, scope: ReportScope, format: ReportFormat, detail: ReportDetail) -> String {
        switch format {
        case .markdown: return markdown(data, scope: scope, detail: detail)
        case .text: return plain(data, scope: scope, detail: detail)
        case .json: return json(data, scope: scope, detail: detail)
        case .html: return html(data, scope: scope, detail: detail)
        }
    }

    // MARK: Markdown

    static func markdown(_ d: ReportData, scope: ReportScope, detail: ReportDetail) -> String {
        var l: [String] = []
        l.append("# Inventário do Mac — Uptend")
        l.append("")
        l.append("Gerado em \(d.generatedAt) · \(scope.title)")
        l.append("")
        l.append("## Identificação")
        l.append("- Nome do computador: \(d.computerName)")
        l.append("- Número de série: \(d.serialNumber)")
        l.append("- Modelo (identificador): \(d.modelIdentifier)")
        l.append("- Hardware UUID: \(d.hardwareUUID)")

        if includes(.hardware, scope: scope) {
            l.append("")
            l.append("## Hardware")
            l.append("- Modelo: \(d.model)")
            l.append("- Chip: \(d.chip)")
            l.append("- Núcleos: \(d.cores)")
            l.append("- Memória: \(d.memory)")
            l.append("- Disco: \(d.diskFree) livres de \(d.diskTotal)")
            l.append("- Ciclos da bateria: \(d.batteryCycles)")
        }
        if includes(.system, scope: scope) {
            l.append("")
            l.append("## Sistema")
            l.append("- macOS: \(d.osVersion)")
            l.append("- Ativo há: \(d.uptime)")
            l.append("- IP local: \(d.localIP)")
        }
        if includes(.software, scope: scope) {
            l.append("")
            l.append("## Aplicativos (\(d.apps.count))")
            l.append("- Pacotes do Homebrew: \(d.brewPackages)")
            l.append("- Atualizações pendentes: \(d.outdated)")
            l.append("- Espaço total em apps: \(ByteCountFormatter.string(fromByteCount: d.totalAppsSize, countStyle: .file))")
            l.append("")
            if detail == .detailed {
                l.append("| App | Versão | Tamanho | Origem |")
                l.append("|-----|--------|---------|--------|")
                for a in d.apps.sorted(by: { $0.sizeBytes > $1.sizeBytes }) {
                    l.append("| \(a.name) | \(a.version ?? "—") | \(a.sizeLabel) | \(a.source) |")
                }
            } else {
                l.append("Maiores apps:")
                for a in d.apps.sorted(by: { $0.sizeBytes > $1.sizeBytes }).prefix(10) {
                    l.append("- \(a.name) — \(a.sizeLabel)")
                }
            }
        }
        if includes(.security, scope: scope) {
            l.append("")
            l.append("## Segurança")
            if d.security.isEmpty { l.append("- (não verificado)") }
            for c in d.security { l.append("- \(c.name): \(c.ok ? "OK" : "ATENÇÃO") — \(c.detail)") }
        }
        l.append(contentsOf: deepMarkdown(d, scope: scope))
        l.append("")
        l.append("_Gerado localmente pelo Uptend. Nenhum dado foi enviado para fora._")
        return l.joined(separator: "\n")
    }

    /// Seções do pente-fino em Markdown (só aparecem quando coletadas).
    private static func deepMarkdown(_ d: ReportData, scope: ReportScope) -> [String] {
        guard let deep = d.deep else { return [] }
        var l: [String] = []
        func section(_ title: String) { l.append(""); l.append("## \(title)") }

        if includes(.system, scope: scope) {
            let sys = [("Build do macOS", deep.osBuild), ("Kernel", deep.kernel),
                       ("Ligado desde", deep.bootTime), ("Fuso horário", deep.timezone),
                       ("Nome local", deep.localHostName)].filter { !$0.1.isEmpty }
            if !sys.isEmpty { section("Sistema detalhado"); for (k, v) in sys { l.append("- \(k): \(v)") } }
        }
        if includes(.hardware, scope: scope), !deep.gpu.isEmpty || !deep.batteryCondition.isEmpty {
            section("Hardware detalhado")
            for g in deep.gpu { l.append("- GPU: \(g)") }
            for m in deep.displays { l.append("- Monitor: \(m)") }
            if !deep.batteryCondition.isEmpty { l.append("- Bateria: \(deep.batteryCondition)") }
        }
        if includes(.system, scope: scope), !deep.interfaces.isEmpty || !deep.dns.isEmpty {
            section("Rede detalhada")
            for i in deep.interfaces { l.append("- \(i.name): IP \(i.ip.isEmpty ? "—" : i.ip) · MAC \(i.mac.isEmpty ? "—" : i.mac)") }
            if !deep.gateway.isEmpty { l.append("- Gateway: \(deep.gateway)") }
            if !deep.dns.isEmpty { l.append("- DNS: \(deep.dns.joined(separator: ", "))") }
        }
        if includes(.software, scope: scope) {
            if !deep.runtimes.isEmpty {
                section("Ferramentas de linha de comando")
                for r in deep.runtimes { l.append("- \(r.name): \(r.version)") }
            }
            if !deep.brewFormulaeList.isEmpty || !deep.brewCasksList.isEmpty {
                section("Homebrew instalado")
                if !deep.brewFormulaeList.isEmpty { l.append("- Fórmulas: \(deep.brewFormulaeList.joined(separator: ", "))") }
                if !deep.brewCasksList.isEmpty { l.append("- Casks: \(deep.brewCasksList.joined(separator: ", "))") }
            }
            if !deep.installHistory.isEmpty {
                section("Histórico de instalações (recentes)")
                for h in deep.installHistory { l.append("- \(h)") }
            }
        }
        if includes(.personalization, scope: scope) {
            section("Integridade e personalizações")
            l.append("- Proteção do sistema (SIP): \(deep.sip.isEmpty ? "—" : deep.sip)")
            l.append("- Apps fora da App Store: \(deep.nonAppStoreApps)")
            l.append("- Homebrew: \(deep.brewFormulae) fórmulas, \(deep.brewCasks) casks")
            l.append("- /usr/local presente: \(deep.hasUsrLocal ? "sim" : "não") · /opt: \(deep.hasOpt ? "sim" : "não")")
            if !deep.shellDotfiles.isEmpty { l.append("- Configs de shell: \(deep.shellDotfiles.joined(separator: ", "))") }
            if !deep.users.isEmpty { l.append("- Contas de usuário: \(deep.users.joined(separator: ", "))") }
            l.append("- Itens de inicialização (não-Apple): " + (deep.startupItems.isEmpty ? "nenhum" : ""))
            for s in deep.startupItems { l.append("  - \(s)") }
            if !deep.loginItems.isEmpty {
                l.append("- Itens de login:")
                for s in deep.loginItems { l.append("  - \(s)") }
            }
            if !deep.systemExtensions.isEmpty {
                l.append("- Extensões de sistema (terceiros):")
                for e in deep.systemExtensions { l.append("  - \(e)") }
            }
        }
        if includes(.storage, scope: scope), !deep.folderSizes.isEmpty || !deep.largestFiles.isEmpty {
            section("Armazenamento")
            for f in deep.folderSizes.sorted(by: { $0.bytes > $1.bytes }) { l.append("- \(f.name): \(f.sizeLabel)") }
            if !deep.volumes.isEmpty {
                l.append("- Volumes:"); for v in deep.volumes { l.append("  - \(v)") }
            }
            if !deep.largestFiles.isEmpty {
                l.append("- Maiores arquivos:")
                for file in deep.largestFiles { l.append("  - \(file.sizeLabel) — \(file.path)") }
            }
        }
        if includes(.hardware, scope: scope) {
            for raw in deep.rawSections {
                section(raw.title); l.append("```"); l.append(raw.text); l.append("```")
            }
        }
        return l
    }

    // MARK: Texto simples

    static func plain(_ d: ReportData, scope: ReportScope, detail: ReportDetail) -> String {
        // Reaproveita o Markdown removendo os marcadores mais chamativos.
        markdown(d, scope: scope, detail: detail)
            .replacingOccurrences(of: "# ", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "_", with: "")
    }

    // MARK: JSON

    static func json(_ d: ReportData, scope: ReportScope, detail: ReportDetail) -> String {
        var dict: [String: Any] = [
            "gerado_em": d.generatedAt,
            "escopo": scope.rawValue,
            "identificacao": [
                "nome_computador": d.computerName,
                "numero_serie": d.serialNumber,
                "modelo_identificador": d.modelIdentifier,
                "hardware_uuid": d.hardwareUUID,
            ],
        ]
        if includes(.hardware, scope: scope) {
            dict["hardware"] = [
                "modelo": d.model, "chip": d.chip, "nucleos": d.cores,
                "memoria": d.memory, "disco_total": d.diskTotal, "disco_livre": d.diskFree,
                "ciclos_bateria": d.batteryCycles,
            ]
        }
        if includes(.system, scope: scope) {
            dict["sistema"] = ["macos": d.osVersion, "ativo_ha": d.uptime, "ip_local": d.localIP]
        }
        if includes(.software, scope: scope) {
            dict["aplicativos"] = [
                "total": d.apps.count,
                "pacotes_homebrew": d.brewPackages,
                "atualizacoes_pendentes": d.outdated,
                "lista": d.apps.sorted(by: { $0.sizeBytes > $1.sizeBytes }).map { a in
                    ["nome": a.name, "versao": a.version ?? "", "bytes": a.sizeBytes,
                     "tamanho": a.sizeLabel, "origem": a.source, "bundle_id": a.bundleID ?? ""]
                },
            ]
        }
        if includes(.security, scope: scope) {
            dict["seguranca"] = d.security.map { ["nome": $0.name, "ok": $0.ok, "detalhe": $0.detail] }
        }
        if let deep = d.deep {
            if includes(.hardware, scope: scope), !deep.gpu.isEmpty || !deep.batteryCondition.isEmpty {
                dict["hardware_detalhado"] = ["gpu": deep.gpu, "monitores": deep.displays, "bateria": deep.batteryCondition]
            }
            if includes(.system, scope: scope) {
                dict["sistema_detalhado"] = [
                    "build_macos": deep.osBuild, "kernel": deep.kernel, "ligado_desde": deep.bootTime,
                    "fuso_horario": deep.timezone, "nome_local": deep.localHostName,
                ]
                if !deep.interfaces.isEmpty {
                    dict["rede_detalhada"] = [
                        "interfaces": deep.interfaces.map { ["nome": $0.name, "ip": $0.ip, "mac": $0.mac] },
                        "gateway": deep.gateway, "dns": deep.dns,
                    ]
                }
            }
            if includes(.software, scope: scope) {
                if !deep.runtimes.isEmpty {
                    dict["ferramentas"] = deep.runtimes.map { ["nome": $0.name, "versao": $0.version] }
                }
                dict["homebrew_instalado"] = ["formulas": deep.brewFormulaeList, "casks": deep.brewCasksList]
                if !deep.installHistory.isEmpty { dict["historico_instalacoes"] = deep.installHistory }
            }
            if includes(.personalization, scope: scope) {
                dict["personalizacoes"] = [
                    "sip": deep.sip, "apps_fora_app_store": deep.nonAppStoreApps,
                    "homebrew_formulas": deep.brewFormulae, "homebrew_casks": deep.brewCasks,
                    "usr_local": deep.hasUsrLocal, "opt": deep.hasOpt,
                    "configs_shell": deep.shellDotfiles, "contas_usuario": deep.users,
                    "itens_inicializacao": deep.startupItems, "itens_login": deep.loginItems,
                    "extensoes_sistema": deep.systemExtensions,
                ]
            }
            if includes(.hardware, scope: scope), !deep.rawSections.isEmpty {
                dict["detalhes_brutos"] = Dictionary(uniqueKeysWithValues: deep.rawSections.map { ($0.title, $0.text) })
            }
            if includes(.storage, scope: scope), !deep.folderSizes.isEmpty || !deep.largestFiles.isEmpty {
                dict["armazenamento"] = [
                    "pastas": deep.folderSizes.sorted(by: { $0.bytes > $1.bytes }).map { ["nome": $0.name, "bytes": $0.bytes, "tamanho": $0.sizeLabel] },
                    "volumes": deep.volumes,
                    "maiores_arquivos": deep.largestFiles.map { ["caminho": $0.path, "bytes": $0.bytes, "tamanho": $0.sizeLabel] },
                ]
            }
        }
        guard let json = try? JSONSerialization.data(withJSONObject: dict,
                                                     options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: json, encoding: .utf8) else { return "{}" }
        return text
    }

    // MARK: HTML (para imprimir / salvar em PDF)

    static func html(_ d: ReportData, scope: ReportScope, detail: ReportDetail) -> String {
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        }
        // Um cartão de categoria com marcador colorido no título.
        func card(_ tint: String, _ title: String, _ inner: String) -> String {
            guard !inner.isEmpty else { return "" }
            return "<section class=\"card\"><h2><span class=\"ic\" style=\"background:\(tint)\"></span>\(esc(title))</h2><div class=\"body\">\(inner)</div></section>"
        }
        func kv(_ pairs: [(String, String)]) -> String {
            let rows = pairs.filter { !$0.1.isEmpty }
                .map { "<tr><th>\(esc($0.0))</th><td>\(esc($0.1))</td></tr>" }.joined()
            return rows.isEmpty ? "" : "<table class=\"kv\">\(rows)</table>"
        }
        func bar(_ value: Int64, _ max: Int64) -> String {
            let pct = max > 0 ? min(100, Int(Double(value) / Double(max) * 100)) : 0
            return "<div class=\"bar\"><span style=\"width:\(pct)%\"></span></div>"
        }
        var body = ""

        // Hero
        body += "<div class=\"hero\"><h1>Inventário do Mac</h1>"
        body += "<div class=\"sub\">\(esc(d.computerName)) · Série \(esc(d.serialNumber))</div>"
        body += "<div class=\"chips\"><span class=\"chip\">\(esc(scope.title))</span><span class=\"chip\">\(esc(d.generatedAt))</span><span class=\"chip\">\(esc(d.model))</span></div></div>"

        body += card("#8e8e93", "Identificação", kv([
            ("Nome do computador", d.computerName), ("Número de série", d.serialNumber),
            ("Modelo (identificador)", d.modelIdentifier), ("Hardware UUID", d.hardwareUUID),
        ]))
        if includes(.hardware, scope: scope) {
            body += card("#2f6bff", "Hardware", kv([
                ("Modelo", d.model), ("Chip", d.chip), ("Núcleos", String(d.cores)),
                ("Memória", d.memory), ("Disco", "\(d.diskFree) livres de \(d.diskTotal)"),
                ("Ciclos da bateria", d.batteryCycles),
            ]))
        }
        if includes(.system, scope: scope) {
            var inner = kv([("macOS", d.osVersion), ("Ativo há", d.uptime), ("IP local", d.localIP)])
            if let deep = d.deep {
                inner += kv([("Build do macOS", deep.osBuild), ("Kernel", deep.kernel),
                             ("Ligado desde", deep.bootTime), ("Fuso horário", deep.timezone),
                             ("Nome local", deep.localHostName)])
            }
            body += card("#5856d6", "Sistema", inner)
        }
        if includes(.software, scope: scope) {
            let list = detail == .detailed ? d.apps : Array(d.apps.sorted(by: { $0.sizeBytes > $1.sizeBytes }).prefix(15))
            let maxSize = d.apps.map(\.sizeBytes).max() ?? 1
            var inner = "<p class=\"muted\">\(d.apps.count) apps · Homebrew: \(d.brewPackages) · Atualizações pendentes: \(d.outdated) · Espaço em apps: \(ByteCountFormatter.string(fromByteCount: d.totalAppsSize, countStyle: .file))</p>"
            inner += "<table class=\"grid\"><tr><th>App</th><th>Versão</th><th>Tamanho</th><th>Origem</th></tr>"
            for a in list.sorted(by: { $0.sizeBytes > $1.sizeBytes }) {
                inner += "<tr><td>\(esc(a.name))</td><td>\(esc(a.version ?? "—"))</td><td>\(esc(a.sizeLabel))\(bar(a.sizeBytes, maxSize))</td><td>\(esc(a.source))</td></tr>"
            }
            inner += "</table>"
            body += card("#34c759", "Aplicativos", inner)
        }
        if includes(.security, scope: scope) {
            var inner = "<table class=\"grid\"><tr><th>Item</th><th>Estado</th><th>Detalhe</th></tr>"
            for c in d.security {
                let badge = c.ok ? "<span class=\"badge ok\">OK</span>" : "<span class=\"badge warn\">Atenção</span>"
                inner += "<tr><td>\(esc(c.name))</td><td>\(badge)</td><td>\(esc(c.detail))</td></tr>"
            }
            inner += "</table>"
            body += card("#ff3b30", "Segurança", inner)
        }
        if let deep = d.deep {
            if includes(.hardware, scope: scope) {
                body += card("#2f6bff", "Hardware detalhado", kv(
                    deep.gpu.map { ("GPU", $0) } + deep.displays.map { ("Monitor", $0) }
                    + (deep.batteryCondition.isEmpty ? [] : [("Bateria", deep.batteryCondition)])))
            }
            if includes(.system, scope: scope), !deep.interfaces.isEmpty {
                var inner = "<table class=\"grid\"><tr><th>Interface</th><th>IP</th><th>MAC</th></tr>"
                for i in deep.interfaces {
                    inner += "<tr><td>\(esc(i.name))</td><td>\(esc(i.ip.isEmpty ? "—" : i.ip))</td><td>\(esc(i.mac.isEmpty ? "—" : i.mac))</td></tr>"
                }
                inner += "</table>" + kv([("Gateway", deep.gateway), ("DNS", deep.dns.joined(separator: ", "))])
                body += card("#00c7be", "Rede detalhada", inner)
            }
            if includes(.software, scope: scope) {
                body += card("#30b0c7", "Ferramentas de linha de comando", kv(deep.runtimes.map { ($0.name, $0.version) }))
                body += card("#a2845e", "Homebrew instalado", kv([
                    ("Fórmulas (\(deep.brewFormulaeList.count))", deep.brewFormulaeList.joined(separator: ", ")),
                    ("Casks (\(deep.brewCasksList.count))", deep.brewCasksList.joined(separator: ", ")),
                ]))
                if !deep.installHistory.isEmpty {
                    let items = deep.installHistory.map { "<li>\(esc($0))</li>" }.joined()
                    body += card("#af52de", "Histórico de instalações", "<ul class=\"list\">\(items)</ul>")
                }
            }
            if includes(.personalization, scope: scope) {
                body += card("#ff9500", "Integridade e personalizações", kv([
                    ("Proteção do sistema (SIP)", deep.sip.isEmpty ? "—" : deep.sip),
                    ("Apps fora da App Store", String(deep.nonAppStoreApps)),
                    ("Homebrew", "\(deep.brewFormulae) fórmulas, \(deep.brewCasks) casks"),
                    ("/usr/local · /opt", "\(deep.hasUsrLocal ? "sim" : "não") · \(deep.hasOpt ? "sim" : "não")"),
                    ("Configs de shell", deep.shellDotfiles.joined(separator: ", ")),
                    ("Contas de usuário", deep.users.joined(separator: ", ")),
                    ("Itens de inicialização (não-Apple)", deep.startupItems.isEmpty ? "nenhum" : deep.startupItems.joined(separator: ", ")),
                    ("Itens de login", deep.loginItems.joined(separator: ", ")),
                    ("Extensões de sistema (terceiros)", deep.systemExtensions.isEmpty ? "nenhuma" : deep.systemExtensions.joined(separator: ", ")),
                ]))
            }
            if includes(.storage, scope: scope), !deep.folderSizes.isEmpty || !deep.largestFiles.isEmpty {
                let maxF = deep.folderSizes.map(\.bytes).max() ?? 1
                var inner = "<table class=\"grid\">"
                for f in deep.folderSizes.sorted(by: { $0.bytes > $1.bytes }) {
                    inner += "<tr><th>\(esc(f.name))</th><td>\(esc(f.sizeLabel))\(bar(f.bytes, maxF))</td></tr>"
                }
                inner += "</table>"
                if !deep.volumes.isEmpty { inner += kv(deep.volumes.map { ("Volume", $0) }) }
                if !deep.largestFiles.isEmpty {
                    inner += "<table class=\"grid\"><tr><th>Maiores arquivos</th><th>Tamanho</th></tr>"
                    for f in deep.largestFiles { inner += "<tr><td class=\"path\">\(esc(f.path))</td><td>\(esc(f.sizeLabel))</td></tr>" }
                    inner += "</table>"
                }
                body += card("#ffcc00", "Armazenamento", inner)
            }
            if includes(.hardware, scope: scope) {
                for raw in deep.rawSections {
                    let inner = "<details><summary>Ver saída completa</summary><pre>\(esc(raw.text))</pre></details>"
                    body += card("#8e8e93", raw.title, inner)
                }
            }
        }
        body += "<p class=\"foot\">Gerado localmente pelo Uptend. Nenhum dado foi enviado para fora.</p>"

        let css = """
        :root{--bg:#f4f5f7;--card:#fff;--ink:#1c1c1e;--muted:#6b7280;--line:#e6e8eb;--accent:#2f6bff;}
        @media(prefers-color-scheme:dark){:root{--bg:#1a1b1e;--card:#242629;--ink:#f2f2f4;--muted:#9aa0a6;--line:#34363b;--accent:#4d84ff;}}
        *{box-sizing:border-box;} body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;background:var(--bg);color:var(--ink);margin:0;padding:28px;line-height:1.5;}
        .wrap{max-width:900px;margin:0 auto;}
        .hero{background:linear-gradient(135deg,#2f6bff,#6a3bff);color:#fff;border-radius:16px;padding:22px 26px;margin-bottom:20px;}
        .hero h1{margin:0 0 3px;font-size:23px;} .hero .sub{opacity:.92;font-size:13px;}
        .chips{margin-top:12px;} .chip{display:inline-block;background:rgba(255,255,255,.18);border-radius:999px;padding:3px 11px;font-size:12px;margin:0 6px 4px 0;}
        .card{background:var(--card);border:1px solid var(--line);border-radius:14px;margin-bottom:14px;overflow:hidden;}
        .card>h2{margin:0;font-size:14px;font-weight:600;padding:11px 16px;border-bottom:1px solid var(--line);display:flex;align-items:center;gap:9px;}
        .ic{width:12px;height:12px;border-radius:4px;display:inline-block;}
        .body{padding:8px 16px 14px;}
        table{border-collapse:collapse;width:100%;font-size:13px;}
        .kv th{text-align:left;color:var(--muted);font-weight:500;padding:5px 8px;vertical-align:top;width:36%;}
        .kv td{padding:5px 8px;vertical-align:top;word-break:break-word;}
        .grid th{text-align:left;color:var(--muted);font-weight:600;padding:6px 8px;border-bottom:2px solid var(--line);font-size:12px;}
        .grid td{padding:6px 8px;border-bottom:1px solid var(--line);vertical-align:top;} .grid tr:hover td{background:rgba(127,127,127,.06);}
        .path{font-family:ui-monospace,Menlo,monospace;font-size:11px;word-break:break-all;}
        .badge{display:inline-block;padding:2px 9px;border-radius:999px;font-size:12px;font-weight:600;}
        .ok{background:rgba(52,199,89,.16);color:#1f9d4d;} .warn{background:rgba(255,149,0,.18);color:#b8690a;}
        .bar{height:6px;border-radius:4px;background:var(--line);overflow:hidden;margin-top:3px;max-width:260px;} .bar>span{display:block;height:100%;background:var(--accent);}
        .list{margin:4px 0;padding-left:18px;font-size:13px;} .list li{margin:2px 0;}
        .muted{color:var(--muted);font-size:12px;margin:2px 0 6px;} .foot{text-align:center;color:var(--muted);font-size:11px;margin-top:10px;}
        summary{cursor:pointer;color:var(--accent);font-size:13px;} pre{background:rgba(127,127,127,.08);padding:12px;border-radius:8px;overflow:auto;font-size:11px;line-height:1.4;max-height:420px;}
        @media print{body{background:#fff;padding:0;} .card,.hero{break-inside:avoid;} pre{max-height:none;} details{display:block;} details>summary{display:none;}}
        """
        return "<!doctype html><html lang=\"pt-BR\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>Inventário do Mac</title><style>\(css)</style></head><body><div class=\"wrap\">\(body)</div></body></html>"
    }
}
