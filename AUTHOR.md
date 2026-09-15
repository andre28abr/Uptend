# Sobre o autor

## André Augusto Azarias De Souza

→ [LinkedIn](https://linkedin.com/in/andreaugusto-azariasdesouza) · [GitHub](https://github.com/andre28abr) · [Profile completo](https://github.com/andre28abr)

---

## Resumo

Profissional com mais de 18 anos de experiência em **gestão administrativa, compliance, governança da informação e proteção de dados pessoais**, com atuação integrada entre áreas administrativas, tecnologia da informação e conformidade regulatória.

Formação dupla em **Direito (Anhanguera)** e **Análise e Desenvolvimento de Sistemas (Mackenzie)**, complementada por especializações em LGPD, Direito Digital, Segurança Digital e Liderança Ágil.

Exerceu por quase duas décadas a função de **Gerente Administrativo e Encarregado de Dados (DPO)** em organização do setor de saúde suplementar, com atuação na organização da governança, adequação à LGPD, controle documental e apoio às áreas administrativas e tecnológicas.

Atualmente em transição de carreira, com **disponibilidade imediata**, busca posições em DPO (Encarregado de Dados), Compliance, Governança & GRC, Privacy Engineering ou Security Analyst com viés regulatório.

---

## Por que esse projeto existe

O **Uptend** nasceu como exercício pessoal de portfólio com três objetivos:

1. **Resolver um problema meu e transformá-lo em produto.** Formatar o Mac e reinstalar tudo era uma tarde perdida. O app começou como a lista de "tudo que eu instalo" com um botão — perfis de Brewfile, dotfiles, ajustes do sistema — e cresceu para o canivete de manutenção que uso todo dia: Homebrew, apps, limpeza, Git, Docker, rede, segurança.

2. **Traduzir auditoria técnica em linguagem de decisão.** Como DPO, o que faltava nas ferramentas de auditoria de servidores não era detecção, era *tradução*: o gestor não lê `sshd_config`. O módulo de **Auditoria Externa** roda um coletor portátil em qualquer servidor Linux e devolve achados com **impacto de negócio, referência normativa (CIS, ISO 27001, LGPD), evidência, mapeamento MITRE ATT&CK, correlação com CVEs** e um **playbook de correção com rollback** — os entregáveis que uma consultoria de fato apresenta, com a marca de quem audita.

3. **Exercitar a orquestração de um projeto técnico complexo com auxílio de IA generativa.** A skill emergente do mercado pós-2024 não é "decorar sintaxe" — é **definir requisitos, validar arquitetura, traduzir necessidade de negócio em especificação** e usar IA para acelerar a entrega. O Uptend reúne **Swift 6 + SwiftUI**, um núcleo de lógica pura testado em isolamento, integrações reais com o sistema por processos sem shell, SSH e Keychain, e um coletor em shell POSIX validado num laboratório de VMs seguras e vulneráveis — tudo com **428 testes** e zero warnings, e uma auditoria de segurança de ponta a ponta com cada correção acompanhada de teste de regressão.

---

## Atuação neste projeto

**Papel:** Product Owner técnico, com auxílio de assistentes de IA generativa para a etapa de codificação.

**Entregas pessoais (direção e revisão do autor):**
- Definição de **requisitos, escopo e roadmap**, registrados desde o primeiro dia em `docs/` (histórico, decisões, padrões, brainstorm) — inclusive a decisão de renomear o projeto e a de separar o núcleo testável da interface.
- **Padrões de engenharia** fixados antes do código (`docs/PADROES.md`): sem force-unwrap em caminho que pode falhar, Security by Design, Privacy by Design, feature nova exige teste novo, Definition of Done.
- **Curadoria do conteúdo de auditoria**: domínios, severidades, referências normativas, catálogo de conformidade, lente LGPD, explicações para leigos e o modelo de entregável (Markdown, HTML, PDF, dataset para BI).
- **Direção da auditoria de segurança** (julho/2026): tratamento do JSON do coletor como entrada adversarial, caminhos temporários previsíveis, injeção em HTML/Markdown/script gerado, deadlock de pipe — cada achado virou correção com teste.
- **Decisões de trade-off**: zero dependências externas; `Process` com argumentos em array em vez de shell; token do GitHub via `GIT_ASKPASS` e Keychain; playbook com backup e rollback em vez de aplicar correções direto; AGPL-3.0 com dual license.

**Etapa de codificação:** orquestrada com auxílio de IA generativa, sob direção e revisão do autor.

---

## Formação relevante para o domínio

### Formação acadêmica

- **Bacharelado em Direito** — Anhanguera Educacional
- **Análise e Desenvolvimento de Sistemas** — Universidade Presbiteriana Mackenzie

### Pós-graduações ligadas a Privacy / Security / Tech

- **Privacidade e Proteção de Dados Pessoais (LGPD)** — Faculdade Focus
- **Direito, Inovação e Tecnologia** — Faculdade CERS
- **Direito Digital** — Legale Educacional
- **Segurança Digital, Governança e Gestão de Dados** — PUCRS

### Certificações ligadas ao tema deste projeto

- **DPO – Data Protection Officer (LGPD)** — CERS (2020)
- **Cybersecurity Essentials** — Cisco (2022)
- **Cibersegurança – Ameaças e Táticas de Prevenção** — FGV (2023)
- **Crise Cibernética e Continuidade de Negócios** — FGV (2023)
- **Fundamentos na Lei Geral de Proteção de Dados** — Certiprof Summit (2023)
- **Data Mapping: da Teoria à Prática** — IbiJus (2023)
- **AI for Leaders** — StartSe University (2024)
- **Visual Law** — Legale Educacional (2023)

---

## Outros projetos

**[SentinelBR](https://github.com/andre28abr/SentinelBR-platform)** — Plataforma open-source de **SIEM + LGPD** para PMEs brasileiras. Coleta logs e inventário de servidores Linux via agente Go (gRPC mTLS), detecção em tempo real (regras Sigma-style + YARA + OSV.dev), resposta automatizada (SOAR-lite) e compliance LGPD nativa, multi-tenant. Onde o SentinelBR monitora *continuamente*, o Uptend audita *sob demanda*.

**[VigiaOS](https://github.com/andre28abr/VigiaOS)** — Suíte de **segurança, privacidade e LGPD** para a estação de trabalho (Fedora Workstation, GTK4 + libadwaita): hardening, antivírus, integridade de arquivos, controles de privacidade e relatórios de conformidade, tudo em português.

**[Plataforma LGPD](https://github.com/andre28abr/lgpd-platform)** — Plataforma web multi-tenant que **treina, avalia e opera** a conformidade com a LGPD: diagnóstico de maturidade, ROPA (Art. 37), RIPD (Art. 38), direitos do titular (Art. 18) e resposta a incidentes (Art. 48).

**[Peapod](https://github.com/andre28abr/Peapod)** — Sandboxes **isolados e descartáveis para agentes de IA** (MCP, CLI, dashboard web e app nativo de macOS): rede desligada por padrão, allowlist de domínios e trilha de auditoria.

**[banana](https://github.com/andre28abr/banana)** — Editor **local-first** de notas Markdown, código e PDF (Tauri 2 + Rust + Svelte 5), com vault cifrado (Argon2id + AES-256-GCM) e export de PDF vetorial.

**SC Platform** *(privado, sob NDA — disponível para apresentação em entrevistas mediante solicitação)* — Plataforma SaaS multi-tenant para gestão de licitações públicas brasileiras (PNCP em tempo real, simulador FSM da Lei 14.133, robô de lances, extração de PDF com IA local, CRM, Telegram). 75k+ linhas, 547 testes.

---

→ **[LinkedIn](https://linkedin.com/in/andreaugusto-azariasdesouza)** · [GitHub](https://github.com/andre28abr)
