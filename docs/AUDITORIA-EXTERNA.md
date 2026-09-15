# Auditoria Externa — Uptend (documento de plano/design)

> Nova "arma" do Uptend: um **coletor de auditoria portátil** que roda em qualquer
> servidor (remoto, local ou do pen drive), gera um **arquivo estruturado** que o Uptend
> importa e transforma em **painel de auditoria + relatórios** (Markdown, HTML com gráficos,
> PDF e dataset para Power BI). Foco: mostrar saúde/segurança/boas práticas e **traduzir
> em valor de negócio para stakeholders e leigos**.
>
> Documento **vivo** de design — ainda **sem código**. Respeita o `PADROES.md`
> (segurança, privacidade, testes). Decisões fechadas migram para `DECISOES.md`;
> quando virar execução, entra no `ROADMAP.md`.

**Criado:** 2026-07-16 · **Status:** em design

---

## 1. Ideia central

Hoje a aba Segurança do Uptend audita **ao vivo por SSH**. Isso não cobre o caso do
**auditor/consultor** que não tem acesso SSH permanente, ou de servidores isolados
(air-gapped). A Auditoria Externa resolve isso com um **coletor de uma passada**:

```
[ Coletor portátil ]  →  roda 1 vez no servidor (remoto / local / pen drive)
        │                lê tudo (read-only), NÃO altera nada, NÃO acessa a internet
        ▼
[ Arquivo de auditoria ]  →  JSON estruturado e versionado (+ hash/assinatura)
        │                    o auditor leva embora (pen drive, e-mail, etc.)
        ▼
[ Uptend importa ]  →  arrastar o arquivo na aba "Auditoria Externa"
        │
        ▼
[ Painel + Relatórios ]  →  dashboard (semáforo/nota/CIS) + Markdown/HTML/PDF/Power BI
```

## 2. Casos de uso

- **Auditor/consultor de segurança**: roda o coletor num cliente (com autorização), leva o
  JSON, gera o relatório executivo para o cliente.
- **Dono do próprio servidor/homelab**: tira uma "foto" da postura sem manter SSH aberto.
- **Servidores isolados**: coleta offline via pen drive, análise depois.
- **Apresentar a stakeholders/gestão**: relatório visual (HTML/PDF/Power BI) que traduz o
  técnico em risco, custo e ação — inclusive **hardware em fim de vida**.

## 3. O coletor (o "script")

Um script **portátil e transparente** (bash e/ou Python — legível, **não ofuscado**).

Princípios inegociáveis (é o que separa "auditor" de "malware" — ver seção 9):
- **Read-only**: nunca modifica configuração, nunca instala, nunca cria persistência
  (sem cron/systemd/serviço).
- **Sem rede / sem exfiltração**: escreve só um arquivo local. Zero conexão de saída.
- **Legível + verificável**: texto puro + `sha256`/assinatura para a organização conferir
  integridade antes de rodar.
- **Consentimento**: assume autorização do dono/escopo assinado (a responsabilidade é do
  usuário — ver seção 10).

Dois modos:
- **Modo usuário** (sem sudo): coleta o que der sem privilégio — fricção zero.
- **Modo admin** (sudo): auditoria completa nível CIS Benchmark (lê `/etc/shadow`,
  `sshd -T`, `auditd`, etc.). O coletor diz **o que precisa de root e por quê**.

Aproveitar o que já existe:
- **Lynis** como um dos motores (já é reconhecido pelos times de segurança → menos cara de
  "script estranho"; e o Uptend **já parseia** o relatório dele). Complementar com coleta
  própria para os itens que o Lynis não cobre.
- Opcional no futuro: **osquery** / mapeamento **OpenSCAP/CIS-CAT**.

## 4. O que o coletor lê (categorias)

- **Identidade da máquina / hardware**: modelo/CPU (fabricante, núcleos, ano/geração),
  RAM total, discos (modelo, horas de uso, SMART, setores realocados), placa-mãe/BIOS/UEFI
  e versão, virtual vs físico.
- **Sistema operacional**: distro + versão + **data de fim de suporte (EOL)**, kernel,
  uptime, patches pendentes (segurança).
- **Segurança / hardening**: firewall (ufw/nftables), fail2ban, SSH (root/senha/algoritmos),
  usuários e sudoers, senhas fracas/sem expiração, SELinux/AppArmor, auditd, permissões de
  arquivos sensíveis, serviços expostos, portas abertas, atualizações automáticas.
- **Serviços & software**: pacotes instalados, versões desatualizadas/vulneráveis,
  containers e imagens, serviços rodando (systemd).
- **Rede**: interfaces, DNS, portas escutando (local vs exposto), regras de firewall.
- **Backups & resiliência**: existência/idade de backups, RAID, espaço em disco.
- **Conformidade**: mapeamento para **CIS Benchmarks** / boas práticas (aprovado/falho por
  controle) + índice de endurecimento (Lynis).
- **Logs/SIEM (leitura)**: presença/estado de auditoria (auditd/journald), retenção,
  sinais de eventos relevantes (sem coletar conteúdo sensível de logs por padrão).

## 5. Formato de saída (o arquivo importado)

- **JSON versionado** (schema com `schema_version`) — a "verdade" que o Uptend ingere.
- Contém: metadados da coleta (data, host, modo, versão do coletor, hash), + cada
  categoria com **achados normalizados**: `id`, `título`, `severidade` (ok/baixa/média/
  alta/crítica), `categoria`, `controle CIS`, `evidência`, `recomendação`, `impacto de
  negócio`.
- **Assinado/hasheado** para garantir que o arquivo não foi adulterado entre coletar e
  importar.

## 6. Ingestão no Uptend — nova aba "Auditoria Externa"

- **Arrastar o arquivo** (ou "Importar…") → o Uptend valida o schema/assinatura e monta o
  painel. Sem rede, sem servidor — puro processamento local do arquivo.
- Guarda um **histórico** de auditorias importadas (comparar no tempo: "melhorou desde a
  última?").
- Suporta **comparar dois servidores** ou **duas datas** do mesmo servidor.

## 6.1 Metabase EMBUTIDO no Uptend (WebView) — parece serviço nativo

A aba Auditoria Externa integra o Metabase de forma que o usuário **não precisa abrir o
navegador**:
1. **Gerencia o serviço** (nativo, reaproveita Catálogo/Containers): sobe/para o container
   do Metabase, mostra status.
2. **Importa/carrega os dados** (JSON → banco) — nativo.
3. **Embute a interface do Metabase numa WebView** (WKWebView) dentro da janela do Uptend:
   ver e **mexer** nos dashboards (criar/editar/filtrar/consultar) sem sair do app.

Honestidade: o conteúdo da WebView **continua sendo a UI web do Metabase** (não é
reconstruída com os cartões nativos) — o certo aqui, reaproveita 100% do Metabase. Oferecer
os dois caminhos: **embutido** (padrão) + botão **"Abrir no navegador"** (tela cheia/
compartilhar link).

**Generalização (bônus):** a mesma técnica (WebView) serve para **qualquer serviço
self-hosted** do Catálogo (Portainer, Pi-hole, Uptime Kuma…). O Uptend vira um **hub que
abre os painéis dos serviços dentro do próprio app**.

Segurança: a WebView só carrega a **URL do serviço self-hosted (confiável)** — nada externo;
dados não saem. Ressalvas: o serviço precisa estar rodando (RAM) e tem login próprio (o
Uptend pode facilitar).

## 7. Painel de auditoria (dashboard)

- **Nota geral** (0–100) + **semáforo por categoria** (verde/amarelo/vermelho).
- **Top riscos** priorizados por severidade × facilidade de correção.
- **Cumprimento CIS** (X de Y controles) com barra de progresso.
- **Hardware**: destaque de **fim de vida** (SO/EOL, CPU antiga, disco com muitas horas/
  setores realocados) → sugestão de **substituição/upgrade** (ver seção 8).
- Cada achado: o que é, evidência, **como corrigir**, e o **impacto de negócio**.

## 8. Relatórios gerados (formatos e papéis)

O usuário importa **um** arquivo; o Uptend gera **vários** formatos, cada um com um papel:

| Formato | Papel | Público |
|---|---|---|
| **Markdown** | Documentação **crua/estruturada**, guardada e **legível por IA** (para análise posterior — ex.: pedir para uma IA aprofundar). Não é para apresentar. | Arquivo/IA/dev |
| **HTML** | Relatório **detalhado com gráficos** (barras, pizza, gauge, timeline), autocontido (gráficos embutidos, sem depender de internet). O principal para leigos/stakeholders. | Gestão / cliente |
| **PDF** | Versão "impressa" do HTML, para anexar/enviar/imprimir em reunião. | Gestão / formal |
| **Metabase** (recomendado p/ BI interativo) | Dashboard **interativo, self-hosted, open-source e grátis**, que o **próprio Uptend sobe via Docker**. Dados de auditoria **ficam na sua/na infra do cliente** — nunca vão pra nuvem de terceiro. Ideal para análise viva e confidencialidade. | Apresentação / análise contínua |
| **Power BI** | Só para empresas que **exigem** padrão Microsoft. **Dataset** (CSV/JSON) + template `.pbit` que o usuário abre no Power BI. Dados vão pra nuvem MS. | Compatibilidade corporativa |

Notas de viabilidade:
- **Gráficos no HTML**: SVG inline ou lib de gráfico embutida — autocontido (o relatório
  abre em qualquer lugar, inclusive offline).
- **PDF**: gerado a partir do HTML (render/print-to-PDF).
- **Metabase (preferido para BI interativo)**: é **Docker** → encaixa no Catálogo/Deploy do
  Uptend (o Uptend pode **subir o Metabase sozinho**). Lê de **banco**, não de JSON solto →
  pipeline: `JSON → Uptend carrega num banco (Postgres/SQLite) → Metabase lê → dashboards`
  (dá para provisionar painéis prontos). **Vantagem decisiva para auditoria**: self-hosted =
  as vulnerabilidades **não saem** pra nuvem de terceiro (confidencialidade). Custo: um
  servidor rodando (app Java, ~1–2 GB RAM) + um banco. Alternativa mais "ops" seria o
  Grafana (já no Catálogo), mas o Metabase é mais no-code/amigável para negócio.
- **Power BI**: gerar `.pbix` programaticamente é inviável; o caminho realista é **exportar
  um dataset limpo** + entregar um **template `.pbit`**. Fica como opção de compatibilidade
  para quem é obrigado pelo padrão Microsoft.

**Estratégia dos formatos:** HTML/PDF = entregável **portátil** (arquivo único, offline);
**Metabase** = BI **interativo self-hosted** recomendado (o Uptend sobe); Power BI = só
compatibilidade corporativa. Markdown = cru/IA (documentação).

## 9. Valor de negócio & stakeholders (o coração da ideia)

Traduzir **técnico → negócio**, para o gestor/leigo entender e aprovar correções:
- Cada achado ganha um **impacto de negócio** ("porta X exposta = risco de invasão/
  vazamento", "SO em fim de vida = sem patches = risco + não-conformidade").
- **Risco** em linguagem de negócio (probabilidade × impacto), não jargão.
- **Priorização** por severidade e esforço → "corrija estes 3 primeiro".
- **Hardware em fim de vida**: sinalizar SO/EOL, CPU antiga, disco desgastado → recomendar
  **substituir/atualizar** (v1: sinais de EOL e desgaste; futuro: sugerir modelos/estimar
  custo — possivelmente com apoio de IA/catálogo).
- **Comparativo temporal**: "postura subiu de 58 → 74 desde a última auditoria" — mostra
  progresso e justifica investimento.

## 10. Segurança & aspecto legal

- **Não é malware** se seguir a seção 3 (read-only, sem persistência, sem exfiltração,
  transparente, com consentimento). A diferença é **comportamento + intenção +
  autorização**, não a ideia.
- **Vai ser logado** por SIEM/auditd (é o esperado) e **pode ser flagrado por EDR**
  corporativo — por isso auditoria séria é **coordenada, não escondida**. Transparência é
  feature, não bug. Nunca adicionar "stealth"/ofuscação (isso, sim, cruzaria a linha).
- **Legal**: rodar só em sistema **autorizado** (seu, ou cliente com escopo/contrato
  assinado). Em servidor de terceiro **sem autorização** é acesso não autorizado (crime),
  mesmo read-only. O Uptend deixa isso explícito e o usuário confirma a autorização.
- **Hash/assinatura** do coletor e do arquivo de saída para cadeia de custódia.

## 11. Roteiro de implementação (fases) — a definir

1. **Schema JSON v1** + coletor mínimo (bash) read-only, modo usuário e admin, aproveitando
   o Lynis + coleta própria essencial.
2. **Importação + painel** no Uptend (aba nova; arrastar arquivo → dashboard).
3. **Relatório HTML com gráficos** (autocontido) + **Markdown** (cru/IA).
4. **PDF** (a partir do HTML).
5. **Export Power BI** (dataset + template `.pbit`).
6. **Histórico/comparativo** + **hardware EOL** + **impacto de negócio** refinados.
7. (futuro) osquery/OpenSCAP, sugestão de hardware com IA, assinatura forte.

## 12. Decisões em aberto

- Coletor em **bash** (portabilidade máxima, zero dependência) vs **Python** (mais rico,
  mas exige interpretador)? Provável: bash no núcleo, Python opcional.
- Usar **Lynis como motor** e complementar, ou coletor 100% próprio? (Tendência: Lynis +
  complemento — reaproveita o parser que já temos e a credibilidade da ferramenta.)
- Framework de conformidade inicial: **CIS Benchmarks** (mais reconhecido) — confirmar.
- Assinatura: hash simples (v1) vs assinatura com chave (futuro).
