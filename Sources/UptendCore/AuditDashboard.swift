import Foundation

// =============================================================================
// AUDITORIA EXTERNA — dashboard visual (nativo, para apresentar/imprimir/PDF)
// Página HTML autocontida com gráficos SVG e interatividade em JavaScript
// (filtro por servidor, hover). Usa o HISTÓRICO (várias auditorias) para mostrar
// a evolução no tempo. Sem rede, sem dependências externas → abre offline e
// imprime/vira PDF. Os dados vêm do SQLite do app; aqui só formatamos.
// =============================================================================

public enum AuditDashboard {

    private static func lightKey(_ l: AuditLight) -> String {
        switch l { case .green: "green"; case .yellow: "yellow"; case .red: "red" }
    }

    /// Monta o dashboard a partir de uma lista de auditorias (o histórico).
    public static func html(_ audits: [ExternalAudit]) -> String {
        var items: [[String: Any]] = []
        for audit in audits {
            let s = AuditScoring.evaluate(audit, topN: 6)
            let open = audit.findings.filter { $0.severity > .ok }.sorted {
                $0.severity != $1.severity ? $0.severity > $1.severity
                    : $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            items.append([
                "host": audit.host.hostname,
                "date": audit.collectedAt,
                "score": s.score,
                "light": lightKey(s.light),
                "counts": [
                    "critical": s.counts[.critical] ?? 0, "high": s.counts[.high] ?? 0,
                    "medium": s.counts[.medium] ?? 0, "low": s.counts[.low] ?? 0, "ok": s.counts[.ok] ?? 0,
                ],
                "categories": s.categories.map { ["name": $0.category, "light": lightKey($0.light), "count": $0.count] },
                // achados abertos com recomendação e impacto — para clicar e expandir na apresentação
                "findings": open.map { [
                    "title": $0.title, "sev": $0.severity.rawValue, "cat": $0.category,
                    "rec": $0.recommendation ?? "", "impact": $0.businessImpact ?? "",
                ] },
                "containers": audit.docker?.total ?? 0,
                "lynis": audit.lynis?.hardeningIndex as Any? ?? NSNull(),
                "os": audit.os?.pretty ?? audit.os?.distro ?? "",
                "eol": audit.os?.eolDate as Any? ?? NSNull(),
            ])
        }
        var json = (try? JSONSerialization.data(withJSONObject: items, options: [.sortedKeys]))
            .map { String(decoding: $0, as: UTF8.self) } ?? "[]"
        // O JSON vai dentro de <script>: um dado contendo "</script>" encerraria o
        // bloco e injetaria HTML/JS na página. Escapamos "<" no estilo unicode do JSON.
        json = json.replacingOccurrences(of: "<", with: "\\u003c")
        return page(dataJSON: json)
    }

    private static func page(dataJSON: String) -> String {
        // Atenção: o JS abaixo NÃO pode conter a sequência barra-invertida-parêntese
        // (interpolação do Swift). Só injetamos dados em DATA.
        """
        <!DOCTYPE html>
        <html lang="pt-BR"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Dashboard — Auditoria</title>
        <style>
        :root { --bg:#f2f2f5; --fg:#1d1d1f; --muted:#6b6b70; --card:#ffffff; --border:#e2e2e6; --shadow:0 1px 3px rgba(0,0,0,.07),0 1px 2px rgba(0,0,0,.04); }
        @media (prefers-color-scheme: dark) { :root { --bg:#141416; --fg:#f2f2f7; --muted:#98989f; --card:#242427; --border:#3a3a3c; --shadow:0 1px 3px rgba(0,0,0,.35); } }
        * { box-sizing:border-box; }
        body { margin:0; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif; background:var(--bg); color:var(--fg); line-height:1.5; }
        .wrap { max-width:1080px; margin:0 auto; padding:28px 24px 60px; }
        header { display:flex; align-items:center; justify-content:space-between; gap:16px; flex-wrap:wrap; margin-bottom:6px; }
        h1 { font-size:25px; margin:0; letter-spacing:-.3px; }
        h2 { font-size:15px; margin:0 0 12px; color:var(--muted); text-transform:uppercase; letter-spacing:.4px; font-weight:600; }
        .sub { color:var(--muted); font-size:14px; margin:4px 0 0; }
        .controls { display:flex; gap:10px; align-items:center; }
        select { font-size:14px; padding:7px 12px; border-radius:9px; border:1px solid var(--border); background:var(--card); color:var(--fg); box-shadow:var(--shadow); }
        section { margin-top:26px; }
        .card { background:var(--card); border:1px solid var(--border); border-radius:14px; padding:18px; box-shadow:var(--shadow); }
        .hero { display:flex; gap:26px; align-items:center; background:var(--card); border:1px solid var(--border); border-radius:16px; padding:22px 26px; box-shadow:var(--shadow); margin-top:16px; }
        .hero .ring { flex:0 0 auto; }
        .hmeta { flex:1; min-width:220px; }
        .verdict { font-size:22px; font-weight:700; letter-spacing:-.2px; }
        .hsub { color:var(--muted); font-size:14px; margin-top:2px; }
        .tiles { display:flex; gap:10px; margin-top:16px; flex-wrap:wrap; }
        .tile { background:var(--bg); border:1px solid var(--border); border-radius:11px; padding:11px 16px; min-width:92px; }
        .tile .tv { font-size:23px; font-weight:700; line-height:1.1; }
        .tile .tl { font-size:12px; color:var(--muted); margin-top:2px; }
        .cols2 { display:grid; grid-template-columns:1fr 1fr; gap:16px; align-items:start; }
        .cols2 section { margin-top:0; }
        .donut { display:flex; gap:20px; align-items:center; flex-wrap:wrap; }
        .lgs { display:flex; flex-direction:column; gap:7px; }
        .lg { font-size:13.5px; display:flex; align-items:center; gap:8px; }
        .lg b { margin-left:2px; }
        .cats { display:grid; grid-template-columns:repeat(auto-fill,minmax(180px,1fr)); gap:8px; }
        .cat { display:flex; align-items:center; gap:8px; background:var(--bg); border:1px solid var(--border); border-radius:9px; padding:9px 12px; font-size:13.5px; flex-wrap:wrap; cursor:pointer; }
        .cat .n { margin-left:auto; color:var(--muted); font-size:12px; font-weight:600; }
        .cat .chev, .risk .chev { color:var(--muted); transition:transform .18s; font-size:12px; }
        .cat.open .chev, .risk.open .chev { transform:rotate(90deg); }
        .cat .det, .risk .det { display:none; flex-basis:100%; width:100%; }
        .cat.open .det, .risk.open .det { display:block; }
        .cat .det { margin-top:8px; padding-top:8px; border-top:1px solid var(--border); }
        .cat .fi { display:flex; align-items:center; gap:8px; padding:4px 0; font-size:13px; }
        .risk .det { margin-top:8px; padding:11px 13px; background:var(--bg); border:1px solid var(--border); border-radius:9px; font-size:13.5px; line-height:1.55; }
        .risk .det .lb { color:var(--muted); font-weight:700; }
        .risk .det .row { margin:3px 0; }
        .risk .rt { flex:1; }
        .hint { color:var(--muted); font-size:12px; margin:2px 0 8px; }
        .dot { width:11px; height:11px; border-radius:50%; flex:0 0 auto; }
        .bars { display:flex; flex-direction:column; gap:9px; }
        .barrow { display:flex; align-items:center; gap:12px; font-size:14px; }
        .barrow .lbl { width:80px; color:var(--muted); }
        .barrow .track { flex:1; background:var(--bg); border:1px solid var(--border); border-radius:7px; height:18px; overflow:hidden; }
        .barrow .fill { display:block; height:100%; border-radius:7px 0 0 7px; transition:width .3s; }
        .barrow .n { width:30px; text-align:right; font-variant-numeric:tabular-nums; font-weight:700; }
        .risk { display:flex; align-items:center; gap:10px; padding:10px 0; border-bottom:1px solid var(--border); font-size:14px; flex-wrap:wrap; cursor:pointer; }
        .risk:last-child { border-bottom:none; }
        .risk:hover .rt { text-decoration:underline; }
        .tag { font-size:11px; font-weight:700; color:#fff; padding:2px 9px; border-radius:20px; white-space:nowrap; }
        .controls button { font-size:13px; padding:6px 12px; border-radius:8px; border:1px solid var(--border); background:var(--card); color:var(--fg); cursor:pointer; box-shadow:var(--shadow); }
        .controls button:hover { border-color:var(--muted); }
        .controls button.on { background:#3a7bd5; color:#fff; border-color:#3a7bd5; }
        body.present .wrap { max-width:1500px; }
        body.present h1 { font-size:34px; }
        body.present .verdict { font-size:30px; }
        body.present .tile .tv { font-size:30px; }
        body.present .tile .tl { font-size:14px; }
        body.present .risk, body.present .cat, body.present td, body.present th, body.present .lg { font-size:17px; }
        body.present .risk .det, body.present .cat .fi { font-size:16px; }
        body.present h2 { font-size:17px; }
        table { width:100%; border-collapse:collapse; font-size:13px; }
        th,td { text-align:left; padding:9px 10px; border-bottom:1px solid var(--border); }
        tr:last-child td { border-bottom:none; }
        th { color:var(--muted); font-weight:600; font-size:12px; text-transform:uppercase; letter-spacing:.3px; }
        .mini { display:inline-block; width:52px; height:7px; border-radius:4px; background:var(--bg); overflow:hidden; vertical-align:middle; margin-left:8px; }
        .mini > span { display:block; height:100%; }
        svg text { fill:var(--muted); font-size:11px; }
        .empty { color:var(--muted); padding:56px 0; text-align:center; font-size:15px; }
        @media (max-width:720px){ .cols2{grid-template-columns:1fr;} .hero{flex-direction:column;text-align:center;} }
        @media print { :root{ --bg:#fff; } body { background:#fff; } .controls { display:none; } .card,.hero,.cat,.tile { break-inside:avoid; box-shadow:none; } }
        </style></head>
        <body><div class="wrap">
        <header>
          <div><h1>Dashboard de Auditoria</h1><p class="sub" id="sub"></p></div>
          <div class="controls"><label>Servidor:&nbsp;</label><select id="srv"></select>
            <button id="btnPresent">Modo apresentação</button>
            <button id="btnFull">⛶ Tela cheia</button>
          </div>
        </header>
        <div id="root"></div>
        </div>
        <script>
        const DATA = \(dataJSON);
        const COLORS = {green:'#30a46c', yellow:'#e2a336', red:'#e5484d'};
        const SEV = {critical:'#e5484d', high:'#e5711a', medium:'#e2a336', low:'#3a7bd5', ok:'#30a46c'};
        const SEVL = {critical:'Crítica', high:'Alta', medium:'Média', low:'Baixa', ok:'OK'};
        const SEVORDER = ['critical','high','medium','low','ok'];
        const $ = id => document.getElementById(id);
        const esc = s => String(s).replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
        const fmt = iso => { const d = new Date(iso); return isNaN(d) ? String(iso).slice(0,10) : d.toLocaleDateString('pt-BR') + ' ' + d.toLocaleTimeString('pt-BR',{hour:'2-digit',minute:'2-digit'}); };
        const fmtShort = iso => { const d = new Date(iso); return isNaN(d) ? String(iso).slice(5,10) : d.toLocaleDateString('pt-BR',{day:'2-digit',month:'2-digit'}); };

        const hosts = [...new Set(DATA.map(d => d.host))].sort();
        function latestPerHost(){ const m = {}; DATA.forEach(d => { if(!m[d.host] || d.date > m[d.host].date) m[d.host] = d; }); return Object.values(m); }

        function init(){
          // Apresentação: clicar num risco/categoria expande (delegação — sobrevive a re-render).
          document.addEventListener('click', function(e){
            const el = e.target.closest('.risk, .cat');
            if(el && $('root').contains(el) && !e.target.closest('.det')) el.classList.toggle('open');
          });
          $('btnPresent').onclick = function(){ document.body.classList.toggle('present'); this.classList.toggle('on'); };
          $('btnFull').onclick = function(){
            if(!document.fullscreenElement){ if(document.documentElement.requestFullscreen) document.documentElement.requestFullscreen(); }
            else { if(document.exitFullscreen) document.exitFullscreen(); }
          };
          if(!DATA.length){ $('root').innerHTML = '<div class="empty">Nenhuma auditoria no histórico ainda. Importe ou colete uma na aba Importar/Coletar.</div>'; $('srv').style.display='none'; return; }
          const most = DATA.slice().sort((a,b)=>a.date.localeCompare(b.date)).pop();
          $('srv').innerHTML = '<option value="__all">Todos os servidores</option>' + hosts.map(h=>'<option>'+esc(h)+'</option>').join('');
          $('srv').value = most.host;
          $('srv').onchange = render;
          render();
        }

        function render(){
          const host = $('srv').value;
          const all = host === '__all';
          const rows = all ? [] : DATA.filter(d=>d.host===host).sort((a,b)=>a.date.localeCompare(b.date));
          const latest = all ? DATA.slice().sort((a,b)=>a.date.localeCompare(b.date)).pop() : rows[rows.length-1];
          $('sub').textContent = (all ? hosts.length+' servidores · '+DATA.length+' coletas' : host+' · '+rows.length+' coleta(s) · última '+fmt(latest.date));

          let html = hero(latest, all);
          html += section('Nota ao longo do tempo', all ? barsLatest() : lineChart(rows));
          html += '<div class="cols2">'
                + section('Risco por severidade', donut(latest.counts))
                + section('Situação por categoria', cats(latest))
                + '</div>';
          html += section('Principais riscos', risks(latest));
          html += section('Servidores', serversTable());
          $('root').innerHTML = html;
        }

        function section(title, inner){ return '<section><h2>'+esc(title)+'</h2>'+inner+'</section>'; }

        function polar(cx,cy,r,ang){ return [cx+r*Math.cos(ang), cy+r*Math.sin(ang)]; }

        function scoreRing(score, light){
          const R=54, C=2*Math.PI*R, off=C*(1-Math.max(0,Math.min(100,score))/100);
          let s='<svg viewBox="0 0 140 140" width="132" height="132">';
          s+='<circle cx="70" cy="70" r="'+R+'" fill="none" stroke="var(--bg)" stroke-width="13"/>';
          s+='<circle cx="70" cy="70" r="'+R+'" fill="none" stroke="'+COLORS[light]+'" stroke-width="13" stroke-linecap="round" stroke-dasharray="'+C.toFixed(1)+'" stroke-dashoffset="'+off.toFixed(1)+'" transform="rotate(-90 70 70)"/>';
          s+='<text x="70" y="72" text-anchor="middle" font-size="38" font-weight="700" fill="var(--fg)">'+score+'</text>';
          s+='<text x="70" y="94" text-anchor="middle" font-size="12">de 100</text></svg>';
          return s;
        }

        function hero(latest, all){
          const c = latest.counts;
          const verdict = latest.light==='green' ? 'Postura sólida'
                        : (latest.light==='yellow' ? 'Precisa de atenção' : 'Ação urgente recomendada');
          const tiles = [
            ['Críticos', c.critical, c.critical? SEV.critical : 'var(--fg)'],
            ['Altos', c.high, c.high? SEV.high : 'var(--fg)'],
            ['Abertos', c.critical+c.high+c.medium+c.low, 'var(--fg)'],
            ['Containers', latest.containers, 'var(--fg)'],
            ['Lynis', latest.lynis==null?'—':latest.lynis, 'var(--fg)'],
          ];
          let t = tiles.map(x=>'<div class="tile"><div class="tv" style="color:'+x[2]+'">'+esc(String(x[1]))+'</div><div class="tl">'+esc(x[0])+'</div></div>').join('');
          return '<div class="hero"><div class="ring">'+scoreRing(latest.score, latest.light)+'</div>'
               + '<div class="hmeta"><div class="verdict" style="color:'+COLORS[latest.light]+'">'+esc(verdict)+'</div>'
               + '<div class="hsub">'+esc(latest.os||'')+'</div>'
               + '<div class="tiles">'+t+'</div></div></div>';
        }

        function donut(counts){
          const total = SEVORDER.reduce((a,k)=>a+counts[k],0) || 1;
          const open = counts.critical+counts.high+counts.medium+counts.low;
          let a0=-Math.PI/2, segs='';
          SEVORDER.forEach(k=>{ const v=counts[k]; if(!v) return;
            const frac=v/total, a1=a0+frac*2*Math.PI;
            const p0=polar(70,70,58,a0), p1=polar(70,70,58,a1), large=frac>0.5?1:0;
            if(frac>=0.999){ segs+='<circle cx="70" cy="70" r="58" fill="'+SEV[k]+'"><title>'+SEVL[k]+': '+v+'</title></circle>'; }
            else { segs+='<path d="M70,70 L'+p0[0].toFixed(1)+','+p0[1].toFixed(1)+' A58,58 0 '+large+' 1 '+p1[0].toFixed(1)+','+p1[1].toFixed(1)+' Z" fill="'+SEV[k]+'"><title>'+SEVL[k]+': '+v+'</title></path>'; }
            a0=a1; });
          segs+='<circle cx="70" cy="70" r="36" fill="var(--card)"/>';
          segs+='<text x="70" y="68" text-anchor="middle" font-size="26" font-weight="700" fill="var(--fg)">'+open+'</text>';
          segs+='<text x="70" y="86" text-anchor="middle" font-size="11">achados</text>';
          const legend = SEVORDER.filter(k=>counts[k]).map(k=>'<div class="lg"><span class="dot" style="background:'+SEV[k]+'"></span>'+SEVL[k]+' <b>'+counts[k]+'</b></div>').join('');
          return '<div class="card donut"><svg viewBox="0 0 140 140" width="140" height="140">'+segs+'</svg><div class="lgs">'+(legend||'<span style="color:var(--muted)">Sem achados abertos 🎉</span>')+'</div></div>';
        }

        function lineChart(rows){
          if(rows.length < 2) return '<div class="card">Só há uma coleta deste servidor — colete de novo mais tarde para ver a evolução.</div>';
          const W=920, H=220, P=32, iw=W-P*2, ih=H-P*2;
          const n=rows.length, dx = n>1 ? iw/(n-1) : 0;
          const x=i=>P+dx*i, y=v=>P+ih-(v/100)*ih;
          let pts=rows.map((r,i)=>[x(i),y(r.score)]);
          let poly=pts.map(p=>p[0].toFixed(1)+','+p[1].toFixed(1)).join(' ');
          let g='';
          [0,25,50,75,100].forEach(v=>{ const yy=y(v); g+='<line x1="'+P+'" y1="'+yy.toFixed(1)+'" x2="'+(W-P)+'" y2="'+yy.toFixed(1)+'" stroke="var(--border)" stroke-width="1"/><text x="'+(P-6)+'" y="'+(yy+3).toFixed(1)+'" text-anchor="end">'+v+'</text>'; });
          let dots=rows.map((r,i)=>'<circle cx="'+x(i).toFixed(1)+'" cy="'+y(r.score).toFixed(1)+'" r="4" fill="'+COLORS[r.light]+'"><title>'+esc(fmt(r.date))+' — '+r.score+'/100</title></circle>').join('');
          let labs=rows.map((r,i)=> (n<=12 || i%Math.ceil(n/12)===0) ? '<text x="'+x(i).toFixed(1)+'" y="'+(H-8)+'" text-anchor="middle">'+esc(fmtShort(r.date))+'</text>' : '').join('');
          return '<div class="card"><svg viewBox="0 0 '+W+' '+H+'" width="100%">'+g+'<polyline points="'+poly+'" fill="none" stroke="#3a7bd5" stroke-width="2.5"/>'+dots+labs+'</svg></div>';
        }

        function barsLatest(){
          const rows = latestPerHost().sort((a,b)=>b.score-a.score);
          const max = 100;
          return '<div class="card bars">'+rows.map(r=>{
            const pct = Math.max(3, r.score);
            return '<div class="barrow"><span class="lbl" style="width:140px">'+esc(r.host)+'</span><span class="track"><span class="fill" style="width:'+pct+'%;background:'+COLORS[r.light]+'"></span></span><span class="n">'+r.score+'</span></div>';
          }).join('')+'</div>';
        }

        function severityBars(d){
          const max = Math.max(1, ...SEVORDER.map(k=>d.counts[k]));
          return '<div class="card bars">'+SEVORDER.map(k=>{
            const v=d.counts[k]; const pct = v===0?0:Math.max(6, Math.round(v/max*100));
            return '<div class="barrow"><span class="lbl">'+SEVL[k]+'</span><span class="track"><span class="fill" style="width:'+pct+'%;background:'+SEV[k]+'"></span></span><span class="n">'+v+'</span></div>';
          }).join('')+'</div>';
        }

        function cats(d){
          if(!d.categories.length) return '<div class="card">—</div>';
          const fs = d.findings || [];
          return '<div class="cats">'+d.categories.map(c=>{
            const inCat = fs.filter(f=>f.cat===c.name);
            const det = inCat.length
              ? '<div class="det">'+inCat.map(f=>'<div class="fi"><span class="tag" style="background:'+SEV[f.sev]+'">'+SEVL[f.sev]+'</span>'+esc(f.title)+'</div>').join('')+'</div>'
              : '<div class="det"><div class="fi" style="color:var(--muted)">Tudo conforme nesta área. 🎉</div></div>';
            const chev = inCat.length ? '<span class="chev">▶</span>' : '';
            return '<div class="cat"><span class="dot" style="background:'+COLORS[c.light]+'"></span>'+esc(c.name)+'<span class="n">'+c.count+'</span>'+chev+det+'</div>';
          }).join('')+'</div>';
        }

        function risks(d){
          const fs = (d.findings || []);
          if(!fs.length) return '<div class="card">Sem riscos relevantes. 🎉</div>';
          const top = fs.slice(0, 8);
          const cards = top.map(f=>{
            const rec = f.rec ? '<div class="row"><span class="lb">O que fazer:</span> '+esc(f.rec)+'</div>' : '';
            const imp = f.impact ? '<div class="row"><span class="lb">Impacto no negócio:</span> '+esc(f.impact)+'</div>' : '';
            const body = (rec||imp) || '<div class="row" style="color:var(--muted)">Sem detalhes adicionais para este achado.</div>';
            return '<div class="risk"><span class="tag" style="background:'+SEV[f.sev]+'">'+SEVL[f.sev]+'</span><span class="rt">'+esc(f.title)+'</span><span class="chev">▶</span><div class="det">'+body+'</div></div>';
          }).join('');
          const more = fs.length>8 ? '<div class="hint">+ '+(fs.length-8)+' outro(s) achado(s) — veja por categoria ao lado ou no relatório técnico.</div>' : '';
          return '<div class="card"><div class="hint">Clique num risco para ver o que fazer e o impacto no negócio.</div>'+cards+more+'</div>';
        }

        function serversTable(){
          const rows = latestPerHost().sort((a,b)=>a.host.localeCompare(b.host));
          return '<div class="card"><table><thead><tr><th>Servidor</th><th>Nota</th><th>Última coleta</th><th>SO</th><th>EOL</th><th>Containers</th></tr></thead><tbody>'+
            rows.map(r=>'<tr><td><b>'+esc(r.host)+'</b></td><td style="color:'+COLORS[r.light]+';font-weight:700">'+r.score+'<span class="mini"><span style="width:'+Math.max(3,r.score)+'%;background:'+COLORS[r.light]+'"></span></span></td><td>'+esc(fmt(r.date))+'</td><td>'+esc(r.os||'—')+'</td><td>'+esc(r.eol||'—')+'</td><td>'+r.containers+'</td></tr>').join('')+
            '</tbody></table></div>';
        }

        init();
        </script>
        </body></html>
        """
    }
}
