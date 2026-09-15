# Sobre o autor

## André Augusto Azarias de Souza

→ [LinkedIn](https://linkedin.com/in/andreaugusto-azariasdesouza) · [GitHub](https://github.com/andre28abr) · contato@azariasdesouza.com

---

## Quem é

Gestor com **18 anos de atuação como Gerente Administrativo e Encarregado de Dados (DPO)** em organização do setor de saúde suplementar, ambiente regulado pela ANS e pela LGPD. Participou de decisões de diretoria, conduziu a relação com hospitais e operadoras, liderou a modernização dos sistemas administrativos e de segurança da informação e coordenou o programa de adequação à LGPD da organização, com dados sensíveis de saúde sob o Art. 11.

Formado em **Direito** e em **Análise e Desenvolvimento de Sistemas**, com pós-graduações em segurança digital, governança de dados, privacidade, direito digital e liderança ágil.

Atua na interseção entre **Compliance, GRC, privacidade e segurança da informação**: mapeamento de dados e ROPA (Art. 37), RIPD/DPIA (Art. 38), direitos do titular (Art. 18), gestão de operadores e terceiros (Art. 39), resposta a incidentes (Art. 48), interface com a ANPD, e os frameworks NIST CSF, CIS Controls e ISO/IEC 27001/27701. Trabalha com o princípio de que proteção de dados é também arquitetura: Security by Design, Zero Trust, defesa em camadas e menor privilégio.

Desde 2025 conduz, como **product owner técnico**, projetos open-source de segurança e privacidade em Python, Go, Rust e Swift, com a codificação orquestrada por assistentes de IA generativa sob sua direção e revisão. Desenvolve **automações de processos com n8n** e é autor de cinco livros publicados, entre eles *Da Norma à Liderança*, sobre atualização profissional em GRC.

---

## Automação de processos com n8n

Projeta e opera **automações de processos de negócio e jurídicos em n8n**, self-hosted em Docker Compose, com foco em privacidade: processamento local, gravação em disco restrita a pastas definidas, sem envio de dados a serviços de terceiros. Entre o que já construiu:

- **Triagem automática de publicações judiciais**: busca de hora em hora no DJEN (Comunica CNJ) por OAB, classificação por urgência, cálculo de prazo provisório em dias úteis, contexto do processo via DataJud e painel web de tratamento por advogado.
- **Onboarding de clientes**: formulário web que gera em segundos procuração, declaração de hipossuficiência e contrato de honorários em PDF (Gotenberg), com registro do cliente para os fluxos seguintes.
- **Portal e páginas servidas pelo próprio n8n** via webhooks, instaladores para Mac e Windows, variante para servidor com HTTPS automático e autenticação (Caddy) e rotina de backup.
- **Integrações com APIs públicas** (DJEN, DataJud, BrasilAPI) e desenho de fluxos com Code nodes, banco JSON local e controle de estado entre execuções.

---

## Por que esse projeto existe

O **Uptend** nasceu como exercício pessoal de portfólio com três objetivos:

1. **Resolver um problema meu e transformá-lo em produto.** Formatar o Mac e reinstalar tudo era uma tarde perdida. O app começou como a lista de "tudo que eu instalo" com um botão, perfis de Brewfile, dotfiles, ajustes do sistema, e cresceu para o canivete de manutenção que uso todo dia: Homebrew, apps, limpeza, Git, Docker, rede, segurança.

2. **Traduzir auditoria técnica em linguagem de decisão.** Como DPO, o que faltava nas ferramentas de auditoria de servidores não era detecção, era *tradução*: o gestor não lê `sshd_config`. O módulo de **Auditoria Externa** roda um coletor portátil em qualquer servidor Linux e devolve achados com **impacto de negócio, referência normativa (CIS, ISO 27001, LGPD), evidência, mapeamento MITRE ATT&CK, correlação com CVEs** e um **playbook de correção com rollback**, os entregáveis que uma consultoria de fato apresenta, com a marca de quem audita.

3. **Exercitar a orquestração de um projeto técnico complexo com auxílio de IA generativa.** A skill emergente do mercado pós-2024 não é "decorar sintaxe", é **definir requisitos, validar arquitetura, traduzir necessidade de negócio em especificação** e usar IA para acelerar a entrega. O Uptend reúne **Swift 6 + SwiftUI**, um núcleo de lógica pura testado em isolamento, integrações reais com o sistema por processos sem shell, SSH e Keychain, e um coletor em shell POSIX validado num laboratório de VMs seguras e vulneráveis, tudo com **428 testes** e zero warnings, e uma auditoria de segurança de ponta a ponta com cada correção acompanhada de teste de regressão.

---

## Atuação neste projeto

**Papel:** Product Owner técnico, com auxílio de assistentes de IA generativa para a etapa de codificação.

**Entregas pessoais (direção e revisão do autor):**
- Definição de **requisitos, escopo e roadmap**, registrados desde o primeiro dia em `docs/` (histórico, decisões, padrões, brainstorm), inclusive a decisão de renomear o projeto e a de separar o núcleo testável da interface.
- **Padrões de engenharia** fixados antes do código (`docs/PADROES.md`): sem force-unwrap em caminho que pode falhar, Security by Design, Privacy by Design, feature nova exige teste novo, Definition of Done.
- **Curadoria do conteúdo de auditoria**: domínios, severidades, referências normativas, catálogo de conformidade, lente LGPD, explicações para leigos e o modelo de entregável (Markdown, HTML, PDF, dataset para BI).
- **Direção da auditoria de segurança** (julho/2026): tratamento do JSON do coletor como entrada adversarial, caminhos temporários previsíveis, injeção em HTML/Markdown/script gerado, deadlock de pipe, cada achado virou correção com teste.
- **Decisões de trade-off**: zero dependências externas; `Process` com argumentos em array em vez de shell; token do GitHub via `GIT_ASKPASS` e Keychain; playbook com backup e rollback em vez de aplicar correções direto; AGPL-3.0 com dual license.

**Etapa de codificação:** orquestrada com auxílio de IA generativa, sob direção e revisão do autor.

---

## Outros projetos

**[SentinelBR](https://github.com/andre28abr/SentinelBR-platform)**: plataforma open-source de **SIEM + LGPD** para PMEs brasileiras. Agente Go com gRPC e mTLS, detecção em tempo real, resposta automatizada e compliance LGPD nativa, multi-tenant. 225 testes entre servidor, agente e frontend; CI em 16 jobs.

**[VigiaOS](https://github.com/andre28abr/VigiaOS)**: suíte de **segurança, privacidade e LGPD** para a estação de trabalho (Fedora Workstation, GTK4 + libadwaita), com 13 ferramentas defensivas, módulos de detecção e resposta e laboratório educacional com termo de uso. 1460 testes em Python e 28 em Rust.

**[Plataforma LGPD](https://github.com/andre28abr/lgpd-platform)**: plataforma web multi-tenant que **treina, avalia e certifica** os setores de uma empresa em LGPD e dá ao DPO as ferramentas de operação: ROPA, RIPD, direitos do titular e incidentes. 121 testes, 95% de cobertura.

**[Peapod](https://github.com/andre28abr/Peapod)**: sandboxes **isolados e descartáveis para agentes de IA**, dirigidos por MCP, CLI, dashboard web e app nativo de macOS: rede desligada por padrão, allowlist de domínios, trilha de auditoria. Go e Swift, distribuído por Homebrew.

**[banana](https://github.com/andre28abr/banana)**: editor **local-first** de notas Markdown, código e PDF, com vault cifrado (Argon2id + AES-256-GCM). Tauri 2, Rust e Svelte 5, 393 testes.

**SC Platform** *(privado, disponível para apresentação mediante solicitação)*: SaaS multi-tenant para gestão de licitações públicas, com PNCP em tempo real, simulador da Lei 14.133/2021, robô de lances em três modos, extração de PDF com IA local, CRM e Telegram. Cerca de 75 mil linhas e 547 testes.

**AUGRAZ** *(privado, produto da empresa do autor)*: plataforma de compliance **LGPD + ISO 27001** para assessoria de proteção de dados: 11 módulos por empresa-cliente (ROPA, canal do titular, incidentes, comunicações com a ANPD, fornecedores, treinamentos), biblioteca dos 93 controles do Anexo A da ISO/IEC 27001:2022 com Gap Analysis, relatórios imprimíveis e geradores de política de privacidade, aviso de cookies e termos de uso. Flask, testes em SQLite e PostgreSQL, CI com lint e auditoria de dependências.

**Site AUGRAZ** *(privado, protótipo ainda não publicado)*: site institucional em HTML e PHP com formulário de contato em PDO e prepared statements, credenciais fora do repositório e `.htaccess` com HTTPS forçado, bloqueio de arquivos sensíveis e cabeçalhos de segurança (HSTS, nosniff, X-Frame-Options, Referrer-Policy, Permissions-Policy).

---

→ **[LinkedIn](https://linkedin.com/in/andreaugusto-azariasdesouza)** · [GitHub](https://github.com/andre28abr)
