# Decisões Técnicas — MacForge

> Registro de decisões importantes (arquitetura, stack, nome, design) com a justificativa e a data. Assim nunca esquecemos por que algo foi escolhido. Se uma decisão for revertida, não apagar — marcar como SUPERADA e adicionar a nova.

Formato: cada decisão vira uma seção com contexto, decisão e motivo.

---

## Template

```
## [ID] Título curto
- Data: AAAA-MM-DD
- Status: proposta | decidida | superada
- Contexto: por que precisávamos decidir isso
- Decisão: o que foi escolhido
- Motivo: por que essa opção venceu
- Alternativas descartadas: ...
```

---

## Decisões em aberto (a resolver)

- **Distribuição** — como gerar o `.dmg` e se haverá assinatura/notarização da Apple.
- **Arquitetura interna** — organização de módulos, como rodar comandos de shell com segurança, gestão de permissões (sudo).

---

## Decisões tomadas

## [D001] Nome do projeto: MacForge
- Data: 2026-07-07
- Status: **SUPERADA por [D009]** (2026-07-08) — havia colisão com app existente.
- Contexto: precisávamos de um nome definitivo para o app/repositório.
- Decisão: **MacForge**.
- Motivo: nome forte e fácil de lembrar; passa a ideia de "forjar/montar o Mac do zero", alinhado ao propósito de setup pós-formatação.
- Alternativas descartadas: Rebrew, Cauldron, Alembic, FreshMac.
- Observação: por enquanto o projeto fica somente local; o push para o GitHub será feito depois pelo usuário.

## [D002] Stack: SwiftUI nativo
- Data: 2026-07-07
- Status: decidida
- Contexto: precisávamos escolher a tecnologia base do app.
- Decisão: **SwiftUI nativo** (macOS).
- Motivo: entrega a "cara de Mac de verdade" que o projeto quer, integração natural com o sistema, temas claro/escuro nativos e melhor UX nativa. Aceitamos a curva de aprendizado maior de Swift como custo.
- Alternativas descartadas: Tauri (web + Rust), Electron (web + Node).

## [D003] Diretrizes de design de interface
- Data: 2026-07-07
- Status: decidida
- Contexto: definir a identidade visual e regras de UI desde o início.
- Decisão:
  - Estilo Mac nativo, interface bonita e amigável, baseada em listas.
  - Sem muitas animações.
  - Não usar emojis (nem na UI, nem na documentação).
  - Ícones no estilo flat.
  - Suporte a tema claro e escuro.
  - Ícones pequenos, somente o ícone; ao passar o mouse, tooltip com breve explicação do que faz. Se o ícone for totalmente intuitivo (ex.: engrenagem = Configurações), o tooltip mostra apenas o nome.
- Motivo: consistência visual e clareza; interface limpa e rápida de usar.

## [D004] App único (canivete suíço), não dois apps
- Data: 2026-07-07
- Status: decidida
- Contexto: com o escopo crescendo (limpeza, desinstalar, Docker, utilidades…), surgiu a dúvida de separar em dois apps.
- Decisão: **um app só**, organizado por barra lateral de ferramentas.
- Motivo: uso pessoal; todas as funções compartilham o tema "centro de controle do Mac". Dois apps = duas bases/dois builds sem ganho. O risco real é escopo de tempo, mitigado construindo o núcleo primeiro e agregando módulos aos poucos.

## [D005] Layout de três colunas
- Data: 2026-07-07
- Status: decidida
- Contexto: definir a navegação principal.
- Decisão: **NavigationSplitView de 3 colunas** — categorias (esquerda) | subseções (meio) | conteúdo (direita), padrão nativo do macOS.
- Motivo: familiar (estilo Mail/Notas), organiza muitas funções sem poluir, e o usuário aprovou o mockup.

## [D006] Construir a interface primeiro (UI-first), rodando local sem DMG
- Data: 2026-07-07
- Status: decidida
- Contexto: como começar a implementação.
- Decisão: construir só a **casca visual** com dados de exemplo (mock) para avaliar o UX; depois ligar a lógica real de cada categoria. Projeto como **Swift Package** (abre no Xcode ou roda via `build-app.sh`). **Sem gerar DMG** por enquanto — empacotamento fica para o fim.
- Motivo: validar o UX antes de investir na lógica; rodar local é suficiente nesta fase.
- Docker (esclarecido): o app não substitui o Docker, ele **pilota** o Docker instalado (roda comandos por baixo e mostra em interface gráfica).

## [D007] Padrões de engenharia: testes, segurança e privacidade desde o início
- Data: 2026-07-08
- Status: decidida
- Contexto: o app será distribuído publicamente (Homebrew), roda comandos de sistema e o usuário quer código 100% desde o começo.
- Decisão: adotar `PADROES.md` como referência obrigatória, com:
  - Testes automatizados (Swift Testing) para toda lógica com risco de quebrar; `./test.sh` sempre verde.
  - **Security by Design**: nunca usar shell (só `Process` com args), validar entradas (`InputValidator`), menor privilégio, revisar contra OWASP Top 10 / ASVS / NIST SSDF / CWE Top 25 a cada feature (skill `/security-review`).
  - **Privacy by Design**: local-first, sem telemetria, sem rede indevida.
  - Preparar distribuição: assinatura Developer ID + notarização + cask com sha256.
  - "Definition of Done" com checklist (build sem warnings, testes, segurança, privacidade, histórico).
- Motivo: qualidade e segurança são muito mais baratas mantidas desde o início do que remendadas antes de distribuir.

## [D008] Reestruturação da navegação: Homebrew unificado, Aplicativos e Sistema
- Data: 2026-07-08
- Status: decidida (substitui parcialmente a estrutura de [D005])
- Contexto: "Instalar" e "Atualizar" eram seções separadas, mas são a mesma ferramenta (Homebrew). O usuário pediu uma seção dedicada ao Homebrew com tudo, uma seção para apps do Mac, e uma área de Sistema.
- Decisão:
  - Seção **Homebrew** unificada, com subseções: Buscar e instalar, Essenciais, Instalados, Atualizações, Manutenção.
  - Seção **Aplicativos**: lista `/Applications` (nome, origem App Store/Manual, tamanho) e desinstala **movendo para a Lixeira** (reversível) + residuais por bundle id, com confirmação.
  - Seção **Sistema**: Informações (chip, memória, disco, uptime, ciclos de bateria), Itens de inicialização (via System Events), Ajustes rápidos (toggles de `defaults`).
- Motivo: navegação mais limpa e coerente ("Homebrew" é a cara de painel gráfico do brew); apps e sistema atendem o pedido de gerenciar o Mac além do brew.
- Segurança aplicada: desinstalação é reversível (Lixeira); AppleScript com nome validado (`isSafeAppleScriptText`); busca com query validada; toggles e comandos com domínios/chaves fixos (sem entrada do usuário).

## [D009] Renomeação do projeto: MacForge → Uptend
- Data: 2026-07-08
- Status: decidida (supera [D001])
- Contexto: descobrimos que "MacForge" já é um app conhecido (framework de plugins para macOS). Fizemos uma busca ampla na web (88 nomes verificados) e constatamos que quase toda palavra comum já está ocupada no espaço de software/Mac.
- Decisão: **Uptend**. *up* (uptime / upkeep / up-to-date) + *tend* (cuidar / manter) = "manter o Mac em dia".
- Motivo: é inventado (único e registrável), pronúncia e escrita óbvias (bom para boca a boca), som moderno de produto, e escala além do Mac. Vence Habile (pronúncia ambígua + colisão com "Habile Technologies").
- Alternativas fortes descartadas: Fettlekit, Macsmith, Kilnix, Macura, Habile.
- Impacto aplicado: renomeado tudo — módulo/target Swift (`Uptend`), `UptendApp`, bundle id `com.andresouza.uptend`, `build-app.sh`, testes (`UptendTests`), e docs vivos (Brainstorm/Roadmap/Padrões). Histórico anterior mantém "MacForge" (registro do passado).
- Verificação de registro (2026-07-08): **nome livre** — nenhum app/produto/empresa "Uptend" (web + App Store); **GitHub `uptend` livre** (404). Domínios: `uptend.dev` provavelmente livre; `uptend.com` (Shopify) e `uptend.app` (Google Cloud) já registrados/parqueados — não é bloqueio para um app open-source via Homebrew. Ação: garantir a org `uptend` no GitHub quando for publicar; domínio opcional (`uptend.dev` ou `getuptend.com`).

## [D010] Cliente GitHub: token pessoal no Keychain + GIT_ASKPASS
- Data: 2026-07-13
- Status: decidida
- Contexto: o usuário quis conectar a conta do GitHub (inclusive repos privados) e fazer push num clique, sem terminal. Precisávamos de um jeito de autenticar o `git` e a API que fosse seguro e não dependesse de o usuário já ter SSH/credential helper configurado.
- Decisão: **token pessoal fine-grained**, guardado no **Keychain** do macOS. Para o `git`, autenticação por **`GIT_ASKPASS`** apontando para um helper fixo que lê o token de uma **variável de ambiente** (`UPTEND_GIT_TOKEN`) do processo filho.
- Alternativas descartadas: (a) **OAuth Device Flow** — mais bonito, mas exige registrar um OAuth App no GitHub e mais código; fica como evolução futura. (b) Token embutido na **URL do remote** (`https://TOKEN@github.com/...`) — vazaria em `.git/config` e em `git remote -v`. (c) `http.extraHeader` via `-c` — colocaria o token em `argv` (visível em `ps`). (d) `credential.helper` inline com `!f(){...}` — depende de shell e mistura segredo com config.
- Por que é seguro: o token só existe (1) no Keychain e (2) como variável de ambiente do processo `git` durante a operação. Nunca em `argv`, nunca em disco de config, nunca em log. O helper em disco não contém segredo. Não há `/bin/sh -c` com interpolação de dados nossos (o script é estático; o git é quem o chama). Permissões mínimas do token: Contents R/W + Metadata R.
- Privacy by Design: nenhuma chamada de rede automática — só ao conectar, atualizar a lista ou clonar.
- Impacto aplicado: `Keychain.swift`, `GitAuth.swift`, `GitHubService.swift`, evolução do `GitService` (commit+push, upstream, arquivos alterados), novas telas na aba Git, validadores novos, +13 testes (73 no total).

## [D011] Licença: AGPL-3.0 (com caminho para dual license)
- Data: 2026-07-13
- Status: decidida
- Contexto: o autor quer o código aberto, mas **sem** que alguém crie um concorrente comercial fechado em cima do projeto; e quer preservar a opção de, no futuro, pedir doação simbólica e/ou publicar uma versão comercial (ex.: Apple App Store).
- Decisão: **GNU AGPL-3.0**. Copyleft forte que fecha a "brecha do SaaS" (uso em rede também obriga a abrir o código). Garante crédito ao autor (aviso de copyright obrigatório) e mantém tudo aberto dos dois lados.
- Por que não outras: MIT/Apache (permissivas) permitiriam fork fechado comercial — o que o autor quer evitar. PolyForm Noncommercial proíbe uso comercial mas **não é** open source (OSI) e não tem o mecanismo "abriu, tem que abrir". GPL comum não cobre uso como serviço em rede; a **A**GPL cobre.
- Monetização: **doação é modelo de negócio, não cláusula de licença** — compatível com AGPL (GitHub Sponsors / PIX / Buy Me a Coffee). Nada fica trancado atrás de pagamento.
- Caminho comercial preservado (dual license): enquanto o autor detiver **100% do copyright**, pode relicenciar para frente sob outra licença (comercial ou compatível com a App Store, que é incompatível com AGPL). Regra de ouro: contribuições externas só com **CLA/DCO**, senão perde-se o direito de relicenciar sozinho. Versões já publicadas sob AGPL permanecem sob AGPL (relicenciamento vale para frente).
- Impacto aplicado: `LICENSE` (texto oficial AGPL-3.0 da GNU) na raiz e em `Uptend/`; seção "Licença" + "Apoie o projeto" no `README.md` (era MIT). Cabeçalhos de copyright nos `.swift` ficam para um passo posterior.

## [D012] Arquitetura: split em módulos SwiftPM (UptendCore + app)
- Data: 2026-07-13
- Status: decidida (migração incremental em andamento)
- Contexto: com o app crescido, a lógica pura (parsers, renderizadores, modelos) estava misturada com a UI num único módulo. Metas: fronteiras impostas pelo compilador, builds incrementais mais rápidos e testar a lógica **sem** SwiftUI.
- Decisão: criar o target **`UptendCore`** (lógica pura, sem SwiftUI/AppKit) do qual o executável `Uptend` depende. Migração **incremental**: começar por um conjunto coeso e de baixo acoplamento (`MarkdownParser`, `RepoBrowser`, `ScannerHelp`) e ir movendo o resto no mesmo padrão, sempre com build verde.
- Por que incremental e não de uma vez: o split exige marcar dezenas de tipos/funcs/inits como `public` e adicionar `import UptendCore` em muitos arquivos. Fazer tudo junto num build saudável (135 testes) arriscaria deixá-lo quebrado. Passo a passo garante que dá para parar em qualquer ponto com tudo verde.
- Não migrado ainda (próximo no mesmo padrão): modelos/renderizadores do relatório (`ReportData`/`SystemReport` — exigem `public init` grandes); depois `Shell`/`InputValidator`/`CommandRunner` (usados em toda parte, muita adição de import). `CodeHighlighter` fica no app (usa AppKit `NSColor`).
- Impacto aplicado: `Package.swift` com 3 targets; `Sources/UptendCore/` com 3 arquivos; `public` no que cruza a fronteira; imports em ~7 arquivos. `build-app.sh`/`make-dmg.sh` inalterados. Ver também [D010]/[D011].

## Confirmações
- ~~Nome MacForge revalidado em 2026-07-07~~ — superada; ver [D009] (renomeado para Uptend em 2026-07-08).

## Taps de terceiros: fluxo de confiança explícito, nunca automático (2026-07-14)
Ao instalar de um tap de terceiros, o `brew trust` (confiar na fonte) é a fronteira
de segurança. Decisão: o Uptend NUNCA confia numa fonte em silêncio. Se o install
falhar por falta de confiança (detectado no log), a UI mostra "Confiar e instalar"
e só então roda `brew trust` + reinstala. Instalamos sempre com o nome totalmente
qualificado (owner/repo/formula) para evitar ambiguidade com o core. A lista "Meus
programas" guarda apenas nomes (tap+fórmula) em UserDefaults — nada de segredos.
