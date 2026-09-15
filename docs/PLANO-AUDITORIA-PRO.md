# Plano — Profissionalização da Auditoria (nível empresarial)

> Roteiro **vivo** para elevar o módulo de **Auditoria Externa** do Uptend de "excelente ferramenta de analista/consultor" (~78/100 como entregável) para **plataforma de nível empresarial**. Registro para consulta e para não esquecer nada. Respeita o `PADROES.md` (testes + segurança + privacidade + Definition of Done). Detalhe de execução conforme a gente for concluindo migra para `HISTORICO.md`.
>
> **Criado:** 2026-07-21 · **Status:** planejado

## Como usar
- Marcar `[x]` conforme concluir; anotar no `HISTORICO.md`.
- Legenda de **prioridade**: 🔴 alta · 🟡 média · ⚪ futura.
- Legenda de **esforço**: `S` (horas) · `M` (1–2 dias) · `L` (dias/semana).
- Cada item traz: **o que fazer**, **notas técnicas** (onde mexer), **critério de aceite**.

---

## Nota atual (baseline honesto)
- **Entregável/relatório:** ~78/100 corporativo.
- **Plataforma completa:** ~50/100.
- **Gap principal:** assinatura/integridade, white-label, profundidade de evidência, frota, nuvem/Windows, fluxo de remediação/GRC.

## Estado atual do módulo (o que já existe — não refazer)
- Coletor read-only (~35 checks) + schema v1 + Vault (SQLite) + histórico/retenção.
- 7 frameworks: CIS Benchmarks, ISO 27001, NIST CSF, OWASP Top 10, PCI-DSS, CIS Controls v8, SOC 2 (`ComplianceMap`).
- 3 relatórios diferenciados (Executivo/SOC/Técnico) + Markdown + comparação entre auditorias + dashboard nativo (HTML/JS).
- MITRE ATT&CK (`MitreMap`), comandos de correção (`RemediationMap`), maturidade, "o que está em jogo", pontuação por área (`AuditDomains`).
- Acabamento profissional: classificação CONFIDENCIAL, metadados, metodologia, legenda.
- Scanner TLS nativo (Network.framework, sem nmap) — modo pentester opt-in, integra achados ao relatório+nota.

---

# FASE A — Relatório 78 → 90%+ ✅ CONCLUÍDA (A1–A4) 🔴

### A1. White-label / marca do entregável ✅ FEITO (2026-07-21) `M`
- **O quê:** capa/cabeçalho com **logo do cliente**, nome/e-mail/credencial do **auditor**, nome do **cliente/engajamento**, **aviso de confidencialidade editável**, número/versão do relatório.
- **Notas técnicas:** nova struct `ReportBranding` (logo em base64 data-URI, auditor, cliente, aviso). Tela de config (Configurações › "Relatório / Marca") persistida em UserDefaults (ou no Vault). Injetar no cabeçalho dos 3 relatórios (`AuditReport`), com fallback para o layout atual. Logo embutido como data-URI (mantém autocontido/offline).
- **Aceite:** gerar um relatório com logo + dados do auditor/cliente visíveis na capa; sem logo, volta ao layout atual; HTML continua bem-formado e offline.

### A2. Assinatura digital / integridade do relatório ✅ FEITO (2026-07-21) `M`
- **O quê:** tornar o relatório/JSON **à prova de adulteração** (cadeia de custódia real, não só hash).
- **Notas técnicas:** gerar par de chaves no Keychain (P-256 via CryptoKit `P256.Signing`), **assinar** o JSON da auditoria + o HTML/PDF; embutir assinatura + chave pública + fingerprint no rodapé e num arquivo `.sig`. Verificador na importação ("assinatura válida ✓"). Documentar em `DECISOES.md`.
- **Aceite:** relatório traz bloco "Assinado digitalmente por <auditor> · <fingerprint>"; alterar 1 byte do JSON invalida a verificação; teste unitário de assinar/verificar/detectar adulteração.

### A3. Evidência bruta anexada por achado ✅ FEITO (2026-07-21) `M`
- **O quê:** cada achado pode carregar a **saída bruta do comando** que o gerou (reprodutibilidade que auditor exige).
- **Notas técnicas:** coletor guarda evidência estendida (`evidence_raw` opcional por achado; cuidado com segredos — reusar `redactedDisplay`/redação). Schema: campo opcional. Relatório técnico mostra em bloco colapsável (`<details>`). Limitar tamanho.
- **Aceite:** relatório técnico tem "ver evidência" que expande a saída real; segredos redigidos; nada quebra se ausente.

### A4. Registro de risco (risk register) ✅ FEITO (2026-07-21) `M`
- **O quê:** exportar achados como **risco de GRC**: ID, descrição, probabilidade × impacto (matriz), dono, tratamento (mitigar/aceitar/transferir), risco residual.
- **Notas técnicas:** `RiskRegister` (UptendCore, puro): deriva probabilidade/impacto da severidade + categoria; matriz 5×5. Export CSV/HTML + seção no executivo. Editável (dono/tratamento) — persistir por achado no Vault.
- **Aceite:** exportar um risk register CSV/HTML com matriz colorida; itens editáveis persistem; testes da matriz.

---

# FASE B — GRC / Compliance 🔴🟡

### B1. Modo "gap assessment" por framework + SoA 🔴 `L` — ✅ FEITO (2026-07-21)
- **O quê:** escolher um framework (ISO 27001 / SOC 2 / PCI) e mapear **TODOS** os controles — **coberto / parcial / não-avaliado / manual** — gerando algo tipo **Declaração de Aplicabilidade (SoA)**.
- **Notas técnicas:** catálogo completo de controles por framework (ISO 27001 Anexo A ~93 controles v2022; PCI 12 requisitos; SOC 2 CC). Cruzar com o que a auditoria cobre (via `ComplianceMap`). Status "manual" para controles que exigem processo/política (não automatizáveis). Relatório SoA (HTML/CSV) com % de cobertura real + justificativa por controle.
- **Aceite:** escolher ISO 27001 → tabela de todos os controles com status; % coberto/parcial/manual; export SoA; honesto sobre o que é automatizável vs manual.
- **Implementado:** `ComplianceCatalog` (Core): catálogo **ISO 27001:2022 Anexo A completo (93 controles)** em PT com tema (Organizacional/Pessoas/Físico/Tecnológico) e natureza (automatizável/manual); mapa de transição 2013→2022 dos refs que o `ComplianceMap` emite; `soaISO27001` cruza catálogo × achados → status (Coberto/Não conforme/Não avaliado/Manual/Não aplicável); `summary` com % sobre verificado e % sobre escopo automatizável; CSV. `AuditReport.soaHTML` (resumo por status + tabela completa por tema + "como ler"). UI: card "Declaração de Aplicabilidade (SoA)" em Relatórios com contadores por status e Ver/PDF/CSV. Verificado no lab: 93 controles → 2 cobertos, 12 não conformes, 8 não avaliados, 71 manuais; HTML bem-formado. 340 testes. **Escopo v1: só ISO 27001; PCI/SOC 2 catálogos completos ficam para depois.**

### B2. Aceitação de risco / exceções 🔴 `M` — ✅ FEITO (2026-07-21)
- **O quê:** marcar achado como **"risco aceito"** com justificativa + data de validade → sai da nota (mas fica registrado).
- **Notas técnicas:** store de exceções no Vault (achado id + host + justificativa + validade + quem aceitou). `AuditScoring` ignora exceções vigentes na nota; relatório lista "Riscos aceitos" à parte. Expirar exceção volta a contar.
- **Aceite:** aceitar um achado com validade → some da nota e do plano de ação, aparece em "Riscos aceitos"; ao expirar, volta; testes.
- **Implementado:** `RiskException` + `RiskExceptions` (Core, lógica pura: `effective`/`accepted`/`expired`, datas ISO). `RiskExceptionStore` (app, UserDefaults por host = machineID??hostname). UI em Relatórios: card "Aceitação de risco" (lista riscos abertos → botão Aceitar → sheet com justificativa/responsável/validade/referência; lista aceitos com Revogar; aviso de expirados). Efetivo aplicado a Executivo+SOC+Registro de Risco (nota e matriz); Técnico mantém inventário completo. Seção "Riscos aceitos (exceções formais)" no relatório de risco. 332 testes.

### B3. Monitoramento contínuo + detecção de desvio (drift) 🟡 `M` — ✅ FEITO parcial (2026-07-21)
- **O quê:** alertar quando a **postura piora** (nota cai, novo achado crítico) entre coletas.
- **Notas técnicas:** reusar `AuditCompare`; agendamento (cron/Timer) de coleta recorrente por host; regra de alerta (delta < -X, novo crítico) → notificação (ToastCenter/NotificationCenter do Mac). Requer o atalho de coleta agendada.
- **Aceite:** configurar coleta recorrente + limiar; ao piorar, notifica com o que mudou; histórico registra.
- **Implementado (v1 — detecção):** `DriftAnalysis` (Core, puro): reusa `AuditCompare` → `DriftReport` com nível (Melhorou/Estável/Atenção/Crítico), regras (novo achado alto/crítico = Crítico; queda de nota ≥15 = Crítico, ≥5 = Atenção; novo achado leve = Atenção) e razões em PT. `ExternalAuditService.previousAudit(for:)` acha a coleta anterior do mesmo host (por machineID??hostname + collectedAt). Banner de desvio no **Painel** (cor + delta de nota + o que mudou + novos achados severos). 344 testes. **Falta (v2): agendamento de coleta recorrente + notificação do macOS (UNUserNotification) — precisa do atalho de coleta agendada.**

### B4. Baseline como código 🟡 `L` — ✅ FEITO (2026-07-21)
- **O quê:** definir o **baseline da empresa** (quais controles são obrigatórios/valores esperados) e medir o **desvio**.
- **Notas técnicas:** arquivo de baseline (YAML/JSON) versionável; comparar cada auditoria contra o baseline; relatório de conformidade ao baseline. Perto de "policy-as-code".
- **Aceite:** carregar um baseline → relatório mostra conformidade/desvio por item.
- **Implementado:** `Baseline`/`BaselineItem` (Codable/JSON versionável) + `BaselineEngine` (Core): `generate(from:)` captura os controles avaliados; `assess` → status Conforme/Desvio/Não avaliado; `summary` (%, desvios obrigatórios, aprovado/reprovado); CSV. **Identidade canônica de controle** `ComplianceMap.controlKey` (alias unificando pares conforme/não-conforme que não compartilham token: firewall-ok/firewall-inactive, umask-strict-ok/umask-loose, uid0-unique-ok/uid0-multiple, updates-ok/updates-pending, mac-*, auditd-*, fail2ban-*, rootkit-*, kernel-net-*, fw-default-*, auto-updates-*) — senão baseline de máquina boa não casaria com máquina ruim. `AuditReport.baselineHTML` (veredito APROVADO/REPROVADO + tabela). `BaselineStore` (app, UserDefaults + carregar/salvar JSON). Subseção **"Relatórios › Baseline"** (`BaselineView`): gerar desta auditoria / carregar / salvar arquivo, e card de conformidade da auditoria carregada Ver/PDF/CSV. Ideal p/ consultoria sob demanda (baseline portátil entre clientes). 351 testes.

---

# FASE C — Analista / SOC 🟡

### C1. Enriquecimento de CVE (versões → vulnerabilidades) 🔴 `L` — ✅ FEITO v1 (2026-07-21)
- **O quê:** cruzar versões de software detectadas com base de **CVE** (+ EPSS/exploitabilidade) → "esse serviço tem CVE-X crítica".
- **Notas técnicas:** coletor colhe versões (pacotes, imagens). Base de vulnerabilidades **local** (baixar/atualizar OSV/NVD feed — decidir: bundle offline vs download sob demanda; respeitar "sem exfiltração" no coletor — o cruzamento é no Mac). Sério de fazer bem; começar por serviços expostos.
- **Aceite:** um serviço com versão vulnerável conhecida vira achado com o CVE + severidade; fonte offline/local.
- **Implementado:** coletor (v1.1.0) colhe versões via `--version` LOCAL (openssh, openssl, nginx, apache, sudo, bash — sem rede) → campo `software` no schema (opcional, retrocompatível, `SoftwarePackage`). Core `CVE`/`CVEDatabase` (base curada offline ~10 CVEs de alto impacto: regreSSHion, Heartbleed, Baron Samedit, sudoedit, path traversal Apache, resolver nginx, Shellshock…) + `CVEMatcher` (comparador de versão tolerante a `9.6p1`/`1.0.1f`; faixas [introduzida,corrigida); também extrai software de imagens Docker). `AuditReport.cveHTML` + card na tela Relatórios. **Honestidade embutida:** marca "EXPOSIÇÃO POTENCIAL — confirme backport da distro" (distro corrige sem mudar versão upstream), não injeta na nota/matriz (separado, informativo), e deixa claro que é subconjunto curado, não NVD completo. Não roda rede no coletor. 364 testes. **Falta v2:** base maior/atualizável (OSV feed), EPSS, mais pacotes, versões de pacotes do host (dpkg/rpm).

### C2. Geração de conteúdo de detecção (Sigma/Falco) 🟡 `M` — ✅ FEITO (2026-07-22)
- **O quê:** a partir dos achados, gerar **regras Sigma/Falco** prontas ("alerte para força-bruta SSH", "acesso a /etc/shadow").
- **Notas técnicas:** templates por achado (mapeado via MITRE). Export de arquivos de regra. Puro/testável.
- **Aceite:** exportar um pacote de regras Sigma/Falco derivado dos achados abertos.

### C3. Integrações de saída (SIEM / ticketing) 🟡 `L`
- **O quê:** exportar para **SIEM** (JSON/CEF) e abrir **tickets** (Jira/ServiceNow) a partir dos achados.
- **Notas técnicas:** export CEF/JSON (offline). Ticketing exige rede + credenciais (Keychain) + confirmação de envio (regra de segurança: envio externo pede consentimento). Começar por export de arquivo; integração ativa depois.
- **Aceite:** exportar findings em CEF/JSON; (fase 2) criar ticket com confirmação.

---

# FASE D — Arquiteto de segurança 🟡

### D1. Frota / multi-host roll-up 🔴 `L` — ✅ FEITO (2026-07-22)
- **O quê:** auditar **N hosts** e ver o **mapa de conformidade** organizacional (quem está mais fraco, aderência ao baseline, heatmap).
- **Notas técnicas:** o Vault já guarda por host; criar visão "Frota" (agrega últimas auditorias de todos os hosts): tabela + heatmap por área/framework + nota média + piores. Relatório executivo de frota. Coleta em lote (rodar coletor em vários hosts).
- **Aceite:** tela Frota com todos os hosts, nota, piores áreas; relatório consolidado; coleta em lote.
- **Implementado:** `FleetRollup` (Core, puro): `latestPerHost` (dedup por machineID/hostname, mais recente), `rollup` → `Fleet` (hosts ordenados pior→melhor, nota média, distribuição semáforo, heatmap host×área via `AuditDomains`, achados mais comuns por chave-base canônica) + CSV. `AuditReport.fleetHTML` (panorama + heatmap + tabela de hosts + top achados). Nova seção **"Frota"** (`FleetView`) na aba Auditoria: cards de resumo, heatmap interativo, lista de hosts clicável (abre o painel do host), top achados, Ver/PDF/CSV, e **coleta em lote** ("Coletar de todos os hosts"). Validado com os 9 hosts reais do lab (nota média 32, piores = vuln). 369 testes.

### D2. Playbook de hardening (Ansible/bash com rollback) 🟡 `M` — ✅ FEITO (2026-07-22)
- **O quê:** transformar os comandos de `RemediationMap` num **script revisável, idempotente, com rollback** — corrigir em lote com aprovação.
- **Notas técnicas:** gerar playbook Ansible (ou bash com backup/rollback) a partir dos achados abertos selecionados. NÃO executa automático — gera para revisão (postura read-only por padrão). Reusar redação de segredos.
- **Aceite:** exportar playbook dos achados escolhidos; cada tarefa tem backup/rollback; nunca roda sozinho.

### D3. Mapa de superfície de ataque 🟡 `M`
- **O quê:** visual do que está **exposto e onde** (portas, serviços, TLS) — diagrama de superfície.
- **Notas técnicas:** reusar dados de portas expostas + varredura TLS + docker. Diagrama SVG no relatório/painel.
- **Aceite:** painel/relatório com o mapa de exposição do servidor.

---

# FASE E — Expansão de escopo (vira plataforma) ⚪

### E1. Nuvem / CSPM (AWS/Azure/GCP) ⚪ `L`
- **O quê:** auditar configuração de nuvem (CIS cloud benchmarks) — enorme em GRC hoje.
- **Notas técnicas:** SDK/API read-only por provedor; credenciais no Keychain; começar por AWS (IAM, S3 público, security groups, CloudTrail). Grande esforço; posiciona como arquiteto.
- **Aceite:** conectar uma conta AWS read-only → achados CIS de nuvem no mesmo formato/relatórios.

### E2. Windows Server ⚪ `L`
- **O quê:** coletor equivalente para Windows (via PowerShell/WinRM).
- **Notas técnicas:** coletor `.ps1` read-only (mesma filosofia do bash) → mesmo schema. SSH/WinRM.
- **Aceite:** auditar um Windows Server → mesmos relatórios.

### E3. Kubernetes / imagens de container ⚪ `L`
- **O quê:** CIS Kubernetes + **CVE de imagens** de container (já temos Docker).
- **Aceite:** achados de k8s/imagens no mesmo formato.

### E4. Bancos de dados + LGPD 🟡 `L` — ✅ v1 FEITO (2026-07-22)
- **Implementado v1 (modo estrutura):** Core `DatabaseSchema` (tabelas/colunas/tipos/chaves/índices, Codable) + `DatabaseAudit` (achados: senha/PII forte em texto plano=alto, PII comum=médio, sem PK/FK-sem-índice=baixo; heurística por nome+tipo, nunca lê dado; `makeAudit` transforma o BD num alvo de auditoria) + domínio "Banco de dados" no `AuditDomains`. **Origem 1 — arquivo SQLite:** `SQLiteSchemaReader` (app, só `sqlite_master`+`pragma_*`, read-only) + subseção **"Banco de dados"** em Importar/Coletar (anexar → ver achados → Adicionar à auditoria). **Origem 2 — Postgres no servidor:** coletor (v1.1.5) com `UPTEND_DB_AUDIT=1` extrai schema via `sudo -u postgres psql` (só `information_schema`, JSON montado pelo próprio PG) → campo `databases` no schema; `ExternalAudit.enrichedWithDatabaseFindings()` deriva os achados na ingestão; tique "Auditar bancos" nas Opções da coleta. Verificado no lab (SQLite + Postgres na ubuntu-vuln, sem ler dado). **v2 ✅ (2026-07-22):** credencial de banco no cadastro do host (Keychain, engine picker Postgres/MySQL) + bastion/ProxyJump (`RemoteHost.jumpHost`, ssh `-J`); **MySQL/MariaDB** no coletor v1.1.6 (`information_schema`, peer/senha `UPTEND_MY_*`); **lente LGPD** (`LGPDLens`+`AuditReport.lgpdHTML`, mapeia achados aos art. 46/6/37, atravessa sistema+banco); **modo Completo** SQLite (amostra só colunas de senha em memória, confirma hash vs texto plano). 382 testes. **Falta:** modo completo no servidor, charset/engine legado, mais heurísticas PII.
- **O quê:** auditar bancos (Postgres/MySQL/SQLite) com foco em **hardening + LGPD**, sem violar privacidade.
- **Arquitetura (DECIDIDA):** fica **DENTRO de Auditoria Externa**, NÃO é aba separada nem renomeia. Achados de BD entram como domínio **"Banco de dados"** na MESMA auditoria (herdam nota/matriz/risk register/SoA/frota). **LGPD vira uma LENTE de framework** (como ISO/PCI no SoA) — um "Relatório LGPD" que atravessa TODOS os achados (sistema + banco), não um silo só de BD.
- **Dois eixos:**
  - **MODO (privacidade):** 🔒 *Estrutura* (padrão, LGPD-safe) — lê só `information_schema`/catálogo (tabelas, colunas, tipos, chaves, índices, charset, engine, usuários, permissões). **NUNCA `SELECT` em dado.** 🔓 *Completo* (só no Mac do usuário ou c/ autorização assinada) — amostra dados (`LIMIT n`, em memória) p/ confirmar hash vs texto plano, PII, integridade. **Nada armazenado — só achados derivados (contagens), jamais o dado.**
  - **ORIGEM:** *servidor via SSH* (coletor roda a query de schema LOCALMENTE no servidor, user read-only → só schema volta no JSON, sem exfiltração); *BD local do Mac* (conexão direta, modo completo liberado); *arquivo anexado* (SQLite ou dump `.sql` só de schema, 100% local).
- **Entradas na UI:** (1) tique nas **Opções da coleta** ("Auditar bancos — só estrutura, LGPD-safe") ao lado de Lynis/varredura; (2) nova subseção **"Banco de dados"** em Importar/Coletar p/ anexar arquivo / conectar BD local.
- **Achados:** TLS na conexão; colunas com cara de PII (cpf/email/senha/cartão) em texto plano → alerta LGPD; `senha` VARCHAR (provável texto plano); contas do BD (root remoto, sem senha, GRANT ALL); estrutura (sem PK/FK, sem índice, charset latin1 legado, engine MyISAM). Mapeados a **LGPD / PCI-DSS req.3 / ISO A.8**.
- **Privacidade (engenharia, não promessa):** modo estrutura usa só metadados → impossível ler linha; credenciais no Keychain/user read-only, nunca em log (redação); Vault guarda só achado.
- **v1 sugerido:** Modo Estrutura + **arquivo SQLite anexado** (100% local, app já usa SQLite no Vault) OU **Postgres no servidor** (LGPD-safe, já tem no lab). MySQL + modo completo + lente LGPD completa vêm depois.
- **Aceite:** anexar um SQLite (ou coletar BD do servidor em modo estrutura) → achados de BD/LGPD no mesmo relatório/nota, sem ler nenhum dado.

---

# FASE F — Produto / ergonomia ⚪

- **F1. Internacionalização (EN)** ⚪ `M` — relatórios e interface em inglês (clientes internacionais).
- **F2. Modo CLI/headless** ⚪ `M` — rodar coleta/relatório por linha de comando (pipeline/CI).
- **F3. Templates de relatório customizáveis** ⚪ `M` — o usuário edita seções/ordem/estilo.

---

# Backlog curto (itens já anotados, pequenos)
- [ ] **STARTTLS** no scanner nativo (hoje só TLS direto: 443/993/8443…). Falta SMTP/IMAP (587/143). `S–M`
- [ ] Atalho **"Auditar este servidor"** direto da barra do host remoto (HomeLab/Servidor). `S`
- [ ] Plugar mais abas do **Este Mac** no Vault (scans de segurança, limpeza) — histórico unificado. `M`
- [ ] Testar **SELinux** num Fedora Server real (hoje só validado AppArmor no lab Ubuntu). `S`
- [ ] Mais checks de hardening conforme surgirem (partições, PAM avançado, sysctls extras). `S` cada

---

# Sequência recomendada (minha sugestão)
1. **A1 White-label + A2 Assinatura** → entregável "de consultoria" na hora (maior salto de percepção).
2. **B2 Aceitação de risco/exceções** → imprescindível em auditoria real.
3. **A4 Risk register + B1 Gap assessment/SoA** → fecha o pacote de GRC.
4. **A3 Evidência bruta** → reprodutibilidade/defensabilidade.
5. **D1 Frota** → muda a escala do produto.
6. Depois: **C1 CVE**, **E1 CSPM** (maior mercado), demais.

# Decisões em aberto (resolver antes de cada item)
- **A2:** onde guardar a chave privada (Keychain) e como distribuir a pública para verificação por terceiros.
- **C1:** base de CVE **bundle offline** vs **download sob demanda** (impacta tamanho do app e a regra "sem exfiltração").
- **C3/E1:** integrações que enviam dados para fora → **sempre com consentimento explícito** (regra de segurança do projeto).
- **B4:** formato do baseline (YAML vs JSON) e como versionar.
