# Uptend — configurar, manter e auditar o Mac e o servidor de casa

> **Uptend** é um app nativo de macOS (SwiftUI) que faz duas coisas que costumam exigir dez ferramentas: **cuidar do Mac** — reinstalar tudo com um clique depois de formatar (perfis de Brewfile e dotfiles), Homebrew, apps, limpeza, Git/GitHub, Docker, rede, segurança e ajustes do sistema — e **auditar servidores Linux** com um **coletor portátil** que roda em qualquer máquina (remota, local ou de um pen drive) e vira, dentro do app, **painel de auditoria, relatórios em Markdown/HTML/PDF, mapa de superfície de ataque, correlação com CVEs, lente LGPD e playbook de hardening com rollback**. Tudo local, sem conta e sem telemetria. *up* (uptime / upkeep) + *tend* (cuidar).

[![ci](https://github.com/andre28abr/Uptend/actions/workflows/ci.yml/badge.svg)](https://github.com/andre28abr/Uptend/actions/workflows/ci.yml)
![Status](https://img.shields.io/badge/status-v0.1.0%20%C2%B7%20auditado-success)
![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-macOS%2014%2B-0A84FF?logo=apple&logoColor=white)
![Tests](https://img.shields.io/badge/tests-428%20passing%20%C2%B7%2070%20su%C3%ADtes-success)
![Warnings](https://img.shields.io/badge/compiler%20warnings-0-success)
![LGPD](https://img.shields.io/badge/LGPD-lens-10b981)
![Homebrew](https://img.shields.io/badge/Homebrew-brew%20install%20----cask%20uptend-FBB040?logo=homebrew&logoColor=black)
![License](https://img.shields.io/badge/license-AGPL--3.0-orange)

---

## 👤 Autor

**André Augusto Azarias de Souza** · DPO / Encarregado de Dados · Compliance & GRC · Privacy Engineering

Gestor com **18 anos de atuação como Gerente Administrativo e Encarregado de Dados (DPO)** em organização do setor de saúde suplementar, ambiente regulado pela ANS e pela LGPD. Participou de decisões de diretoria, conduziu a relação com hospitais e operadoras, liderou a modernização dos sistemas administrativos e de segurança da informação e coordenou o programa de adequação à LGPD da organização, com dados sensíveis de saúde sob o Art. 11.

Desde 2025 conduz, como **product owner técnico**, projetos open-source de segurança e privacidade em Python, Go, Rust e Swift, com a codificação orquestrada por assistentes de IA generativa sob sua direção e revisão. O Uptend seguiu esse modelo: começou como o app pessoal de "reinstalar o Mac" e cresceu para um auditor de servidores que traduz achados técnicos em **risco de negócio, conformidade e plano de correção**. Também desenvolve **automações de processos com n8n** e é autor de cinco livros publicados, entre eles *Da Norma à Liderança*, sobre atualização profissional em GRC.

→ **[Bio completa: AUTHOR.md](AUTHOR.md)** · [LinkedIn](https://linkedin.com/in/andreaugusto-azariasdesouza) · [GitHub Profile](https://github.com/andre28abr)

### 📂 Outros projetos do autor

**[SentinelBR](https://github.com/andre28abr/SentinelBR-platform)** ![Python](https://img.shields.io/badge/-Python-3776AB?logo=python&logoColor=white) ![Go](https://img.shields.io/badge/-Go-00ADD8?logo=go&logoColor=white) ![React](https://img.shields.io/badge/-React-20232A?logo=react&logoColor=61DAFB)<br>
Plataforma open-source de **SIEM + LGPD** para PMEs brasileiras: agente Go com gRPC e mTLS, detecção em tempo real, resposta automatizada e compliance LGPD nativa, multi-tenant. 225 testes, CI em 16 jobs.

**[VigiaOS](https://github.com/andre28abr/VigiaOS)** ![Python](https://img.shields.io/badge/-Python-3776AB?logo=python&logoColor=white) ![Rust](https://img.shields.io/badge/-Rust-000000?logo=rust&logoColor=white) ![GTK4](https://img.shields.io/badge/-GTK4-4A86CF?logo=gtk&logoColor=white)<br>
Suíte de **segurança, privacidade e LGPD** para a estação de trabalho (Fedora Workstation, GTK4 + libadwaita), com 13 ferramentas defensivas, módulos de detecção e resposta e laboratório educacional. 1460 testes em Python e 28 em Rust.

**[Plataforma LGPD](https://github.com/andre28abr/lgpd-platform)** ![Python](https://img.shields.io/badge/-Python-3776AB?logo=python&logoColor=white) ![Flask](https://img.shields.io/badge/-Flask-000000?logo=flask&logoColor=white) ![PostgreSQL](https://img.shields.io/badge/-PostgreSQL-4169E1?logo=postgresql&logoColor=white)<br>
Plataforma web multi-tenant que **treina, avalia e certifica** os setores de uma empresa em LGPD e dá ao DPO as ferramentas de operação: ROPA, RIPD, direitos do titular e incidentes. 121 testes, 95% de cobertura.

**[Peapod](https://github.com/andre28abr/Peapod)** ![Go](https://img.shields.io/badge/-Go-00ADD8?logo=go&logoColor=white) ![Swift](https://img.shields.io/badge/-Swift-F05138?logo=swift&logoColor=white) ![Docker](https://img.shields.io/badge/-Docker-2496ED?logo=docker&logoColor=white)<br>
Sandboxes **isolados e descartáveis para agentes de IA**, dirigidos por MCP, CLI, dashboard web e app nativo de macOS: rede desligada por padrão, allowlist de domínios, trilha de auditoria. Distribuído por Homebrew.

**[banana](https://github.com/andre28abr/banana-releases)** ![Rust](https://img.shields.io/badge/-Rust-000000?logo=rust&logoColor=white) ![Tauri 2](https://img.shields.io/badge/-Tauri%202-24C8D8?logo=tauri&logoColor=white) ![Svelte 5](https://img.shields.io/badge/-Svelte%205-FF3E00?logo=svelte&logoColor=white)<br>
Editor **local-first** de notas Markdown, código e PDF, com vault cifrado (Argon2id + AES-256-GCM). 393 testes.

Todos os projetos, com o porquê de cada um, no perfil [github.com/andre28abr](https://github.com/andre28abr).

---

## Sumário

1. [TL;DR](#tldr)
2. [O que faz — Mac](#o-que-faz--mac)
3. [O que faz — Auditoria de servidores](#o-que-faz--auditoria-de-servidores)
4. [Arquitetura](#arquitetura)
5. [Segurança e privacidade](#segurança-e-privacidade)
6. [Estrutura do projeto](#estrutura-do-projeto)
7. [Como rodar](#como-rodar)
8. [Testes e qualidade](#testes-e-qualidade)
9. [Laboratório](#laboratório)
10. [Métricas do código](#métricas-do-código)
11. [Roadmap](#roadmap)
12. [Documentação interna](#documentação-interna)
13. [Licença](#licença)

---

## TL;DR

**O que é:** um app de Mac com duas metades. A primeira é o canivete suíço de manutenção do próprio Mac. A segunda é um **auditor de servidores Linux** pensado para quem precisa entregar um diagnóstico a um cliente ou a um gestor: roda um script portátil no servidor, importa o resultado e recebe um painel com **achados priorizados por risco, evidências, mapeamento MITRE ATT&CK, correlação com CVEs, análise de deriva entre auditorias, exceções de risco documentadas, lente LGPD e um playbook de hardening** pronto para executar, com backup e rollback.

**Por que existe:** ferramentas de auditoria mostram listas de problemas técnicos. Quem decide orçamento não lê `sshd_config`. O Uptend traduz cada achado em **impacto de negócio, referência normativa e ação concreta**, e gera o entregável (Markdown, HTML com gráficos, PDF, dataset para BI) com a marca de quem audita.

**Stack:** Swift 6 · SwiftUI · Swift Package Manager · Swift Testing · macOS 14+ · sem dependências externas.

---

## O que faz — Mac

| Categoria | O que resolve |
|---|---|
| **Setup** | Modo "primeira vez" passo a passo, perfis de **Brewfile** (exporte sua seleção e reinstale tudo na próxima formatação), restauração de **dotfiles**, comparação de perfis. |
| **Homebrew** | Buscar, instalar, ver instalados, atualizar, taps, manutenção (`update`, `cleanup`, `doctor`) com log ao vivo. |
| **Aplicativos** | Lista `/Applications`, verifica assinatura e notarização, desinstala movendo para a Lixeira com arquivos residuais. |
| **Limpeza** | Lixeira, caches, logs, downloads antigos, caches de dev (Xcode, npm, CocoaPods), analisador de espaço. Sempre reversível. |
| **Git & GitHub** | Monitora pastas de repositórios e o estado de sincronização; cliente GitHub por token no **Keychain**, com clone e commit + push num clique. Autenticação por `GIT_ASKPASS`: o token nunca vai para a linha de comando nem para o `.git/config`. |
| **Docker** | Containers, imagens, volumes e redes (OrbStack / Docker Desktop). |
| **Rede** | Velocidade ao vivo, Wi-Fi, latência, endereços, conexões ativas, portas em uso, teste de velocidade. |
| **Segurança** | FileVault, Firewall, Gatekeeper, SIP e atualizações; exposição de portas; scanners (ClamAV, TLS); gerador de senhas e hashes. |
| **Sistema** | Informações do Mac, energia, itens de inicialização, serviços, ajustes rápidos (Finder, Dock, teclado, capturas). |
| **Ferramentas** | Conversores, QR Code, chave SSH, histórico de clipboard, runtimes (Node, Python, Ruby…), Xcode. |
| **Barra de menu** | Mini painel de CPU, memória e rede com mini-gráficos. |

---

## O que faz — Auditoria de servidores

1. **Coletor portátil** (`audit-collector.sh`, ~1.100 linhas de shell POSIX): roda em Ubuntu, Debian, Fedora, Rocky/Alma — por SSH a partir do app, localmente ou de um pen drive. Coleta sistema, discos, usuários, SSH, firewall, serviços, Docker, pacotes, permissões, banco de dados (estrutura ou com amostras) e gera um **JSON assinado** com hash.
2. **Importação e painel**: achados classificados por severidade e domínio (identidade, rede, endurecimento, dados, conformidade), com evidência bruta, referência normativa (CIS, ISO 27001, LGPD) e explicação para leigos.
3. **Inteligência sobre os achados**: mapa de **superfície de ataque** (portas × serviços × exposição), correlação com **CVEs** conhecidas por versão de pacote, mapeamento **MITRE ATT&CK**, **regras de detecção** compensatórias (estilo Sigma/Falco) para o que não dá para corrigir na hora, **registro de riscos** e **exceções** documentadas.
4. **Comparação e frota**: deriva entre duas auditorias do mesmo host, baseline por perfil de servidor, consolidação de vários hosts.
5. **Entregáveis**: relatório Markdown, dashboard HTML com gráficos, PDF, dataset CSV/JSON para Power BI e afins — com **marca do auditor** (logo, cores, rodapé) e **assinatura** do relatório.
6. **Playbook de hardening**: script gerado por distro (apt × dnf) que aplica as correções com **backup e `rollback`** num só comando, tratando hostname e demais campos do coletor como entrada adversarial.
7. **Lente LGPD**: quais achados tocam dados pessoais, qual artigo da lei e o que dizer ao Encarregado.

---

## Arquitetura

```
Sources/UptendCore/            lógica pura, sem SwiftUI/AppKit — testável isolada
  ExternalAudit · AuditReport · AuditDashboard · AttackSurfaceMap · CVE · MitreMap
  DetectionRules · DriftAnalysis · Baseline · FleetRollup · RiskRegister · RiskException
  HardeningPlaybook · RemediationMap · ComplianceCatalog/Map · LGPDLens · DatabaseAudit
  MarkdownParser · ReportBranding · ReportSignature · RepoBrowser · PortService · ScannerHelp

Sources/Uptend/                app SwiftUI (NavigationSplitView de 3 colunas)
  App/        UptendApp, AppState
  Model/      Category (categorias e subseções), Models
  Services/   integrações reais: Shell/CommandRunner, Brew, Git/GitHub, Docker, SSH,
              Remote* (host, docker, disks, files, network, security, terminal, backup, deploy),
              ExternalAuditService, Keychain, UptendVault, scanners…
  Views/      uma view por categoria + componentes
  Resources/  audit-collector.sh (o coletor portátil, embutido no app)

Tests/UptendTests/             428 testes em 70 suítes (Swift Testing) + fixture de auditoria real do lab
```

Decisões que valem registrar (detalhes em [docs/DECISOES.md](docs/DECISOES.md)):

- **Núcleo separado da interface.** Tudo que é relatório, parser, correlação e playbook vive em `UptendCore`, sem importar SwiftUI. É o que permite 428 testes rápidos e determinísticos.
- **Comandos sem shell.** Todo processo roda via `Process` com argumentos em array. Nunca há interpolação de string em `sh -c`.
- **Entrada do coletor é adversarial.** O JSON vem de um servidor que pode estar comprometido: hostname, versões e evidências são escapados antes de virar HTML, Markdown ou linha de script.
- **Segredos no Keychain.** Token do GitHub, chaves e o vault do app nunca tocam disco em claro nem aparecem em argumentos de processo.
- **Sem dependências.** Zero pacotes externos: menos superfície, build reproduzível, auditável de ponta a ponta.

---

## Segurança e privacidade

- **Local-first**: nada é enviado a servidores. As únicas conexões de rede são ações explícitas (IP público, teste de velocidade, GitHub, SSH aos seus hosts) e sinalizadas.
- **Defesa em profundidade nos comandos**: validação de entrada, argumentos em array, `sudo -n` só onde o usuário autorizou.
- **Coletor remoto** grava em diretório temporário próprio (`mktemp -d`, modo 700); relatórios do Lynis vão para `/var/log`, não para `/tmp` previsível.
- **Relatórios à prova de injeção**: JSON dentro de `<script>` escapado, cercas de código dimensionadas pelo conteúdo, células de tabela sanitizadas, cabeçalhos do playbook achatados numa linha.
- **Ações destrutivas** são reversíveis (Lixeira) e pedem confirmação; o playbook de hardening faz backup e tem `rollback`.
- Auditoria de segurança de ponta a ponta registrada em [docs/HISTORICO.md](docs/HISTORICO.md) (julho/2026), com cada achado corrigido acompanhado de teste de regressão.

---

## Estrutura do projeto

```
.
├── Package.swift                 # SwiftPM: UptendCore, Uptend (app), UptendTests
├── Sources/UptendCore/           # lógica pura (28 arquivos, ~5.5k linhas)
├── Sources/Uptend/               # app SwiftUI (~23k linhas): App, Model, Services, Views, Resources
├── Tests/UptendTests/            # 70 suítes + Fixtures/
├── Resources/                    # ícone (.icon Liquid Glass + .icns legado)
├── docs/                         # histórico, decisões, roadmap, padrões, design (HomeLab, Auditoria)
├── lab/                          # VMs OrbStack seguras/vulneráveis para validar o coletor
├── build-app.sh                  # compila e monta build/Uptend.app (--debug, --install)
├── make-dmg.sh · make-icon.swift # empacotamento e ícone
├── test.sh                       # swift test com o toolchain do Xcode
├── .swiftlint.yml                # regras de lint
├── README-DEV.md                 # guia de desenvolvimento
└── CLAUDE.md                     # contexto para sessões de IA
```

---

## Como rodar

**Instalar pelo Homebrew** (macOS 14+, Apple Silicon):

```bash
brew tap andre28abr/uptend
brew trust andre28abr/uptend   # Homebrew 6+: confiar no tap (uma vez)
brew install --cask uptend
```

Ou baixe o **[Uptend.dmg](https://github.com/andre28abr/Uptend/releases/latest)** e arraste o app para *Aplicativos*. O app é assinado ad-hoc (não notarizado pela Apple): na primeira abertura, clique com o botão direito e escolha **Abrir**. Tap: [andre28abr/homebrew-uptend](https://github.com/andre28abr/homebrew-uptend).

**Compilar do código.** Requisitos: **macOS 14+** e **Xcode 16+** (Swift 6 e Swift Testing). Homebrew é recomendado para as funções de instalação.

```bash
./build-app.sh              # compila em release e abre build/Uptend.app
./build-app.sh --debug      # compila mais rápido
./build-app.sh --install    # compila e atualiza /Applications/Uptend.app
swift run                   # ou direto pelo SwiftPM
```

Ou abra `Package.swift` no Xcode e rode com Cmd+R. Para gerar um DMG: `./make-dmg.sh` (assinatura ad-hoc; notarização descrita em [README-DEV.md](README-DEV.md)).

---

## Testes e qualidade

```bash
./test.sh                   # 428 testes em 70 suítes (Swift Testing), ~13 s
swift build                 # 0 warnings
swiftlint                   # opcional: brew install swiftlint
```

O que a suíte cobre: parser de Markdown, relatórios e dashboard (incluindo os casos de injeção), superfície de ataque, CVE matcher, playbook de hardening, deriva e baseline, frota, exceções de risco, catálogo de conformidade e lente LGPD, banco de dados, assinatura de relatório, Keychain e vault, runner de comandos, serviços de Brew/Git/GitHub/Docker/rede com comandos mockados, e testes de fumaça que rodam de verdade no Mac (scan de apps, checagens de segurança, geração de relatório).

O CI (GitHub Actions, macOS) compila e roda a suíte a cada push. Padrões de engenharia em [docs/PADROES.md](docs/PADROES.md): sem force-unwrap em caminhos que podem falhar, Security by Design, Privacy by Design, feature nova exige teste novo.

---

## Laboratório

[`lab/`](lab/README.md) sobe, no OrbStack, um par de VMs por família de distro — uma **endurecida** (deve sair quase limpa) e uma **vulnerável** (cheia de brechas de propósito) — para validar que o coletor pega o máximo de achados e o playbook os corrige. Inclui bancos de dados seguro e inseguro para o módulo de auditoria de dados.

---

## Métricas do código

| Métrica | Valor |
|---|---|
| **Linhas de Swift** | ~33.700 (núcleo 5.5k · app 23.2k · testes 5.0k) |
| **Arquivos Swift** | 219 |
| **Serviços** | 73 (Mac + remoto/SSH + auditoria) |
| **Views** | 44 |
| **Módulos do núcleo** | 28 |
| **Coletor portátil** | 1 script POSIX de ~1.100 linhas; Ubuntu, Debian, Fedora, Rocky/Alma (apt e dnf) |
| **Testes** | 428 em 70 suítes, ~13 s |
| **Warnings de compilação** | 0 |
| **Dependências externas** | 0 |

---

## Roadmap

- **Concluído (jul/2026):** todas as categorias do Mac ligadas à lógica real; HomeLab (hosts remotos por SSH: Docker, discos, arquivos, rede, segurança, terminal, backup, deploy); Auditoria Externa completa (coletor, painel, relatórios, CVE, MITRE, detecção, deriva, frota, exceções, LGPD, playbook); auditoria de segurança de ponta a ponta; ícone Liquid Glass. **Set/2026:** release v0.1.0 no GitHub e cask no Homebrew (`brew install --cask uptend`).
- **Próximos passos** ([docs/ROADMAP.md](docs/ROADMAP.md) e [docs/PLANO-AUDITORIA-PRO.md](docs/PLANO-AUDITORIA-PRO.md)): assinatura com Developer ID e notarização; itens do plano de profissionalização da auditoria (nível empresarial).

---

## Documentação interna

| Documento | Conteúdo |
|---|---|
| [docs/HISTORICO.md](docs/HISTORICO.md) | Diário cronológico do projeto: o que foi feito, decidido e por quê |
| [docs/DECISOES.md](docs/DECISOES.md) | Decisões técnicas com contexto e motivo |
| [docs/ROADMAP.md](docs/ROADMAP.md) | O que falta, por etapa |
| [docs/PADROES.md](docs/PADROES.md) | Regras de engenharia e Definition of Done |
| [docs/AUDITORIA-EXTERNA.md](docs/AUDITORIA-EXTERNA.md) | Design do módulo de auditoria |
| [docs/PLANO-AUDITORIA-PRO.md](docs/PLANO-AUDITORIA-PRO.md) | Plano de profissionalização da auditoria |
| [docs/HOMELAB.md](docs/HOMELAB.md) | Design do módulo HomeLab |
| [docs/BRAINSTORM.md](docs/BRAINSTORM.md) | Ideias soltas |
| [README-DEV.md](README-DEV.md) | Compilar, testar, navegar o código |

---

## Licença

**GNU Affero General Public License v3.0** — veja [LICENSE](LICENSE). Você é livre para usar, estudar, modificar e redistribuir; se modificar e distribuir, inclusive como serviço em rede, precisa disponibilizar o código sob a mesma licença.

**Licenciamento comercial / dual license.** O autor mantém o copyright e pode oferecer o código sob outras licenças (por exemplo, compatível com a Apple App Store, que é incompatível com a AGPL). Contribuições de terceiros só serão aceitas mediante acordo (CLA/DCO) que preserve essa possibilidade.

---

<div align="center">

**Feito por André Augusto Azarias De Souza**

[![LinkedIn](https://img.shields.io/badge/LinkedIn-André%20Augusto-0A66C2?logo=linkedin&logoColor=white)](https://linkedin.com/in/andreaugusto-azariasdesouza)
[![GitHub](https://img.shields.io/badge/GitHub-andre28abr-181717?logo=github&logoColor=white)](https://github.com/andre28abr)

</div>
