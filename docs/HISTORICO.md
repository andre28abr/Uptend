# Histórico do Projeto — Uptend (antes MacForge)

> Registro cronológico de tudo que foi feito, decidido e conversado. Serve como memória do projeto para consulta futura. **Sempre adicionar ao final** (mais recente embaixo). Nunca reescrever o passado — só acrescentar.

Formato de cada entrada: `## AAAA-MM-DD — Título` seguido do que aconteceu.

---

## 2026-07-07 — Concepção inicial do projeto

**O que foi conversado:**
- Definida a ideia central: app estilo **DMG para Mac**, pessoal, para reinstalar após formatar/reiniciar o Mac.
- Objetivo: central única para instalar essenciais, atualizar Homebrew/apps, sincronizar pastas Git, limpar arquivos básicos (estilo CleanMyMac simplificado) e desinstalar programas.
- Definidos princípios de design: **interface bonita, estilo Mac nativo, baseada em listas, sem muitas animações**.

**O que foi feito:**
- Criado `BRAINSTORM.md` com visão geral, funcionalidades, ideias novas, sugestões de nome e opções de stack.
- Criado `HISTORICO.md` (este arquivo).
- Criado `DECISOES.md` para registrar decisões técnicas com justificativa.

**Sugestões de nome levantadas:** Rebrew (⭐ favorito), Cauldron, MacForge, Alembic, FreshMac.

**Stack em avaliação:** Tauri (⭐), Electron, SwiftUI nativo.

**Pendências / próximos passos:**
- [ ] Verificar disponibilidade dos nomes no GitHub.
- [x] Escolher o nome definitivo.
- [ ] Escolher a stack.
- [ ] Montar plano de arquitetura e estrutura inicial do projeto.

---

## 2026-07-07 — Nome definido: MacForge

**Decisão:** nome do projeto será **MacForge** (registrado em `DECISOES.md` [D001]).
- Descartados: Rebrew, Cauldron, Alembic, FreshMac.
- Projeto fica **somente local** por enquanto; push para o GitHub será feito depois pelo usuário.

**Próximos passos:**
- [ ] Escolher a stack (favorito atual: Tauri).
- [ ] Montar plano de arquitetura e estrutura inicial do projeto.

---

## 2026-07-07 — Stack, escopo de funcionalidades e diretrizes de design

**Decisões:**
- **Stack definida: SwiftUI nativo** (macOS). Descartados Tauri e Electron. Registrado em `DECISOES.md` [D002].
- **Diretrizes de design** fixadas em `DECISOES.md` [D003]: estilo Mac nativo, listas, poucas animações, **sem emojis**, ícones flat, tema claro/escuro, ícones pequenos só com tooltip no hover (nome apenas quando o ícone for intuitivo).

**Escopo:**
- 7 ideias promovidas de "ideias futuras" para **Funcionalidades Fase 2 (confirmadas)** no `BRAINSTORM.md`: Profiles/Brewfile, Dotfiles & configs, Segurança, Log/histórico de ações, Modo "primeira vez", Busca, Agendamento.
- `BRAINSTORM.md` reescrito sem emojis para seguir o próprio padrão de design.

**Próximos passos:**
- [ ] Montar plano de arquitetura e estrutura inicial do projeto SwiftUI.
- [ ] Definir distribuição (.dmg, assinatura/notarização).

---

## 2026-07-07 — Protótipo da interface (SwiftUI) rodando localmente

**Decisões registradas** (em `DECISOES.md`): D004 app único (canivete suíço), D005 layout de 3 colunas, D006 UI-first sem DMG. Nome MacForge revalidado.

**Ajustes de escopo:**
- Removido "Renomear arquivos em lote" (o Finder já resolve).
- Docker esclarecido: painel gráfico que **pilota** o Docker instalado (não substitui).

**O que foi feito:**
- Criado o projeto `MacForge/` como Swift Package (executável SwiftUI, macOS 14+).
- Interface completa com dados de exemplo (mock): layout `NavigationSplitView` de 3 colunas e telas para todas as categorias — Início (dashboard + saúde), Instalar (por categorias), Atualizar, Limpeza (com seleção e total de espaço), Git (status/pull/push), Docker (containers/imagens/volumes/redes), Segurança (checagens + ferramentas), Ferramentas (grid canivete), Configurações (tema claro/escuro).
- Regras de design aplicadas: SF Symbols (ícones flat) com tooltip via `.help()`, sem emojis, tema claro/escuro, listas.
- Criado `build-app.sh` (monta `MacForge.app` local, sem DMG) e `README-DEV.md`.
- Build compilou e o app rodou localmente (verificado).

**Ambiente:** macOS 26.5.1, Xcode instalado, Swift 6.3.

**Próximos passos:**
- [ ] Coletar feedback do UX e ajustar a interface.
- [ ] Começar a ligar a lógica real, categoria por categoria (provável começar por Homebrew: Instalar/Atualizar).

---

## 2026-07-08 — Homebrew ligado de verdade (Instalar + Atualizar)

**Feedback do usuário:** aprovou a interface ("melhor que esperado"), achou intuitiva, notou espaço sobrando. Direção escolhida: partir para a lógica real (recomendada).

**O que foi feito:**
- Camada de execução de comandos: `Services/Shell.swift` (`capture` para comandos rápidos parseáveis, `stream` para saída ao vivo) com PATH do Homebrew.
- `Services/BrewService.swift` (@MainActor ObservableObject): detecta o brew, lê instalados (`brew list --formula/--cask`), lê desatualizados (`brew outdated --json=v2`), e executa install/uninstall/upgrade/update.
- **Instalar** agora é real: catálogo com tokens reais do Homebrew, estado instalado/não vem do brew, botões instalam/desinstalam de verdade. "Instalar tudo" instala os pendentes.
- **Atualizar** agora é real: lista fórmulas/casks desatualizados do brew; "Atualizar tudo" roda `brew update && brew upgrade`; botão por item faz upgrade.
- Folha de log ao vivo (`RunningTaskView`) mostra a saída do comando em tempo real.
- **Dashboard** parcialmente real: contagem de pacotes instalados, atualizações pendentes e espaço livre em disco reais.
- Polimento de layout: grids adaptáveis (dashboard e ferramentas) para aproveitar a largura; largura máx. de conteúdo nas listas.
- Tela de "Homebrew não encontrado" com link para brew.sh.
- Package em modo de linguagem Swift 5 (evita atrito de concorrência estrita nesta fase).

**Verificado:** build OK; comandos testados (58 fórmulas + 3 casks desatualizados na máquina); app rodando localmente.

**Próximos passos:**
- [ ] Feedback do fluxo real de instalar/atualizar.
- [ ] Ligar próxima categoria (candidatas: Limpeza real, ou Git real).
- [ ] Melhorias: auto-scroll do log, tratamento de senha/sudo quando necessário.

---

## 2026-07-08 — Padrões de engenharia (testes, segurança, privacidade)

**Definido pelo usuário:** criar testes automatizados quando fizer sentido; revisar segurança a cada passo (OWASP Top 10, NIST, etc.) pensando na distribuição via Homebrew; código 100% desde o início com Security by Design e Privacy by Design.

**O que foi feito:**
- Criado `PADROES.md` (referência obrigatória): qualidade de código, política de testes, segurança (OWASP/ASVS/NIST SSDF/CWE), privacidade local-first, distribuição, e "Definition of Done". Decisão registrada em `DECISOES.md` [D007].
- **Segurança aplicada na prática:** `Services/Security.swift` com `InputValidator` (regex allowlist para tokens do brew, defesa em profundidade). `BrewService` agora valida todo token antes de executar install/uninstall/upgrade; token inválido é bloqueado sem rodar nada.
- **Base de testes:** alvo `MacForgeTests` com Swift Testing. 9 testes (segurança + lógica), incluindo casos de injeção (`node; rm -rf /`, `$(whoami)`, backticks, pipes) que devem ser rejeitados, integridade/unicidade do catálogo, formatação e mapeamentos.
- Scripts: `test.sh` (roda os testes com o toolchain do Xcode, necessário para o framework de testes).

**Verificado:** `./test.sh` verde — 9 testes passando em 2 suítes.

**Observação de ambiente:** `xcode-select` aponta para o Command Line Tools, que não traz XCTest/Swift Testing; por isso os testes rodam via `DEVELOPER_DIR=/Applications/Xcode.app/...` (encapsulado no `test.sh`). O build do app continua funcionando com o CLT.

**Próximos passos:**
- [ ] Aplicar a "Definition of Done" (incl. `/security-review`) a cada nova feature.
- [ ] Seguir ligando categorias reais (Limpeza ou Git) já dentro desses padrões.

**Ambiente atualizado:** `xcode-select` fixado no Xcode completo (26.6), então `swift test` roda direto (sem o wrapper). `test.sh` mantido como fallback para o cenário CLT.

---

## 2026-07-08 — Reestruturação: Homebrew unificado, Aplicativos e Sistema

**Pedido do usuário:** seção dedicada ao Homebrew com tudo (buscar, instalar, remover, ver instalados, atualizar); seção para apps do Mac (listar/desinstalar); e área de Sistema completa (info, itens de inicialização, ajustes). Tudo intuitivo e com tooltips. Decisão em `DECISOES.md` [D008].

**O que foi feito:**
- Navegação reestruturada (`Category`): as antigas "Instalar" e "Atualizar" viraram a seção **Homebrew** (subseções: Buscar e instalar, Essenciais, Instalados, Atualizações, Manutenção). Novas seções **Aplicativos** e **Sistema**.
- `BrewService` estendido: `search` (brew search validado), `installToken`/`uninstallToken`, manutenção (`update`/`cleanup`/`doctor`), listas de instalados ordenadas.
- Novo `AppsService`: lista `/Applications` (nome, bundle id, tamanho, origem App Store/Manual via _MASReceipt) e desinstala movendo para a **Lixeira** (reversível) + residuais por bundle id (conservador), com diálogo de confirmação.
- Novo `SystemService`: informações do Mac (sysctl/ioreg/ProcessInfo/disco), itens de inicialização (osascript System Events, com nome validado para AppleScript), ajustes rápidos (toggles via `defaults`, sem sudo).
- Views novas: `HomebrewView` (5 subtelas), `ApplicationsView`, `SystemView`. Removidas `InstallView`/`UpdateView`.
- `InputValidator` ampliado: `isValidSearchQuery`, `isSafeAppleScriptText`.
- Testes: subiu de 9 para **14** (validação de busca, segurança de AppleScript, formatUptime, residuais sem bundle id, origem de app). `./test.sh` verde.

**Segurança (revisão rápida aplicada):** nenhuma entrada do usuário entra em comando sem validação; osascript só com texto validado; desinstalação reversível via Lixeira; comandos de sistema com domínios/chaves fixos. Pendente: rodar o skill `/security-review` completo antes de distribuir.

**Verificado:** build sem warnings; 14 testes verdes; app rodando.

**Observação:** a leitura de itens de inicialização usa o System Events e dispara, na primeira vez, o pedido de permissão de **Automação** do macOS (esperado; transparente ao usuário).

**Próximos passos:**
- [ ] Feedback da nova navegação e das telas Aplicativos/Sistema.
- [ ] Ligar categorias ainda mock (Limpeza, Git) à lógica real.
- [ ] Rodar `/security-review` antes de pensar em distribuição.

---

## 2026-07-08 — Roadmap criado + Git real (Etapa 3, item 1)

**Roadmap:** criado `ROADMAP.md` (documento vivo por etapas). Etapa 3 = ligar as categorias mock; ordem sugerida Git → Limpeza → Segurança → Docker → Ferramentas.

**Git ligado de verdade:**
- Novo `Services/GitService.swift`: pastas monitoradas escolhidas via `NSOpenPanel`, persistidas em `UserDefaults`. Lê status real com `git status --porcelain=v2 --branch` (branch, à frente/atrás, alterações locais). Ações reais fetch/pull/push com indicador de ocupado por repositório e banner de erro.
- `GitView` reescrita para dados reais; filtros todos/com alterações/dessincronizados; estado vazio com "Adicionar pasta"; remover = parar de monitorar.
- Removidos mocks: `MockData.repos` e struct `GitRepo`. Badges estáticos do Git removidos.
- Parser `parseStatus` é função pura e testável.
- Testes: 15 → **19** (parser: limpo/sincronizado, à frente e atrás, working tree suja, detached HEAD, mapeamento de status). Build sem warnings, testes verdes.

**Segurança:** `git` por caminho fixo (`/usr/bin/git`) com argumentos em array; pasta vem do `NSOpenPanel` (não é texto livre). Sem injeção. Local-first.

**Verificado:** build OK, 19 testes verdes, app rodando.

**Próximos passos:**
- [ ] Feedback do Git real (adicionar uma pasta e testar pull/push).
- [ ] Etapa 3 item 2: **Limpeza** real (com cuidado — ações destrutivas reversíveis).

---

## 2026-07-08 — Limpeza real (Etapa 3, item 2)

**Limpeza ligada de verdade, com foco em segurança:**
- Novo `Services/FileUtils.swift`: cálculo de tamanho em disco (reutilizado pelo AppsService, que perdeu sua cópia — reuso conforme PADROES).
- Novo `Services/CleanupService.swift`: alvos reais por subseção com `CleanupTarget.Kind`:
  - `emptyPermanently` (Lixeira — permanente), `trashContents` (caches/logs → Lixeira, reversível), `trashPaths` (downloads >30 dias, Xcode DerivedData, cache npm/CocoaPods → Lixeira), `brewCleanup` (via BrewService, com log).
  - Tamanhos calculados em background; propriedade `isReversible` guia a mensagem de confirmação.
- `CleanupView` reescrita: tamanhos reais, botão por alvo, **diálogo de confirmação** com aviso de reversível vs permanente, e nota explicativa. `brew cleanup` abre a folha de log.
- Removidos mocks: `MockData.cleanup` e struct `CleanupEntry`.
- Testes: substituído o teste antigo de formatação (MB) pelo teste dos alvos de limpeza (Lixeira permanente, caches reversível, dev inclui brew cleanup). Total **19** verdes.

**Segurança/Privacidade:** ações destrutivas reversíveis via Lixeira (exceto esvaziar a Lixeira, que é permanente por natureza e avisado); nenhum caminho vem de texto livre (todos derivados do home do usuário); confirmação obrigatória. Local-first.

**Verificado:** build sem warnings, 19 testes verdes, app rodando.

**Próximos passos:**
- [ ] Feedback da Limpeza.
- [ ] Etapa 3 item 3: **Segurança** real (FileVault, Firewall, Gatekeeper, SIP, updates — leitura de status).

---

## 2026-07-08 — Segurança real + ferramentas (Etapa 3, item 3)

**Segurança ligada de verdade:**
- Novo `Services/SecurityService.swift`: status real (somente leitura, sem sudo) de FileVault (`fdesetup status`), Firewall (`socketfilterfw --getglobalstate`), Gatekeeper (`spctl --status`), SIP (`csrutil status`). Interpretadores puros e testáveis. Atualizações do sistema (`softwareupdate -l`) sob demanda (é lento/rede).
- Novo `Services/CryptoTools.swift`: `PasswordGenerator` (senha local, sem rede) e `HashUtil` (SHA-256 de arquivo via CryptoKit, leitura em blocos).
- `SecurityView` reescrita: aba Status com dados reais + verificação de updates sob demanda; aba Ferramentas com gerador de senhas interativo e hash de arquivo (com copiar). Removido `MockData.securityChecks`.
- Testes: 19 → **27** (interpretadores dos 4 status + updates, gerador de senha tamanho/charset/mínimo, vetor conhecido SHA-256 de "abc").

**Verificado:** build sem warnings; 27 testes verdes; comandos de status checados na máquina (todos retornam no formato esperado; Mac com tudo ativo); app rodando.

**Segurança/Privacidade:** só leitura de status; gerador de senha e hash 100% locais (nada de rede); comandos por caminho absoluto com args em array.

**Próximos passos:**
- [ ] Etapa 3 item 4: **Docker** real (detectar, listar, iniciar/parar/remover).
- [ ] Etapa 3 item 5: **Ferramentas** (canivete) reais.

---

## 2026-07-08 — Correção: Lixeira não identificava itens (TCC)

**Problema (reportado pelo usuário):** a Limpeza mostrava a Lixeira vazia mesmo com itens.

**Causa:** `~/.Trash` é protegida por TCC — ler a pasta direto retorna "Operation not permitted" sem "Acesso Total ao Disco". O cálculo dava 0 e desabilitava o botão. Confirmado no shell (`ls ~/.Trash` → Operation not permitted; Finder via AppleScript → 1 item).

**Solução:** para a Lixeira, não ler a pasta — usar o **Finder via AppleScript** (`count items of trash` para contar, `empty the trash` para esvaziar). Troca a exigência de Acesso Total ao Disco por permissão de **Automação** (Finder), mais simples. Novo `CleanupTarget.Kind.emptyTrash` + campo `count`; a Lixeira agora mostra a contagem de itens em vez de bytes.

**Verificado:** build sem warnings, 27 testes verdes, app rodando.

**Observação:** ao abrir a subseção Lixeira pela primeira vez, o macOS pede permissão de Automação para controlar o Finder (esperado; autorize para ver a contagem e esvaziar).

---

## 2026-07-08 — Docker real (Etapa 3, item 4)

**Ambiente:** máquina usa OrbStack (docker CLI 29.4.0 em /usr/local/bin/docker); no momento o daemon estava parado — bom para validar o estado "parado".

**Docker ligado de verdade:**
- Novo `Services/DockerService.swift`: detecta o binário (OrbStack/Docker Desktop), verifica o daemon (`docker info`), e lista containers/imagens/volumes/redes fazendo parse do JSON (`--format {{json .}}`). Ações: start/stop/remove container, remove imagem/volume, ver logs (`docker logs --tail 200`).
- `DockerView` reescrita com 3 estados: **ausente** (instalar via Homebrew), **parado** (botão "Abrir OrbStack/Docker"), **rodando** (listas reais + ações + folha de logs).
- Removidos mocks: structs Docker* em Models e `MockData` (containers/images/volumes/networks).
- `InputValidator.isSafeArgument` para IDs/nomes do Docker (defesa em profundidade).
- Testes: 27 → **32** (parse de containers com/sem campo State, imagens, volumes/redes, e ignorar linhas inválidas).

**Segurança:** docker por caminho detectado com args em array; IDs/nomes vêm da saída do próprio docker e passam por `isSafeArgument`. Sem shell. Local.

**Verificado:** build sem warnings, 32 testes verdes, app rodando (mostra o estado "OrbStack não está rodando" corretamente, já que o daemon está parado).

**Próximos passos:**
- [ ] Etapa 3 item 5 (último): **Ferramentas** (canivete) reais.

---

## 2026-07-08 — Ferramentas (canivete) reais — Etapa 3 CONCLUÍDA

**Ferramentas ligadas de verdade** (cada uma virou subseção de Ferramentas):
- `Converters.swift` (puro): Base64 (encode/decode), JSON pretty, timestamp→data, hex→RGB.
- `NetworkTools.swift`: IP local (getifaddrs, sem rede), IP público (URLSession, sob demanda/transparente), ping (host validado).
- `PortsService.swift`: lista portas TCP em escuta (`lsof`), encerra processo (kill, com confirmação).
- `SSHService.swift`: lista chaves públicas de ~/.ssh (copiar) e gera ed25519 (nome/comentário validados).
- `ClipboardService.swift`: histórico de clipboard em memória (poll do NSPasteboard enquanto o app está aberto; nada persistido — Privacy by Design).
- QR Code via CoreImage (local). Senha e hash reaproveitados da aba Segurança.
- `InputValidator` ampliado: `isValidHost`, `isValidFileName`. Removidos `MockData.tools` e struct `ToolItem`.
- Testes: 32 → **37** (Base64 round-trip, JSON, timestamp UTC, hex→RGB, parser de `lsof`).

**Segurança/Privacidade:** comandos por caminho absoluto com args em array; host/nome de arquivo/pid validados; IP público é ação explícita (única saída de rede, transparente); clipboard só em memória. Sem shell.

**Verificado:** build sem warnings, 37 testes verdes, `lsof`/IP local conferidos na máquina, app rodando.

**ETAPA 3 CONCLUÍDA** — todas as categorias (Homebrew, Aplicativos, Sistema, Git, Limpeza, Segurança, Docker, Ferramentas) agora têm lógica real.

**Próximos passos (Etapa 4):**
- [ ] Rodar `/security-review` completo (recomendado agora que o núcleo está real).
- [ ] Persistência ampliada, dashboard 100% real, ícone do app, auto-scroll do log, toasts.

---

## 2026-07-08 — Categoria Rede + ícone na barra de menu (Etapa 4)

**Pedido do usuário:** separar Rede das Ferramentas e ampliar (velocidade da conexão, etc., sem virar nmap); criar ícone na barra de menu com mini dashboard e mini-gráficos.

**O que foi feito:**
- Novo `Services/MonitorService.swift`: amostra CPU (host_statistics), memória (host_statistics64), e tráfego de rede (getifaddrs/if_data) a cada 1,5s, mantendo histórico para mini-gráficos. `formatRate` puro e testável.
- Componente `Sparkline` (mini-gráfico) em Components.
- Nova **categoria Rede** (`NetworkView`): Velocidade (download/upload ao vivo com sparklines + interfaces), Endereços IP (local + público sob demanda), Ping, DNS (`dig +short`). Removida a subseção "IP e rede" das Ferramentas; `dnsLookup` adicionado ao NetworkTools.
- **Ícone na barra de menu** via `MenuBarExtra` (estilo janela): `MenuBarDashboard` com CPU, memória e rede (mini-gráficos) + botões "Abrir MacForge" e "Sair". O `MonitorService` alimenta tanto a barra de menu quanto a aba Rede.
- Testes: 37 → **38** (formatação de taxa de rede).

**Segurança/Privacidade:** leitura de contadores do sistema (local); dig/ping com host validado; IP público continua sob demanda. Sem shell.

**Verificado:** build sem warnings, 38 testes verdes, app rodando com ícone na barra de menu.

**Observações/pendências:** true "minimizar só para a barra" (ocultar do Dock) fica como ajuste futuro; a categoria Rede pode ganhar mais itens (uso por app, histórico, teste de velocidade) depois.

---

## 2026-07-08 — Renomeação: MacForge → Uptend

**Motivo:** o usuário descobriu que "MacForge" já é um app conhecido (framework de plugins macOS). Fizemos busca ampla na web (2 levas, 88 nomes verificados por sub-agentes) — quase toda palavra comum estava ocupada no espaço de software/Mac. Escolhido **Uptend** (inventado: *up* + *tend* = "manter em dia"), único e fácil de falar/escrever. Decisão em `DECISOES.md` [D009] (supera [D001]).

**O que foi feito (rename completo):**
- Código: pasta `MacForge/` → `Uptend/`; módulo/target Swift `MacForge` → `Uptend`; `Sources/MacForge` → `Sources/Uptend`; `MacForgeApp.swift`/struct → `UptendApp`; `Tests/MacForgeTests` → `Tests/UptendTests`; `@testable import Uptend`.
- Scripts: `build-app.sh` gera `Uptend.app`; bundle id `com.andresouza.uptend`.
- Strings de UI e nome na barra de menu → "Uptend".
- Docs vivos (Brainstorm, Roadmap, Padrões) renomeados; HISTORICO e DECISOES preservam o passado ("MacForge") e registram a troca.
- Ajustado 1 teste que usava "MacForge" como exemplo de Base64.

**Verificado:** build sem warnings, 38 testes verdes, `Uptend.app` rodando.

**Pendente antes de publicar:** verificar registro de `uptend` (GitHub, domínios uptend.app/.dev, App Store).

---

## 2026-07-08 — Ampliação dos "Ajustes rápidos" (Sistema)

**Pedido do usuário:** mais opções de configuração do Mac na aba Sistema > Ajustes rápidos.

**O que foi feito:**
- `SystemToggle` refatorado: ganhou `section`, `defaultOn` (padrões do macOS quando a chave não existe), `inverted` (ex.: sombra vs. `disable-shadow`) e `restart` (Finder/Dock/SystemUIServer) no lugar do antigo `restartFinder`.
- Ajustes ampliados de 4 → **15**, agrupados por seção:
  - **Finder:** arquivos ocultos, extensões, barra de caminho, barra de status, pastas no topo, caminho completo no título.
  - **Dock:** ocultar automaticamente, apps recentes, minimizar no ícone do app, reorganizar Espaços por uso.
  - **Teclado e texto:** correção automática, aspas curvas, travessões inteligentes.
  - **Capturas de tela:** sombra em janela (invertido), incluir data no nome.
- Leitura respeita padrão do macOS e inversão; ao alterar, reinicia o processo certo (killall Finder/Dock/SystemUIServer). `SystemView` agora agrupa por seção com cabeçalhos + botão recarregar.
- Teste novo (39 no total): ordem das seções, ids únicos, config do caso invertido.

**Segurança/Privacidade:** tudo via `defaults` por usuário (sem sudo), domínios/chaves fixos (sem entrada do usuário), reversível.

**Verificado:** build sem warnings, 39 testes verdes, app rodando.

---

## 2026-07-08 — Rede expandida (com gráficos)

**Pedido do usuário:** mais funções de rede/dispositivo, com gráficos (marcou todos os módulos, incl. limítrofes).

**O que foi feito** (categoria Rede passou de 4 para 8 subseções):
- **Visão geral turbinada:** gráfico de área/linha do tráfego (Swift Charts), cartões de download/upload agora + **totais da sessão** (novos campos em MonitorService), interfaces.
- **Wi-Fi** (`WiFiService`, CoreWLAN): medidor de sinal (RSSI→%), canal, banda (2.4/5/6GHz), taxa, segurança, SSID. Poll ao vivo com start/stop no aparecer/desaparecer.
- **Qualidade** (`LatencyMonitor`): ping contínuo a 1.1.1.1, gráfico de latência (Swift Charts), média, jitter, perda de pacotes.
- **Endereços+:** IP local, **gateway** (route), **DNS** (scutil), **MAC** (ifconfig), e **IP público + provedor/cidade** (ipinfo.io, sob demanda).
- **Conexões ativas** (`ConnectionsService`): lsof de conexões TCP estabelecidas (comando + host remoto).
- **Teste de velocidade** (`SpeedTest`): download/upload reais via endpoints da Cloudflare (sob demanda, avisado).
- Componentes reaproveitados (ScreenHeader, cardBackground, Sparkline) + Gauge nativo para o sinal.
- Testes: 39 → **45** (parse de latência, stddev/jitter, mapeamento RSSI→%, gateway/DNS/MAC, conexões).

**Segurança/Privacidade:** tudo leitura local, exceto IP-info e teste de velocidade (ações explícitas, avisadas). Host de ping/dns validado; conexões são só do próprio Mac. SSID depende de permissão de Localização do macOS (sem isso, mostra aviso). Sem shell.

**Verificado:** build sem warnings, 45 testes verdes, app rodando.

---

## 2026-07-08 — Segurança: subseção "Ferramentas" renomeada

**Feedback do usuário:** o menu "Ferramentas" em Segurança estava vago — na prática é o gerador de senhas (e o hash).

**O que foi feito:** subseção "Ferramentas" dividida em **"Senhas"** (gerador) e **"Hash de arquivo"**, cada uma com nome honesto. `SecurityView` passou a rotear por subseção. Segurança agora: Status, Senhas, Hash.

**Observação (dívida a decidir):** senha e hash aparecem também na categoria **Ferramentas (canivete)** — há duplicação. A decidir com o usuário: manter nos dois lugares ou centralizar em um só. Build sem warnings, 45 testes verdes.

**Resolvido (opção 1):** senha/hash centralizados em **Segurança**; removidos da categoria Ferramentas. Ferramentas ficou com: Conversores, QR Code, Portas, Chave SSH, Clipboard. Sem duplicação. 45 testes verdes.

---

## 2026-07-08 — Revisão de segurança (item 1 da fila) + correções

**Como foi feito:** como o projeto ainda não é repositório git (o skill `/security-review` depende de diff), rodei uma auditoria de segurança do código inteiro via subagente adversarial, contra o modelo de ameaça + OWASP/CWE.

**Veredito da auditoria:** sem injeção de comando/shell, sem falhas críticas, sem sudo, rede só HTTPS em ações explícitas, sem telemetria. Código sólido. Achados corrigidos:
- **[MÉDIA] Path traversal via bundleID** (`AppsService.residualURLs`): o bundle id vinha do Info.plist do app (não confiável) e virava caminho de arquivo. Corrigido: valida contra reverse-DNS (`InputValidator.isValidBundleID`, sem `/` nem `..`) e confirma que cada caminho resolvido fica dentro de `~/Library` (standardizedFileURL + hasPrefix).
- **[BAIXA-MÉDIA] Option injection**: validadores aceitavam valor começando com `-`. Endurecidos brewToken/host/fileName/searchQuery/isSafeArgument para proibir `-` inicial.
- **[BAIXA] removeLoginItem sem confirmação**: adicionado confirmationDialog (consistência com as demais ações destrutivas).
- **[BAIXA] Resíduo de renome**: comentário padrão de chave SSH `"macforge"` → `"uptend"`.
- SSH sem passphrase (`-N ""`): mantido como escolha de design (baixa prioridade), a revisitar.

**Testes:** 45 → **47** (option injection barrada; validação de bundle id contra traversal).

**Verificado:** build sem warnings, 47 testes verdes, app rodando.

**Pendência de distribuição (fora do código):** avaliar App Sandbox/hardened runtime + entitlements mínimos ao empacotar para notarização.

---

## 2026-07-08 — Ícone do app (item 2) + permissão de Localização/SSID (item 3)

**Ícone (item 2):** criado `make-icon.swift` (AppKit/CoreGraphics) que desenha o ícone — seta de tendência para cima (up-trend, casa com "Uptend") branca sobre gradiente azul→teal em squircle nativo — e exporta os PNGs do .iconset. Gerado `Resources/Uptend.icns` (via iconutil). `build-app.sh` agora copia o .icns e define `CFBundleIconFile`. Ícone aprovado visualmente.

**Localização/SSID (item 3):** novo `LocationService` (CLLocationManager) pede autorização de Localização — exigência do macOS para ler o nome (SSID) da rede. `WiFiInfo` ganhou `ssidLocked`; quando o SSID está bloqueado, o card Wi-Fi mostra botão "Mostrar nome" que dispara o pedido, e ao autorizar o Wi-Fi recarrega. Info.plist ganhou `NSLocationUsageDescription`/`NSLocationWhenInUseUsageDescription` (texto deixa claro que nada de localização é coletado).

**Verificado:** build sem warnings, 47 testes verdes, app rodando com o novo ícone.

**Fila do usuário:** 1) security-review ✅ 2) ícone ✅ 3) Localização/SSID ✅ 4) Etapa 5 (Profiles/Brewfile, Dotfiles, Modo "primeira vez", Log de ações, Agendamento) — próximo.

---

## 2026-07-08 — Etapa 5 completa (item 4 da fila)

**Nova categoria Setup** (na barra lateral, logo após Início) com 3 subseções + extras no Início e Configurações:

- **Primeira vez** (`FirstRunView`): wizard que guia por Homebrew → Essenciais → Perfil → Dotfiles → Ajustes, cada passo navegando para a seção certa.
- **Perfis (Brewfile)** (`ProfilesService` + `BrewService.dumpBundle/installBundle`): exporta tudo instalado (`brew bundle dump --describe`) para `~/Library/Application Support/Uptend/Profiles/<nome>.brewfile` e restaura (`brew bundle install`). Listar/restaurar/excluir/revelar no Finder.
- **Dotfiles** (`DotfilesService`): escolhe pasta de backup, lista dotfiles de uma **allowlist fixa** (sem path traversal), restaura copiando para ~/ com **backup .uptend.bak** e confirmação.
- **Atividade** (Início) (`ActionLog`, singleton persistente em UserDefaults): registra install/remove/limpeza/git/update/atualização. Ligado nos serviços (BrewService, AppsService, CleanupService, GitService).
- **Agendamento** (Configurações) (`ScheduleService`): intervalo em dias para limpeza/updates, status vencido/em dia (lógica pura testável), "rodar agora" e "marcar como feito". Só lembra com o app aberto (sem launchd nesta versão).

- Testes: 47 → **51** (isDue/statusText do agendamento; allowlist de dotfiles segura; caminho do perfil dentro de Profiles).

**Segurança/Privacidade:** dotfiles restringidos a allowlist + backup reversível; perfis em Application Support com nome validado; ActionLog e histórico só locais. Sem shell novo.

**Verificado:** build sem warnings, 51 testes verdes, app rodando.

**TODA A FILA DO USUÁRIO CONCLUÍDA (1–4).** Categorias atuais: Início, Setup, Homebrew, Aplicativos, Limpeza, Git, Docker, Rede, Segurança, Sistema, Ferramentas, Configurações — todas reais.

---

## 2026-07-08 — Tradução PT-BR, polimentos e distribuição

**Tradução:** rótulos Download/Upload → Baixando/Enviando (mantido "Downloads" para a pasta e termos técnicos como Ping/DNS/Hash/Mbps). Info.plist ganhou `CFBundleDevelopmentRegion` pt-BR + `CFBundleLocalizations` para os **menus do sistema** (Editar/Visualizar/Janela/Ajuda/Sair) aparecerem em português quando o macOS estiver em PT.

**Polimentos:**
- **Auto-scroll do log** (RunningTaskView) via ScrollViewReader.
- **Toasts** de sucesso/erro (`ToastCenter` + `ToastView`, overlay no rodapé); "Copiado" ao copiar (Clipboard.copy centralizado, inclusive senha/hash da Segurança).
- **Aviso de manutenção vencida** no Início (banner quando limpeza/updates estão vencidos, com atalho para Agendamento).

**Distribuição (Etapa 7 parcial):**
- `make-dmg.sh` → `build/Uptend.dmg` (hdiutil, com link para Aplicativos). build-app.sh ganhou `--no-open`.
- `README.md` público (PT), `LICENSE` (MIT), `.gitignore`.
- **git inicializado** (branch main, commit inicial; 66 arquivos). Push pendente — o usuário cria o repo/org `uptend` e faz push.
- Pendente (fora do meu alcance): assinatura Developer ID + notarização (exige conta paga Apple) e cask no Homebrew.

**Verificado:** build sem warnings, 51 testes verdes, DMG gerado (1,7 MB), app rodando.

---

## 2026-07-08 — 8 novas funcionalidades (analisador de espaço, comparador, saúde, foco, runtimes, favoritos, relatório, agendamento em 2º plano)

Distribuídas nas categorias existentes (sem novo item na barra lateral):
- **Limpeza > Espaço em disco** (`SpaceAnalyzerService` + `SpaceAnalyzerView`): tamanho por item, navegação para dentro, barra proporcional.
- **Setup > Comparar perfil** (`ProfilesService.parseBrewfile` + `CompareProfileView`): diff entre o instalado e um Brewfile salvo (faltando/sobrando), com instalar/desinstalar por item.
- **Sistema > Saúde** (`HealthService`): bateria (condição, ciclos, capacidade, carga) via SPPowerDataType + status SMART dos discos (SPNVMe/SPSerialATA).
- **Sistema > Modo foco** (`FocusService`): oculta ícones da Mesa + Dock automático (reversível) e atalho para o Foco dos Ajustes.
- **Sistema > Relatório** (`SystemReport` + `ReportView`): gera Markdown com specs/apps/segurança; copiar ou salvar.
- **Ferramentas > Versões (runtime)** (`RuntimesService`): mostra Node/Python/Ruby; troca a global via pyenv/rbenv (Node via nvm é só leitura).
- **Git > Favoritos** (`FavoritesService`): lista de URLs de repos (persistida) e "clonar todos" numa pasta escolhida.
- **Configurações > Agendamento**: toggle de **lembretes em segundo plano** que instala um LaunchAgent (`launchctl`) enviando notificação (osascript) no intervalo, mesmo com o app fechado.

**Segurança:** bundleID já validado; URLs de repo e versões validadas (`isSafeArgument`/`isValidRepoURL`); Focus/foco e agendamento por `defaults`/launchd do usuário (sem sudo); análise de espaço e saúde só leitura. Sem shell.

**Testes:** 51 → **55** (parse de Brewfile, validação de URL de repo, parse de bateria e SMART).

**Verificado:** build sem warnings, 55 testes verdes, app rodando.

---

## 2026-07-08 — Docker: tela didática + detecção de múltiplos motores

**Pedido do usuário:** explicar melhor por que o Docker precisa de um motor rodando, e detectar/oferecer não só OrbStack mas outros motores.

**O que foi feito:**
- `DockerService` ganhou o conceito de **motor de containers** (`ContainerEngine`): reconhece OrbStack, Docker Desktop, Rancher Desktop (apps) e Colima, Podman (CLI). `detect()` lista os instalados (`engines`); `startEngine()` abre o app (`open -a`) ou inicia o CLI (`colima start` / `podman machine start`).
- `DockerView`: quando o daemon não está ativo, mostra uma **tela didática** — explica que containers vivem dentro do motor (mini VM Linux) e que o Uptend pilota o motor, não o substitui — e lista os **motores detectados** com botão Abrir/Iniciar. Se nenhum motor instalado, oferece instalar OrbStack via Homebrew. Removidas as telas antigas `missing`/`notRunning` e o método `openApp` (código morto).

**Contexto:** confirmado na máquina do usuário que o OrbStack está instalado mas com o daemon parado — comportamento esperado; a tela agora explica isso.

**Verificado:** build sem warnings, 55 testes verdes, app rodando.

---

## 2026-07-08 — Central de notificações (sininho no topo)

**Pedido do usuário:** um sininho no canto superior direito que englobe atividades, coisas a fazer e atualizações pendentes, bem separadas.

**O que foi feito:** `NotificationCenterView` (popover) + botão de sino na toolbar do `RootView` (placement `.primaryAction`) com **badge numérico** (contagem de pendências). O popover tem duas seções:
- **A fazer:** atualizações pendentes (brew.outdated → leva a Homebrew>Atualizações), manutenção vencida (agendamento → leva a Configurações/Limpeza), pontos de atenção da segurança (leva a Segurança). Cada linha navega e fecha o popover.
- **Atividade recente:** últimas 8 entradas do `ActionLog`, com "Limpar atividade".
Env objects passados explicitamente ao popover (evita ambiente não herdado). Segurança é carregada ao abrir se ainda vazia.

**Verificado:** build sem warnings, 55 testes verdes, app rodando.

**Correção (mesmo dia):** o popover do sino abria e fechava na hora. Primeira tentativa (encapsular em `NotificationBell`) não resolveu — é o bug crônico do `.popover` em toolbar do macOS, que auto-dismissa. **Solução final:** abandonei o `.popover`; o sino agora só alterna `AppState.showNotifications`, e o painel é um **overlay flutuante** (`NotificationPanel`) ancorado no topo direito do `RootView`, com captura de clique-fora para fechar. Estável. Build OK, 55 testes verdes.

**Ajuste (mesmo dia):** removida a subseção **Início > Atividade** (ficou redundante com a "Atividade recente" do sino). Início agora só tem Visão geral e Saúde do sistema. Build OK, 55 testes verdes.

---

## 2026-07-08 — Antivírus ClamAV (Segurança > Antivírus)

**Pedido do usuário:** frente gráfica completa do ClamAV (instalável via Homebrew): quarentena, atualizações, escanear, controlar tudo pela interface.

**O que foi feito:**
- Novo `Services/ClamAVService.swift`: detecta `clamscan`/`freshclam` (via `Shell.binaryPath`, novo helper reutilizável); mostra versão das definições (`clamscan --version`); **configura** (copia `freshclam.conf.sample` comentando a linha `Example`); **atualiza definições** (`freshclam`, com log ao vivo); **escaneia** pasta/arquivo (`clamscan -r --infected [--move=quarentena]`, streaming); gerencia **quarentena** (pasta em Application Support/Uptend/Quarentena; listar/excluir/revelar). Parsers `parseScan`/`parseVersion` puros e testáveis.
- Nova subseção **Segurança > Antivírus (ClamAV)** (`ClamAVView`): se não instalado, oferece `brew install clamav`; se instalado, botões Atualizar definições/Escanear, toggle de quarentena, log ao vivo com resumo de ameaças, lista de quarentena com exclusão (confirmação — permanente por serem maliciosos).
- Roteado como tela cheia no SecurityView (evita scroll aninhado).
- Testes: 55 → **58** (parse de scan com/sem ameaças, parse de versão/definições).

**Segurança:** tudo como usuário (sem sudo); caminho de scan vem do NSOpenPanel; config escrita no prefix do brew (user-owned); sem shell. Na máquina do usuário o ClamAV não está instalado — o app mostra a tela de instalação.

**Verificado:** build sem warnings, 58 testes verdes, app rodando.

**Ajuste UX (mesmo dia):** usuário instalou o ClamAV e o `freshclam` funcionou, mas imprimia "ERROR: NULL X509 store" (aviso inofensivo do macOS) — assustava. Agora `updateDefinitions` avalia sucesso pelo código de saída + conteúdo ("updated"/"up to date") e expõe `updateStatus`; a tela mostra card verde "Definições atualizadas com sucesso" + nota explicando que o aviso X509 é inofensivo. Corrigido também o resumo de ameaças (só aparece após scan, não após update). Build OK, 58 testes verdes.

**Modos de scan (mesmo dia):** além de "Pasta…", adicionados **Rápido** (Downloads, Mesa, Aplicativos, /private/tmp) e **Completo** (pasta pessoal + Aplicativos, com confirmação). `ClamAVService.scan` passou a aceitar múltiplos caminhos; `quickScanPaths()`/`fullScanPaths()`. A confirmação do completo avisa que pode demorar e que pastas protegidas exigem Acesso Total ao Disco (limitação de TCC — scan de `/` inteiro exigiria FDA e levaria horas). Build OK, 58 testes verdes.

**Correção de performance/UX (mesmo dia):** o usuário rodou o "Rápido" e passou de 10 min — porque eu havia incluído `/Applications` (enorme, ainda mais com Xcode). Corrigido: **Rápido = Downloads + Mesa + /private/tmp** (sem /Applications, que ficou só no Completo). Adicionado **cancelamento de scan**: `Shell.stream` ganhou callback `onStart(Process)`; `ClamAVService` guarda o processo e `cancelScan()` chama `terminate()` (código 2 = interrompido). A tela mostra banner "Escaneando…" com botão **Parar** e explica que o ClamAV é lento e só lista ameaças (--infected). Build OK, 58 testes verdes.

---

## 2026-07-12 — ClamAV: Modo turbo (daemon multinúcleo)

**Pedido do usuário:** usar vários núcleos no scan (tem 16 GB de RAM).

**O que foi feito:** o `clamscan` é single-thread; a forma correta é o daemon `clamd` (definições em memória) + `clamdscan --multiscan` (multithread). Implementado no `ClamAVService`:
- Detecta `clamd`/`clamdscan`; configura `clamd.conf` (LocalSocket, DatabaseDirectory, MaxThreads 12); `startDaemon()` (carrega o banco na RAM e daemoniza) / `stopDaemon()` (`killall clamd`); `daemonRunning` via `pgrep`.
- `scan()` passou a usar `clamdscan --multiscan --fdpass --infected` quando o daemon está ativo (multinúcleo, sem recarregar o banco), caindo no `clamscan` normal quando não está.
- `ClamAVView`: card **Modo turbo** com status e botões Iniciar/Parar + aviso de RAM (~1,5 GB).
- **Correção:** `Shell.binaryPath` não procurava em `sbin` — o `clamd` fica em `/opt/homebrew/sbin`. Adicionados os diretórios `sbin` na busca.

**Verificado:** build sem warnings, 58 testes verdes, app rodando; clamd/clamdscan presentes na máquina.

**Ajuste (mesmo dia):** o `clamdscan --fdpass` gerava avisos inofensivos "LibClamAV Warning: cli_realpath: Invalid arguments" no macOS. Como o clamd roda como o próprio usuário (iniciado pelo Uptend), o `--fdpass` é desnecessário — removido; agora `clamdscan --multiscan --infected`. Build OK, 58 testes verdes.

**Ajuste 2 (mesmo dia):** os avisos `cli_realpath` continuaram (são do clamd no macOS, um por caminho, cosméticos — o scan detecta normal; não saem por flag). Solução: **filtro de ruído** no streaming do scan (`appendScanChunk` acumula por linha e descarta linhas com "LibClamAV Warning"/"cli_realpath"), preservando ameaças e resumo. Teste `noiseFilter` adicionado. Build OK, **59 testes** verdes.

**Cronômetro + curadoria (2026-07-13):** (1) **Cronômetro ao vivo** no scan — `scanElapsed` + Timer; banner mostra "Escaneando… Xm Ys" e o log ganha "Tempo total". (2) **Completo curado** (`curatedScanPaths`): Aplicativos + pasta pessoal, pulando ~/Library/{Caches,Developer,Containers,Group Containers,CloudStorage,Mobile Documents,Logs} e ~/.Trash — mais leve e esquenta menos (motivo: usuário relatou o Mac esquentando em scan longo). (3) Novo botão **Agressivo** (`aggressiveScanPaths`): tudo sem exclusões, com confirmação avisando do tempo/calor. `formatDuration` testável. Build OK, **60 testes** verdes.

**Correção do Completo (2026-07-13):** o "curado" ainda levava 1h+ e dava "Communication error / File tree walk aborted" — porque ainda incluía blobs gigantes (~/.orbstack e ~/.docker = VMs, ~/.ollama = modelos, ~/.cache/.npm/.cargo/go = caches de dev, Pictures/Movies = mídia, Library/Metadata = Spotlight, Application Support/MobileSync = backups de iPhone). Estratégia mudou de "tudo menos o lixo" para **lista de allowlist** dos lugares relevantes a malware: /Applications, ~/Applications, Downloads, Mesa, Documentos, LaunchAgents/LaunchDaemons e Application Support (menos MobileSync). Também: `MaxThreads` = metade dos núcleos (menos calor; 4 de 8), e filtro de ruído ampliado ("File tree walk aborted", "safe quarantine action", "traverse_to"). Os warnings de "safe quarantine action" vinham do `--move` em plists protegidos (benignos). Build OK, 60 testes verdes.

**Correção 2 do Completo (2026-07-13):** ainda ~14 min — o `~/Library/Application Support` puxava caches de navegadores (Chrome/Edge/Brave/Arc/Opera/Vivaldi) e IDEs (Code/Cursor/Antigravity), milhares de arquivos. Removido do Completo (foi para o Agressivo). Completo curado agora = /Applications, ~/Applications, Downloads, Mesa, Documentos, LaunchAgents/LaunchDaemons — alto valor para malware e rápido. Build OK, 60 testes verdes.

**Cobertura de persistência (2026-07-13):** o usuário perguntou se a lista cobre onde malware realmente se instala. Confirmado que cobre apps + downloads + LaunchAgents/Daemons (os vetores principais); adicionados os **arquivos de inicialização do shell** (`.zshrc/.zprofile/.zshenv/.zlogin/.bash_profile/.bashrc/.profile`) ao Completo — persistência comum via injeção de linha, e são minúsculos/rápidos. Application Support segue só no Agressivo. Build OK, 60 testes verdes.

**Threads 4→6 (2026-07-13):** medido que o Completo demora pelo volume (clamd a 385% CPU = trabalhando; ~57 GB: /Applications 34G, Documents 17G, Downloads 5,7G) — pastas certas, tempo vem do volume. Usuário escolheu "só mais núcleos": `MaxThreads` passou de metade para **3/4 dos núcleos** (6 de 8). Documentos mantido no Completo. Precisa reiniciar o daemon (Iniciar) para a config valer. Build OK, 60 testes verdes.

**Seletor de núcleos (2026-07-13):** o usuário perguntou se o turbo escala com a máquina (sim — `activeProcessorCount` lido em runtime) e se valeria um seletor de núcleos/memória. Implementado **seletor de núcleos** (`threadOverride` persistido; `autoThreads`=3/4 dos núcleos como padrão; `effectiveThreads` usado no clamd.conf). UI: Stepper "Núcleos: N (auto)" + botão "Auto" no card do turbo; vale ao (re)iniciar. **Memória: decidido NÃO ter seletor** — clamd não expõe limite de RAM real (é o banco de assinaturas); enganaria o usuário. Build OK, 60 testes verdes.

**Rótulo "Performance" + tooltip de cautela (2026-07-13):** no card do turbo, adicionado cabeçalho "Performance", `.help()` no Stepper com texto adaptado ao Mac (mostra coreCount e o recomendado autoThreads), e um aviso laranja automático quando `effectiveThreads > autoThreads`. Tudo derivado de coreCount em runtime (escala com a máquina). Build OK, 60 testes verdes.

**Configurações na toolbar (2026-07-13):** por estética/limpeza, a Configurações saiu da barra lateral e virou um **ícone de engrenagem na toolbar** (ao lado do sino, placement `.primaryAction`), que navega para `.settings` e fica tintada de accent quando ativa. SidebarView perdeu a Section de settings. Build OK, 60 testes verdes.

**Sistema → dentro de Configurações (2026-07-13):** categoria `.system` removida do enum e da barra lateral; suas subseções (info/health/toggles/login/focus/report) mescladas em `.settings`. RootView.DetailColumn: para `.settings`, despacha essas ids para `SystemView` e o resto para `SettingsView`. Wizard (SetupView) atualizado `.system`→`.settings`. Configurações agora: Geral, Informações do Mac, Saúde, Ajustes rápidos, Itens de inicialização, Modo foco, Agendamento, Relatório, Sobre. Sidebar enxuta (10 categorias). Build OK, 60 testes verdes.

**Novo ícone: martelo no círculo azul (2026-07-13):** o usuário quis padronizar o ícone do app pelo martelo (que aparecia na UI). `make-icon.swift` reescrito com NSBitmapImageRep + SF Symbol `hammer.fill` (tom escuro) sobre squircle com gradiente azul; regenerado `Resources/Uptend.icns`. `make-dmg.sh` ganhou **ícone de volume** (`.VolumeIcon.icns` + `SetFile -a C` via ciclo UDRW→convert UDZO) para o DMG no Finder também ter o ícone. App e DMG (1,8 MB) padronizados. Dock reiniciado para atualizar cache. Build OK. (Obs.: cache de ícone do Dock ficou teimoso no Mac do usuário — arquivo do ícone está correto, resolve com `sudo rm -rf /Library/Caches/com.apple.iconservices.store` + reiniciar Dock, ou relogar.)

**Cliente GitHub gráfico (2026-07-13):** o usuário pediu uma interface tipo GitHub Desktop dentro do Uptend — conectar a conta (inclusive repos privados), ver o que mudou e fazer push num clique, sem depender do terminal. A aba Git já monitorava pastas + status + pull/push; faltavam duas peças. Implementado (escopo completo, decisão do usuário: token de acesso + fases 1-2-3):
- **Segredo no Keychain** (`Keychain.swift`): item genérico cifrado, `WhenUnlockedThisDeviceOnly`. Token nunca em UserDefaults/arquivo/log.
- **Autenticação do git sem vazar o token** (`GitAuth.swift`): helper `GIT_ASKPASS` fixo (sem segredo em disco) que lê o token de variável de ambiente `UPTEND_GIT_TOKEN` do processo `git`. Token não vai para `argv` (invisível em `ps`), nem para `.git/config`. Sem `/bin/sh -c` com interpolação — o script é estático e quem o invoca é o próprio git. Ver [D010].
- **GitHubService** (`GitHubService.swift`): `connect(token:)` valida via `GET /user`; lista repos (paginado, `affiliation=owner,collaborator,organization_member`, inclui privados); `clone(_:into:)` autenticado. Rede só em ação explícita (Privacy by Design). Erros HTTP traduzidos (401/403/…).
- **Commit + push amigável** (`GitService`): `changedFiles` (parser de `git status --porcelain` v1, testável), `commitAndPush` (`add -A` → `commit -m` → push, com `push -u origin HEAD` na primeira publicação detectada por `# branch.upstream`). `parseStatus` agora devolve `hasUpstream`.
- **UI**: aba Git ganhou "Conta GitHub" (conectar/desconectar, passo a passo, link para criar token) e "Meus repositórios" (listar + clonar com badge privado/público). Nas linhas de repositório, botão "Enviar alterações" abre `CommitSheet` (lista de arquivos + mensagem + "Commit e enviar").
- **Validadores** (defesa em profundidade): `isValidGitHubToken`, `isValidRepoFullName` (anti path-traversal), `isSafeCommitMessage`.
- **Testes**: +13 (GitTests de upstream/arquivos + GitHubTests de validadores e decodificação da API). Build limpo, **73 testes** verdes.

**Licença AGPL-3.0 (2026-07-13):** definida a licença do projeto após conversa sobre objetivos (código aberto, mas sem concorrente comercial fechado; opção de doação simbólica e futura versão comercial/App Store). Escolhida **AGPL-3.0** (copyleft forte, fecha brecha de SaaS, garante crédito). `LICENSE` com texto oficial da GNU baixado (`curl`, 661 linhas) na raiz e em `Uptend/`; `README.md` atualizado (era MIT) com seção de licença + "Apoie o projeto" + autor, e a linha do Git reescrita mencionando o cliente GitHub. Caminho de **dual license** preservado enquanto o autor detiver 100% do copyright (contribuições externas exigirão CLA/DCO). Decisão detalhada em [D011]. Cabeçalhos de copyright nos `.swift` ficam para depois.

**Visualizador de repositórios (2026-07-13):** o usuário quis navegar os arquivos dos repositórios dentro do app, com Markdown renderizado e código colorido, só leitura (decisão: fonte **local** dos repos clonados; configs do repo ficam para depois). Implementado 100% nativo, sem dependências:
- **`RepoBrowser`** (Model): `FileNode` (árvore), `FileKind.detect` (markdown/imagem/código+linguagem/texto/binário por extensão/nome), `buildTree` (pula `.git`, `node_modules`, `build`, etc.; limite de 8000 nós), `readText` (limite de 1 MB + heurística de binário por byte NUL).
- **`CodeHighlighter`** (Service): scanner de passo único (comentários de linha/bloco, strings com escape e aspas triplas, números, palavras-chave) para Swift/C-family/Python/Ruby/Shell/JSON/YAML/CSS/SQL/markup; produz `AttributedString` colorido com `NSColor` dinâmicos (tema claro/escuro).
- **`MarkdownParser`** (Service): parser em nível de bloco (títulos, parágrafos, código cercado, listas, citações, régua, tabelas GFM, imagens); inline (negrito/itálico/código/links) via `AttributedString(markdown:)`.
- **Views**: `CodeView` (gutter de números + código, sem quebra, rolagem horizontal), `MarkdownView` (renderiza os blocos; imagens locais só — não busca remotas, por privacidade), `RepoBrowserView` (sheet com `HSplitView`: árvore `OutlineGroup` + painel de conteúdo, "Mostrar no Finder"). Botão **"Ver arquivos"** nas linhas de repositório (aba Git "Todos" e em "Meus repositórios" quando clonado).
- **Testes**: +13 (`RepoBrowserTests`: detecção de tipo, ordenação, parser Markdown, tokenizer). Build limpo, **86 testes** verdes.

**Mais ferramentas de Segurança (2026-07-13):** o usuário pediu ferramentas OSS defensivas e essenciais (sem virar suíte tipo Wireshark/Nmap) e escolheu **as quatro** propostas. Segurança ganhou 4 subseções novas (Exposição, Segredos, Auditoria, Vulnerabilidades):
- **Exposição (nativo, sem sudo)** — `ExposureService`: firewall (`socketfilterfw --getglobalstate`), stealth mode (`--getstealthmode`) e serviços de acesso remoto por **portas em escuta** via `netstat -an -p tcp` (`parseListening` distingue `*`=exposto à rede de `127.0.0.1`=local). Checa Login remoto/SSH, Compartilhamento de Tela/Arquivos(SMB/AFP)/Impressora, Gerenciamento Remoto (ARD) + lista outras portas expostas. (Sondado antes: `systemsetup -getremotelogin` e `launchctl print-disabled` exigem admin — descartados pela regra "no sudo".)
- **Segredos (gitleaks)** — `SecretScanService`: `gitleaks detect --source <pasta> --redact --report-format json` (segredos **redigidos**, nunca exibidos). Alvo: pasta escolhida ou repo monitorado. Local.
- **Auditoria (Lynis)** — `AuditService`: `lynis audit system --quick` com report-file em tmp; `parseReport` extrai `hardening_index`, warnings e sugestões. Local, sem sudo (verificações limitadas mas úteis).
- **Vulnerabilidades (osv-scanner)** — `DepsScanService`: `osv-scanner --format json --recursive <pasta>` contra a base OSV; `parseVulns` lê pacote/versão/ecossistema/ID. **Faz rede** à base OSV (ação explícita, avisado na UI).
- Ferramentas OSS que faltarem mostram card "não instalado" com botão `brew.installToken`. Descartados (para não virar suíte/ruído): rkhunter/chkrootkit (falsos positivos no macOS), trivy/grype (pesados), Nmap/Wireshark (fora do escopo).
- **Testes**: +8 (`SecurityScannersTests`: netstat, service checks, gitleaks, Lynis, osv-scanner). Build limpo, **94 testes** verdes.

**Polimento + padronização (2026-07-13):** executado o backlog de 4 itens que o usuário pediu:
1. **Saídas em português** nos scanners (novo `ScannerHelp`, puro/testável): gitleaks mostra o **tipo de segredo em PT** por RuleID (AWS/GitHub/chave privada/OpenAI…) + dica de correção; Lynis marca cada aviso/sugestão com a **categoria em PT** derivada do prefixo do ID (`SSH-7408`→"Servidor/acesso SSH") — `parseReport` agora devolve `LynisFinding` (id+texto); osv-scanner mostra **ação em PT** ("atualize a dependência") por vuln. (Textos crus da própria ferramenta — descrição de CVE, frase do Lynis — seguem no idioma original; tradução offline de texto arbitrário não é viável.)
2. **UI dos 3 scanners mais amigável** (estilo ClamAV): cartão de introdução explicativo (`ScannerIntro`), card de "Opções", e no gitleaks um **toggle "incluir histórico de commits"** (`--no-git` quando off).
3. **Ordem alfabética** em todos os menus e submenus: helper `Array.alphabetical` (protocolo `Titled`, `localizedCaseInsensitiveCompare`) aplicado em `SidebarView` (categorias) e `ContentColumn` (subseções). Base padronizada; promover itens ao topo fica para decisão futura do usuário.
4. **Ferramentas → Rede**: "Portas em uso" movida de `Category.tools` para `Category.network` (e o roteamento `PortsToolView` de `ToolsView` para `NetworkView`).
- **Testes**: +3 (`ScannerHelpTests`) e ajuste do teste do Lynis. Build limpo, **97 testes** verdes.

**Correção do desinstalar + install com admin (2026-07-13):** o usuário relatou que "Enviar para a Lixeira" o BlueStacks não fazia nada. Diagnóstico: (a) `AppsService.uninstall` usava `try?` que **engolia o erro em silêncio**; (b) BlueStacks é **root:wheel** (instalado via .pkg), e `FileManager.trashItem` não move item protegido sem autenticação. Correções:
- **`uninstall` reescrito**: erros viram `lastError` (mostrado em banner na ApplicationsView). `MacApp.ownerIsRoot` detectado no scan (`.ownerAccountID == 0`). Apps root vão para a Lixeira via **Finder** (`osascript … Finder delete`), que dispara o pedido de senha de administrador do macOS — continua reversível. Diálogo de confirmação avisa quando pedirá senha.
- **Instalar apps que exigem admin (feature)**: `BrewService.run` detecta pelo log (`logSuggestsAdmin`) quando um cask falhou por precisar de senha (ex.: .pkg), seta `needsTerminal`, e a `RunningTaskView` oferece **"Instalar pelo Terminal"** (`openInTerminal` via `osascript` do Terminal, onde o usuário digita a senha). BlueStacks existe como cask (`bluestacks`), mas é .pkg arm64 — daí a necessidade.
- **ApplicationsView mais clara (feature)**: banner explicando que a seção gerencia/desinstala (instalar novos = Homebrew) + botão "Ir para Homebrew".
- Também constatado que o **BlueStacks já estava instalado** no Mac do usuário (`/Applications/BlueStacks.app`).
- **Testes**: +2 (`AppsTests`: detecção de admin no log). Build limpo, **99 testes** verdes.

**Relatório → inventário da máquina (2026-07-13):** o usuário quis transformar o relatório simples num **inventário de ativos** (estilo "apresentar a máquina para uma empresa"), com **botão dedicado na toolbar** (entre engrenagem e sino) abrindo um menu de escopos, e vários formatos/tamanhos.
- **`ReportService` reescrito**: enums `ReportScope` (completo/apps/hardware/segurança/armazenamento), `ReportFormat` (Markdown/HTML/JSON/Texto), `ReportDetail` (resumido/detalhado); `ReportData` (Codable/Sendable) com identificação, hardware, sistema, rede, software e segurança; renderizadores puros `markdown`/`plain`/`json` (via JSONSerialization, escopado)/`html` (standalone, com CSS, escapado, imprimível/PDF). `includes(section,scope)` central.
- **`ReportBuilder`** (@MainActor): coleta dos serviços + `system_profiler SPHardwareDataType` (**número de série, Model Identifier, Hardware UUID**), `scutil --get ComputerName`, `ipconfig getifaddr` (IP local). `MacApp` ganhou **`version`** (lido do Info.plist no scan) para a lista de apps com versão+tamanho+origem.
- **UI**: `ReportPanel` reutilizável (escopo/formato/detalhe + pré-visualização + Copiar/Salvar/Abrir no navegador). Botão `Menu` na toolbar do `RootView` (ícone `doc.text.magnifyingglass`) entre engrenagem e sino, abrindo por escopo via `AppState.pendingReport` → sheet. Configurações › Relatório passou a reutilizar o `ReportPanel`.
- Privacy by Design mantido (tudo local, aviso na UI). Verificado que as fontes retornam dados reais no Mac do usuário.
- **Testes**: +7 (`ReportTests`: escopo, markdown, JSON válido/escopado, HTML escapado, parser do system_profiler). Build limpo, **106 testes** verdes.

**Relatório completo → pente-fino (2026-07-13):** o usuário quis o "completo" muito mais detalhado, com diretórios/arquivos e "original vs. mudado pelo usuário". Deixado claro que sem sudo não dá para comparar arquivo-a-arquivo com o original da Apple — mas o **SIP** garante integridade do sistema base, e dá para inventariar tudo que o usuário/terceiros adicionaram por cima. `ReportDeep` adicionado ao `ReportData`, coletado **conforme o escopo** (escopos estreitos seguem rápidos; `ReportPanel` re-coleta ao trocar escopo via `.task(id: scope)`):
- **Hardware detalhado**: GPU/monitores (SPDisplaysDataType), condição da bateria (SPPowerDataType).
- **Rede detalhada**: interfaces (IP via ipconfig + MAC via ifconfig), gateway (netstat -rn), DNS (scutil --dns).
- **Integridade & personalizações** (só no completo): SIP (csrutil status), itens de inicialização não-Apple (LaunchAgents/Daemons), extensões de sistema de terceiros (systemextensionsctl), contagem Homebrew, apps fora da App Store, /usr/local·/opt, dotfiles de shell.
- **Ferramentas (runtimes)**: versões de node/python/ruby/go/java/php/rust/swift.
- **Armazenamento**: tamanho das pastas do usuário (du -sk), **maiores arquivos via Spotlight** (mdfind, rápido/indexado), volumes (df -Hl).
- Renderizado nos 4 formatos (Markdown/HTML/JSON/Texto), respeitando escopo. `MacApp.version` já lido no scan.
- Verificado no Mac do usuário: todas as fontes funcionam sem sudo e são rápidas (mdfind ~0,3s, du instantâneo).
- **Testes**: +6 (`ReportTests`: allValues, SIP, DNS, gateway, ether, du, volumes, extensões, render profundo). Build limpo, **112 testes** verdes.

**Relatório: ainda mais completo + HTML redesenhado (2026-07-13):** o usuário pediu "completo é completo mesmo" e um HTML mais bonito (cores, categorias). Adicionado ao `ReportDeep`: sistema detalhado (build do macOS `sw_vers`, kernel `uname`, boot `kern.boottime`, fuso `readlink /etc/localtime`, LocalHostName), **histórico de instalações** (SPInstallHistoryDataType, parse nome+data, 30 recentes), **contas de usuário** (`dscl . -list /Users`), **itens de login** (System Events via osascript), **Homebrew completo** (listas de fórmulas+casks, não só contagem), e um **bloco bruto de componentes/periféricos** (um único `system_profiler` com 11 data types: memória/armazenamento/displays/áudio/USB/Thunderbolt/Bluetooth/rede/energia/impressoras/câmera, ~4,4s). Novos parsers testáveis: `parseInstallHistory`, `parseUsers`, `bootTime`, `timezone`.
- **HTML redesenhado**: layout em cartões com marcador colorido por categoria (sem emojis, respeitando o padrão), hero com gradiente (nome+série+chips), badges verde/laranja na segurança, barras de tamanho em apps/pastas, `<details>` recolhível para o bloco bruto, dark-mode via `prefers-color-scheme`, CSS de impressão (expande os `<details>` no print). Markdown/JSON também ganharam as seções novas.
- Medido no Mac do usuário: completo ~5-7s (peripherals é o gargalo), demais fontes instantâneas.
- **Testes**: +3 (`ReportTests`: install history, users, boot/timezone). Build limpo, **115 testes** verdes.

**Relatório fora de Configurações (2026-07-13):** para não duplicar com o botão da toolbar, a subseção "Relatório" foi removida de `Category.settings`, junto do roteamento em `RootView`/`SystemView` e da `ReportView` (código morto). O `ReportPanel` segue usado só pelo botão dedicado da toolbar. Build limpo, 115 testes verdes.

**Roadmap de 4 features escolhidas (2026-07-13):** após sugerir próximos passos, o usuário escolheu 4 para implementar em sequência: (1) Verificador de apps, (2) Kit dev (doctor+portas), (3) Disco+duplicados, (4) Kit de migração.
- **#1 Verificador de apps (CONCLUÍDO):** nova subseção Segurança › "Verificar app". `AppCheckService` usa `spctl --assess` (Gatekeeper), `codesign -dv`/`--verify` (assinatura/identidade/validade) e `xattr com.apple.quarantine` (quarentena) — tudo sem sudo. `AppVerdict.level` (trusted/caution/danger) com títulos em PT. `AppCheckView`: escolhe app → cartão de veredito + linhas (assinatura, autoridade, Team ID, notarização, Gatekeeper, quarentena). Parsers `parseSpctl`/`parseCodesign` testáveis. +5 testes (`AppCheckTests`). Build limpo, **120 testes** verdes.
  - **Melhoria para apps próprios (2026-07-13):** o usuário perguntou sobre confiar num app feito por ele. Adicionado `AppVerdict.adhoc` (detecta `Signature=adhoc`), `selfMadeLike` e uma `note` amigável ("normal em apps próprios/open-source compilados localmente — não é perigoso; confie se conhece a origem"). Botão **"Confiar localmente"** (`xattr -dr com.apple.quarantine`, reverifica) quando o app está em quarentena. +1 teste. **121 testes** verdes.

**Auditoria completa ponto-a-ponto (2026-07-13):** rodados 3 auditores em paralelo (segurança/execução de processos, privacidade/rede, correção/bugs). Núcleo confirmado sólido (todo processo via `Shell` com args array, sem shell/sudo; AppleScripts com path validado; token só no Keychain+env, nunca em argv/config/log; sem telemetria). Corrigidos:
- **CRÍTICO — loop infinito no `MarkdownParser`**: linha começando com `#` sem ser título válido (ex.: `#Título`, `#!/bin/bash`, 7+ hashes) caía no acumulador de parágrafo que quebrava sem consumir a linha → 100% CPU, app congelava ao mostrar tal README no visualizador. Corrigido consumindo sempre a linha atual. +teste de regressão.
- **ALTO — chamada de rede automática no launch** (`GitHubService.init`): se havia token, o app chamava `api.github.com/user` (mandando o token) sozinho ao abrir, violando o próprio "rede só em ação explícita". Passou a restaurar a identidade do **cache local** (UserDefaults, dados públicos); rede só ao conectar.
- **MÉDIO — auto-ping externo** (`QualityCard`): pingava 1.1.1.1 a cada 2s só por abrir a aba. Agora requer botão "Medir".
- **MÉDIO — exclusão permanente de perfis** (`ProfilesService.delete`): usava `removeItem` sem confirmação. Agora `trashItem` (reversível) + diálogo de confirmação.
- **BAIXO — `git clone` sem validar cloneURL**: adicionada exigência de prefixo `https://` (evita URLs de transporte do git tipo `ext::`). **BAIXO — `parseVolumes`** descartava volumes com espaço no nome: corrigido (reconstrói a coluna de montagem do `df -Hl`).
- Lows aceitos/anotados (não exploráveis): `openInTerminal` usa escaping manual mas só recebe tokens brew já validados; paths de `NSOpenPanel` em spctl/scanners são absolutos (seguros). Build limpo, **122 testes** verdes.

**Fechamento dos lows da auditoria (2026-07-13):** a pedido do usuário, os lows restantes foram corrigidos (defesa em profundidade): (1) `BrewService.openInTerminal` virou **privado** e `openLastInTerminal` valida que todos os args são tokens/flags seguros antes de abrir o Terminal — remove o "sink genérico". (2) Guardas de caminho (absoluto + existe) adicionadas em `AppCheckService.check`, `SecretScanService.scan`, `DepsScanService.scan` (paths do NSOpenPanel). (3) `DotfilesService.restore` agora, se o backup `.uptend.bak` foi criado mas a cópia falhou, avisa o usuário como recuperar o original. ClamAV usa caminhos curados/absolutos (mantido); `parseInstallHistory` já ordena certo (formato ISO do system_profiler). Build limpo, **122 testes** verdes.

**Smoke tests + performance (2026-07-13):** a pedido do usuário (subir QA e melhorar performance).
- **Smoke tests (`SmokeTests.swift`, +10):** (a) **renderização real** das telas via `ImageRenderer` (força o `body` — pegaria o loop do Markdown): MarkdownView (com o caso `#semEspaco` + tabela/código), CodeView, telas de Segurança (Exposição/Verificar/Segredos/Auditoria/Vulns), e telas principais (Aplicativos/Git/ReportPanel/Segurança) com todos os environment objects injetados. (b) **fluxos críticos de integração** no sistema real: `SystemService.loadInfo`, `AppsService.scan`, `ExposureService.refresh`, `AppCheckService.check` no Calculator (confiável), `ReportBuilder.gather`+render HTML, `SecurityService.refresh`. Remove a ressalva "não vi renderizado".
- **Performance (profiling real, medido):** (1) coleta do relatório paralelizada — `ReportBuilder.gather`/`gatherDeep` reestruturados em seções concorrentes (`async let`), `runtimes()`/`interfaces()`/`folderSizes()` via `withTaskGroup`. Medido **2,96s → 1,60s (~46%)**. (2) `AppsService.scan` dimensiona os bundles em **paralelo** (`withTaskGroup` sobre `makeApp`; `MacApp`/`AppOrigin` marcados `Sendable`) — **14,8s → 8,6s (~42%)**.
- Build limpo, **132 testes** verdes.

**Melhorias de arquitetura (2026-07-13):** implementados 4 dos 5 itens sugeridos (o #2, split em módulos SwiftPM, ficou como passo dedicado por ser migração grande/arriscada num build saudável).
- **#1 `CommandRunning` (protocolo injetável sobre o `Shell`)** — `LiveCommandRunner` (real) + `MockRunner` (testes). `ExposureService`/`AppCheckService` passaram a receber o runner por init. Permite testar a orquestração (comando→parse→estado) de forma determinística/instantânea: +3 testes mockados (`CommandRunnerTests`).
- **#4 `InstallableTool`** — protocolo com `locate()` compartilhado por gitleaks/lynis/osv (dedup da detecção). Unificação por herança de classe foi evitada de propósito (risco de quebrar a observação do SwiftUI).
- **#3** — `ReportService.swift` (581 linhas) dividido em `ReportService.swift` (modelo, 157) + `ReportRenderers.swift` (SystemReport, 426).
- **#5** — `.swiftlint.yml` na raiz + componente `ErrorBanner` reutilizável (padroniza os cartões de erro), adotado em AppCheckView/GitView.
- Build limpo, **135 testes** verdes.

**#2 Split em módulos SwiftPM (2026-07-13):** feito como passo dedicado, com build verde a cada etapa. Criado o target **`UptendCore`** (lógica pura, sem SwiftUI/AppKit) e o `Uptend` (executável) passou a depender dele; `Package.swift` com 3 targets (Core + app + testes que dependem de ambos). Primeiro módulo, coeso e autossuficiente: `MarkdownParser`, `RepoBrowser` (FileNode/FileKind), `ScannerHelp` (LynisFinding) — escolhidos por baixo acoplamento e poucas `public init`. Marcados `public` os tipos/funcs/inits que cruzam a fronteira; `import UptendCore` adicionado nos ~7 arquivos (app + testes) que os usam. Escopo reduzido de propósito (os modelos/renderizadores do relatório, com `public init` grandes, ficam para uma próxima migração no mesmo padrão). `build-app.sh`/`make-dmg.sh` seguem sem alteração (o `swift build` resolve a dependência). Compilou de primeira; **135 testes** verdes. Ver [D012].

**Upgrade que precisa de admin → Terminal (2026-07-13):** o usuário relatou erro ao atualizar `wireshark-app` (componente `ChmodBPF` exige sudo). O botão "atualizar tudo" usava `updateAndUpgradeAll()`, que chamava `Shell.stream` **direto** (sem passar por `run()`), então **não detectava** a necessidade de admin nem oferecia o Terminal — mostrava só "Erro (código 1)". Corrigido: `updateAndUpgradeAll` agora seta `lastCommandArgs = ["upgrade"]`, checa `logSuggestsAdmin` e liga `needsTerminal`. Botão da `RunningTaskView` generalizado ("Instalar pelo Terminal" → **"Abrir no Terminal"**) e texto de aviso genérico (serve pra install e upgrade). Build limpo, **135 testes** verdes.

**Detalhes do pacote na busca (2026-07-13):** o usuário pediu para, ao clicar num resultado da busca do Homebrew, ver uma explicação do que é o app. Adicionado `BrewInfo` + `BrewService.info(token:isCask:)` via `brew info --json=v2 --formula/--cask` e `parseInfo` (puro/testável: descrição, site, versão, licença, dependências, caveats). Na `BrewSearchView`, botão ⓘ (e tap na linha) abre `BrewInfoSheet` com os detalhes, link para o site e botão de instalar direto. Fórmula e cask têm JSON diferente — o parser trata os dois. +3 testes (`BrewInfoTests`), campos verificados no Mac do usuário. Build limpo, **138 testes** verdes.

**Setup → Início + Início na toolbar (2026-07-13):** duas migrações de categoria. (1) As subseções do **Setup** (Primeira vez, Perfis, Comparar, Dotfiles) foram fundidas na categoria **Início** (dashboard), e a categoria `.setup` foi removida do enum/switches; `DetailColumn` para `.dashboard` despacha essas ids para `SetupView` e o resto para `DashboardView`; navegação do `FirstRunView` atualizada (`.setup`→`.dashboard`). (2) **Início saiu da barra lateral** e virou um **ícone de casa na toolbar, antes da engrenagem** (tinta accent quando ativo). `Category.primary` agora exclui `.dashboard` e `.settings` (ambos acessados pela toolbar). Sidebar enxuta: 8 categorias. Build limpo, **138 testes** verdes.

**Visão geral: Ações rápidas → status do Homebrew (2026-07-13):** na `DashboardView.overviewContent`, o bloco "Ações rápidas" (atualizar tudo / verificar) foi removido e substituído pela linha de status do **Homebrew** (reaproveitando o `healthRow`: "Instalado e funcionando"/"Não encontrado"). A "Saúde do sistema" mantém a lista completa. Helper `quickAction` (órfão) removido. Build limpo.

**Remoção da "Saúde do sistema" do Início (2026-07-14):** o usuário apontou redundância (login items já existe em Configurações; espaço/atualizações já aparecem nos cartões da Visão geral). Removida a subseção `health` de `Category.dashboard` e o `healthContent` da `DashboardView` (o "7 apps abrindo no login" era placeholder fixo). `healthRow` mantido (usado pela linha do Homebrew na Visão geral). Início agora: Visão geral, Primeira vez, Perfis, Comparar perfil, Dotfiles. Build limpo.

**Pente fino de tooltips (2026-07-14):** o usuário quis explicações no hover em elementos não-óbvios, para deixar mais amigável. Levantado que a cobertura de `.help` estava concentrada nos `IconButton` (que já têm) e nas categorias; faltava nos elementos de métrica/opção. Adicionado: `StatCard` ganhou param `help` (fallback pro título) + explicações nos 4 cartões do dashboard; métricas de Rede (Latência/Média/Jitter/Perda) com `help` explicando cada uma; pickers do Relatório (Conteúdo/Formato/Detalhe); modos de scan do ClamAV (Rápido/Completo/Agressivo/Pasta) e o seletor de categorias dos Essenciais. Toggles do sistema já tinham `.help(toggle.help)`. Limpeza/Docker usam IconButton (com tooltip) e botões de rótulo claro. Build limpo.

**Correção: conta GitHub aparecia desconectada (2026-07-14):** regressão da auditoria — ao remover a chamada de rede no launch, o `init` passou a restaurar a identidade de um cache local (UserDefaults `uptend.github.account`) que **não existia** para quem conectou antes da mudança. Diagnóstico confirmou: token **presente no Keychain** (`security find-generic-password` achou), só faltava o cache da conta → UI mostrava "não conectado" embora o token funcionasse. Correção: `GitHubService.restoreIdentityIfNeeded()` — quando há token mas `account == nil`, recarrega `/user` e popula o cache; chamado no `.task` da `GitHubAccountView` (ação explícita = abrir a tela). Novo estado `tokenPresentCard` ("Token salvo" + botão Atualizar/Desconectar) enquanto reconecta; erros (ex.: 401/token expirado) surgem no banner. Build limpo, 138 testes verdes.

**Scan em plano de fundo + indicador na sidebar (2026-07-13):** o usuário quis que o escaneamento do antivírus continuasse rodando ao navegar para outra seção, com uma bolinha na barra lateral sinalizando atividade. Causa: `ClamAVService` era `@StateObject` da própria `ClamAVView` — ao sair, a tela (e o serviço) eram destruídos. Correção: `ClamAVService` promovido a **nível de app** (`@StateObject` no `UptendApp`, injetado como `@EnvironmentObject`); a `ClamAVView` passou a consumi-lo. Como o scan é disparado por `Task { await clam.scan(...) }` em botões (fora do ciclo de vida da view), ele **continua ao navegar** e o progresso reaparece ao voltar. Nova `ActivityDot` (bolinha verde pulsante) na `SidebarView` quando a categoria tem processo ativo (`isActive`: Segurança=`clam.running`, Homebrew=`brew.runningBusy`; extensível). Build limpo, **138 testes** verdes.

**4 features novas: Faxina brew + GitHub publish/SSH/settings (2026-07-14):** o usuário escolheu 4 e explicou querer cada uma. (1) **Faxina do Homebrew** (Homebrew › Faxina): `brew leaves` + `brew autoremove --dry-run` (`parseAutoremove` testável) + botão "Remover órfãs"; +3 testes (`BrewTidyTests`). (2) **Publicar no GitHub** (Git › Publicar pasta): pasta local → `POST /user/repos` (helper `post`/`send`) → git init/add/commit/branch -M main/remote/push autenticado; `PublishRepoView`. (3) **Chave SSH → GitHub** (Ferramentas › Chave SSH): botão por chave → `POST /user/keys` (`uploadSSHKey`); erro amigável se faltar a permissão "Git SSH keys". (4) **Configs do repo** (Meus repositórios, engrenagem): `RepoSettingsSheet` → `PATCH /repos/{owner}/{repo}` (`updateRepo`, helper `patch`); **confirmação reforçada** privado→público; avisa da permissão "Administration". Rede só em ação explícita; erros de permissão orientam o escopo a adicionar. Build limpo, **141 testes** verdes.

**4 categorias novas: Serviços, Bateria, Xcode, Armazenamento (2026-07-14):** o usuário escolheu as 4. Cada uma: novo `case` no `Category` (enum + title/systemImage/help/subsections) + roteamento no `RootView` + serviço + view + testes.
- **Serviços** (`server.rack`): `brew services list --json` (`ServicesService.parse` testável) + start/stop/restart; badges de status. +2 testes.
- **Bateria e Energia** (subseções Bateria/Consumo): `pmset -g batt` (`parsePmset`; cuidado que "discharging" contém "charging"), `system_profiler SPPowerDataType` (ciclos/condição/capacidade), `ps -A -r -o %cpu,comm` (`parseTopProcesses`) para apps que mais consomem. +4 testes.
- **Xcode** (subseções Xcode/Simuladores): versão via Info.plist, tamanho do **DerivedData** + limpar (→ Lixeira), `xcrun simctl list` (`parseSimulators`) + zerar/apagar/desligar simulador. +2 testes.
- **Armazenamento** (subseções Uso/Duplicados): `du`+`df`+`mdfind` (uso por pasta/volumes/maiores arquivos) e **caça-duplicados por conteúdo** (`scanDuplicates`: agrupa por tamanho, confirma por SHA-256 streaming; move cópia para a Lixeira). +3 testes (com arquivos temporários reais).
- Tudo local, sem sudo, reversível (Lixeira). Sidebar agora com 12 categorias. Build limpo, **152 testes** verdes.

## 2026-07-14 — Xcode: linha do tamanho das imagens de iOS (runtimes)
Além dos dados dos simuladores (pasta Devices, ~192 MB no Mac de teste), a aba
Simuladores agora mostra o total das **imagens de iOS baixadas** (runtimes) numa
linha própria — a parte pesada (7,9 GB no teste), guardada separada dos dados.
- XcodeService: `runtimeSize`/`runtimeCount` via `xcrun simctl runtime list`
  (parseia o rodapé "Total Disk Images: N (7.9G)"), helper `friendlySize`
  ("7.9G"→"7.9 GB"). Parsers puros + nonisolated.
- XcodeView: card "Imagens de iOS ocupam X" com subtítulo explicando que é o
  sistema compartilhado entre simuladores; tooltip aponta Xcode ▸ Settings ▸
  Platforms para gerenciar. Sem botão de apagar runtime (evita remover a versão
  em uso por engano).
- Testes: parsesRuntimeTotal, parseRuntimeTotalHandlesNone, friendlySize.

## 2026-07-14 — Homebrew: Meus programas + Fontes (taps de terceiros)
Fluxo guiado para instalar programas fora do core oficial (taps pessoais no
GitHub), transformando a sequência manual `tap → trust → install` em 1 clique.
Duas subseções novas em Homebrew:
- **Meus programas** (MyPackagesView): lista curada e editável na interface
  (MyPackagesStore em UserDefaults, só nomes — nada sensível). Cada item instala
  com 1 clique; detecta se já está instalado; permite desinstalar ou remover da
  lista. Formulário AddPackageSheet (nome, fonte owner/repo, fórmula, observação),
  com validação ao vivo e prévia do que será instalado (owner/repo/formula).
- **Fontes (taps)** (TapManagerView): gerenciador genérico — lista `brew tap`,
  adiciona/remove fontes, expande cada fonte para ver e instalar suas fórmulas
  (`brew tap-info --json`). Fontes oficiais (homebrew/*) não têm botão de remover.
Serviço (BrewService): `taps`/`refreshTaps`, `addTap`/`untap`, `tapFormulae`+
`parseTapFormulae` (puro), `installFromTap` (adiciona tap se preciso + install
qualificado owner/repo/formula), fluxo de confiança `needsTrust`/`trustAndRetry`
com detector `logSuggestsTrust`. Botão "Confiar e instalar" na folha de log.
Segurança (PADROES): tudo via Process+args (sem shell/interpolação); tap validado
por InputValidator.isValidRepoFullName, fórmula por isValidBrewToken; `brew trust`
nunca automático (o usuário confirma); rede só na ação. Testes: MyPackagesTests
(validação, codec, store add/dedup/remove/sort/persistência) + parseTapFormulae e
logSuggestsTrust em BrewInfoTests. Total: 165 testes.

## 2026-07-14 — Fontes por CONTA do GitHub + procedência na busca
Reformulação: em vez de digitar owner/repo, o usuário digita só um USUÁRIO do
GitHub. O Uptend varre a conta, acha os repositórios homebrew-* (fontes), conta
os programas e instala com 1 clique (tap por baixo). Muito mais natural.
- GitHubService.discoverProvider(user:): GET /users/{user}/repos, filtra
  homebrew-*, lê Formula/ + raiz + Casks/ via /contents (fetchPublic — usa token
  se houver, senão anônimo). Helpers puros em TapDiscovery (isTapRepo, tapName,
  recipeNames). Modelos TapProgram/TapProvider + TapProvidersStore (cache local
  em UserDefaults, upsert/remove/contains, allPrograms).
- Fontes (contas) [TapManagerView reescrita]: campo de usuário → cartão por conta
  com "N programa(s) · M fonte(s)", expansível com busca + Instalar (1 clique) +
  estrela (salva em Meus programas). Reverificar por conta.
- Busca geral (BrewSearchView): agora combina catálogo oficial + programas das
  contas adicionadas (do cache, offline), cada resultado com SourceTag de
  procedência — "core" (cinza), "sua conta" (verde) ou "@outro" (laranja).
  SearchResult ganhou `tap`/`owner`; instala via installFromTap quando é de tap.
Segurança: usuário validado por isValidGitHubUser; tap por isValidRepoFullName;
fórmula por isValidBrewToken; nada de rede automática (só no Adicionar/Reverificar/
Buscar). Testes: TapDiscovery (isTapRepo/tapName/recipeNames), TapProvidersStore
(upsert/remove/persistência/case-insensitive), SearchResult owner/id. Total: 170.

## 2026-07-14 — Meus programas: remoção do cadastro manual
Com a descoberta por conta + estrela para favoritar, o cadastro manual (AddPackageSheet)
virou redundante. Removido: MyPackagesView agora é só a lista de favoritos, preenchida
pela estrela em "Fontes (contas)". Sem botão "Adicionar" e sem a folha de formulário.

## 2026-07-14 — Meus programas = instalados ∪ favoritos; estrela em todo lugar
Novo modelo de "Meus programas": mostra os programas de fontes de terceiros que
estão INSTALADOS ou FAVORITADOS (união), com favoritos no topo (estrela cheia).
Instalar algo de uma fonte faz o programa aparecer aqui automaticamente. Fonte da
verdade: cross-reference entre providers.allPrograms (contas adicionadas) + store
de favoritos, filtrando por instalado/favorito. Subtítulo mostra contagens.
- FavoriteButton reutilizável (estrela cheia/vazia) usado em 3 lugares: Fontes
  (contas), Meus programas e resultados de terceiros na busca geral.
- Removido o botão "remover da lista" (favoritar/desfavoritar via estrela já cobre).
Sem novos comandos de shell/rede — só reorganização de UI sobre dados existentes.

## 2026-07-14 — Aplicativos: etiqueta de procedência de terceiros
Na aba Aplicativos, apps que vieram de casks de FONTES DE TERCEIROS agora mostram
a etiqueta (verde "sua conta" / laranja "@outro"), a mesma da busca.
- BrewService.indexThirdPartyApps(programs): para cada cask de terceiros instalado,
  lê o nome do .app via `brew info --cask --json=v2` (parseCaskAppNames dos artifacts)
  e monta mapa nomeApp-normalizado → owner. Publicado em thirdPartyApps.
  normalizeAppName casa app ↔ cask sem diferenciar .app/caixa.
- ApplicationsView: injeta brew/providers/github, indexa em .task keyed em
  (nº programas de fontes, nº casks instalados), e mostra TapOriginBadge na linha.
- TapOriginBadge extraído como componente reutilizável.
Testes: parseCaskAppNames (artifacts, target ignorado, lixo), normalizeAppName.

## 2026-07-14 — Tag mostra @usuário; casamento por nome (cask ou fórmula)
- TapOriginBadge e SourceTag agora mostram sempre @login do GitHub (não "sua conta").
  Cor mantém a lógica: verde = sua conta conectada, laranja = outra conta.
- indexThirdPartyApps: considera programa instalado como cask OU fórmula e casa pelo
  nome direto (normalizeAppName), além dos artifacts do cask. Corrige caso em que o
  app (ex.: Peapod) não recebia tag por ter sido descoberto como fórmula (Formula/).

## 2026-07-14 — KindTag (app/CLI) para distinguir fórmula e cask de mesmo nome
Quando um mesmo nome existe como fórmula E cask no tap (caso do peapod: CLI+app),
as linhas ficavam iguais. Adicionado KindTag: "app" (cask) / "CLI" (fórmula) em
Fontes (contas) e Meus programas. Busca geral já distinguia ("cask (app)"/"fórmula").

## 2026-07-15 — HomeLab: prévia visual (só interface, sem função)
Scaffold do módulo HomeLab só para visualizar disposição de menus/submenus:
- Abas de host no topo (HostTabBar): "Este Mac" | "HomeLab ●" | "+", via AppState.activeHost.
  "Este Mac" mantém tudo como está; HomeLab troca sidebar/subseções/detalhe.
- HomeLabSection (overview, machines, containers, services, storage, backups, network,
  updates, terminal) com subseções (SubSection reaproveitado).
- Telas de exemplo (dados estáticos, banner "Prévia"): Visão geral (tiles de saúde),
  VMs/LXC, Containers/Imagens/Volumes, Serviços systemd, Discos/RAID/SMART (semáforo),
  Backups locais/nuvem, Rede/Portas/VPN, Atualizações, Terminal. Folha "Adicionar host".
- Nada funcional: sem rede, sem SSH. Só casca visual (ver HOMELAB.md). Build limpo.

## 2026-07-15 — HomeLab: abas em dois níveis (tipo + instâncias)
Abas de host agora têm 2 níveis: nível 1 = tipo (Este Mac / HomeLab / Servidor);
nível 2 = switch de instâncias do tipo remoto (HomeLab 1,2… / Servidor 1,2…) + "+".
- HostContext virou enum com associados: .thisMac / .remote(HostKind, Int); HostKind
  = homelab|server. AppState: homelabCount/serverCount/addHostKind (prévia).
- Sidebar por tipo: Servidor (Linux comum) não mostra "Máquinas (VMs)" (não é hipervisor).
- Overview com subtítulo dinâmico (Proxmox vs Ubuntu) e esconde linha de VMs em servidor.
- AddHostSheet ciente do tipo; "+"/Adicionar cria uma instância de exemplo e muda pra ela.
Ainda tudo prévia visual (sem função). Build limpo.

## 2026-07-15 — HomeLab: conexão real + Visão geral com dados reais (via SSH)
Ligou a fundação na UI (contra o lab uptend-lab):
- HostContext agora .remote(HostKind, UUID) referenciando hosts reais; removidos
  homelabCount/serverCount de exemplo. HostStore injetado no app.
- HostTabBar: menus HomeLab/Servidor listam hosts reais do HostStore + "Adicionar".
- AddHostSheet REAL: nome/endereço/usuário/porta/chave (com seletor de arquivo),
  "Testar conexão" (SSHRunner.test → uname), salva no HostStore, troca pro host.
- HLOverviewView REAL: lê CPU/RAM/disco/uptime/carga via HomeLabMonitor.overview
  (SSH, /proc + df, CPU por 2 amostras), com refresh e tratamento de "sem conexão".
- HomeLabMonitor + RemoteOverview novos. Demais telas do HomeLab seguem prévia.
- Smoke test: injeta MyPackagesStore/TapProvidersStore/HostStore (lacuna antiga que
  a ApplicationsView expôs). 181 testes passando. Verificado: invocação idêntica ao
  SSHRunner conecta no uptend-lab e retorna dados que os parsers já tratam.

## 2026-07-15 — Servidor Passo 1: Containers (Docker) REAL via SSH
- RemoteDocker (RemoteDocker.swift): lista containers/imagens/volumes via SSH
  (formatos tab-separados), ações start/stop/restart/remove container, remover
  imagem/volume, logs. Verbos constantes; nome dinâmico validado por
  InputValidator.isValidDockerName (novo). Parsers puros.
- HLContainersView reescrita (real): 3 subtelas (containers/imagens/volumes) com
  ações, spinner por item, ErrorBanner, confirmação de remoção, folha de logs
  (ContainerLogsSheet). Resolve o host ativo do HostStore.
- Testes RemoteDockerTests (fixtures reais). Verificado ao vivo no uptend-lab:
  stop→exited, start→running, logs OK. Docker roda sem sudo (grupo docker).

## 2026-07-15 — Servidor Passo 2: Templates (catálogo, deploy 1 clique) REAL
- ServiceTemplate/TemplateField + ServiceCatalog (7 templates: Uptime Kuma, Portainer,
  Dozzle, Vaultwarden, Gitea, n8n, Pi-hole) em ServiceTemplates.swift. dockerRunArgs monta
  `docker run -d` (portas tcp/udp, -e envs, -v volumes nomeados, extraArgs p/ socket), com
  validate (nome/portas). RemoteTask (ObservableObject) faz deploy com log ao vivo via
  SSHRunner.stream (novo; SSH agora tem run+stream, opções extraídas).
- Nova seção Catálogo no menu do servidor (HomeLabSection.catalog). HLCatalogView lista por
  categoria, detecta instalados (nome do container), abre TemplateInstallSheet: form (nome/
  porta/senha) → deploy com log streamado + botão "Abrir <url>".
- Testes ServiceTemplatesTests (builder/validação/catálogo). Verificado ao vivo: deploy do
  uptime-kuma subiu (porta 3001, HTTP 302), depois removido. Correção anterior do shellQuote
  é o que faz o docker run passar certo pelo shell remoto.

## 2026-07-15 — Servidor Passo 3: Serviços (systemd) + Atualizações (apt) REAIS
- RemoteServer.swift: RemoteSystemd (list-units + list-unit-files → ServiceUnit com
  active/sub/enabled; ações start/stop/restart/enable/disable via `sudo -n systemctl`)
  e RemoteApt (apt list --upgradable → AptPackage; update/upgrade streamados via
  `sudo -n apt-get`, upgrade com env DEBIAN_FRONTEND=noninteractive). Parsers puros.
- InputValidator.isValidServiceName. Ações privilegiadas com sudo -n (se pedir senha,
  erro é mostrado; nada às cegas).
- HLServicesView real: lista+filtro, dot rodando, tag "no boot", start/stop/restart +
  habilitar/desabilitar. HLUpdatesView real: contagem, lista old→new, "Atualizar
  catálogo"/"Atualizar tudo" com RemoteTaskSheet (log ao vivo genérico, reutilizável).
- Testes RemoteServerTests (fixtures reais). Verificado: restart cron via sudo -n OK,
  apt list = 6 pacotes. 197 testes no total (após build).

## 2026-07-15 — Servidor Passo 4: Segurança (Status + Auditoria Lynis) REAL
- RemoteSecurity.swift: status() roda 5 checks em paralelo (ufw, sshd -T root/senha,
  fail2ban, unattended-upgrades, updates de segurança) → ServerSecurityCheck (semáforo).
  Parsers puros. Auditoria: auditArgs (bash -lc: instala lynis se preciso + roda,
  grava /tmp/uptend-lynis.dat), readAudit lê com `sudo -n cat` (relatório é de root) e
  REAPROVEITA AuditService.parseReport + LynisFinding do Mac (UptendCore).
- Nova seção Segurança no servidor (status + audit). HLSecurityStatusView (semáforos) e
  HLAuditView (nota 0–100 + avisos/sugestões, reusa ScannerHelp). RemoteTask streama a
  auditoria.
- ServerSecurityCheck (renomeado p/ não colidir com SecurityCheck do Mac). Testes
  RemoteSecurityTests. Verificado ao vivo: lab cru (firewall/fail2ban/auto-update ausentes,
  senha SSH ligada); Lynis rodou → índice 63, 1 aviso, 48 sugestões.

## 2026-07-15 — Servidor Passo 5: Rede (endereços, portas, ping, DNS) REAL
- RemoteNetwork.swift: info (IP local/gateway/DNS/hostname), ports (sudo -n ss -tlnp →
  RemoteListeningPort, colapsa IPv4/IPv6, marca exposto vs local), ping/dnsLookup (alvo
  validado por isValidHost). Parsers puros (parseGateway/parseListening).
- HLNetworkView real: Endereços, Portas (semáforo exposto=laranja/local=verde + processo),
  Ping e DNS (campos + saída). Subseção vpn→"Ping e DNS".
- RemoteListeningPort (renomeado p/ não colidir com ListeningPort do Mac). Testes
  RemoteNetworkTests. 205 testes no total.

## 2026-07-15 — Servidor Passo 6: Arquivos (SFTP) REAL
- RemoteFiles.swift: list (find -printf %y/%s/mtime/%f → RemoteFile, robusto a espaços),
  makeDir, delete (rm -rf, destrutivo→confirmação), download/upload via scp (Process+argv,
  sem shell). parseListing/parent puros. InputValidator.isSafeRemotePath (absoluto, sem
  metacaracteres/globs — protege até o scp que não passa pelo aspeamento do SSHRunner).
- Nova seção Arquivos no servidor. HLFilesView: navegação (clicar pasta/acima/campo de
  caminho), Nova pasta (alert), Enviar (NSOpenPanel→upload), Baixar (NSSavePanel→download),
  Apagar (confirmação: "sem Lixeira no servidor"). Pastas primeiro, ícones, tamanho/data.
- Testes RemoteFilesTests. Verificado ao vivo: scp upload+download roundtrip com conteúdo
  idêntico. 209 testes no total.

## 2026-07-15 — Servidor Passo 7: Discos (leitura) REAL
- RemoteDisks.swift: devices (lsblk -P → BlockDevice, filtra nbd/loop/size0), usage
  (df -B1 → FSUsage, dedupe por source + filtra tmpfs/overlay, ordena por uso),
  raidStatus (mdstat + zpool → resumo), SMART (instala smartmontools + smartctl -H por
  disco; trata "não disponível" em disco virtual). Parsers puros (parseLsblk/parseDf/
  summarizeRaid, pairs por regex).
- HLStorageView real: Discos (barras de uso + dispositivos), RAID (status + aviso de
  destrutivo pra depois), SMART (instalar+verificar, semáforo PASSED/FAILED/indisponível).
- Só LEITURA; montar/formatar/RAID/cripto ficam pro fim (destrutivo, hardware real).
- Testes RemoteDisksTests (fixtures reais). 212 testes no total.

## 2026-07-15 — Servidor Passo 8a: Terminal embutido REAL
- RemoteTerminal.swift: run(host, cwd, command) executa o comando do usuário via
  bash -lc (o comando é 1 arg, aspeado pelo SSHRunner — sem injeção além do que o
  usuário digita; é a "saída de emergência", equivalente a ssh manual). Mantém o cwd
  entre comandos via marcador __UPTEND_CWD__$(pwd). parse puro/testável.
- HLTerminalView real: log rolável, prompt com cwd, campo de comando (Enter/botão),
  limpar. Aviso: não-interativo (top/vim/sudo-senha não servem).
- Testes RemoteTerminalTests. Verificado ao vivo: ls + cd persistem. 215 testes.

## 2026-07-15 — Servidor Passo 8a: Terminal embutido REAL
- RemoteTerminal.swift: run executa o comando do usuário via bash -lc no servidor,
  mantendo o cwd entre comandos (marcador __UPTEND_CWD__ + pwd no fim). parse puro
  (separa saída do cwd; while para remover newlines finais). É a "saída de emergência":
  rodar comando arbitrário é a função (usuário no próprio servidor via SSH); comando vai
  como 1 arg (aspas do SSHRunner). Não-interativo (sem TTY).
- HLTerminalView real: log (altura fixa 380, autoscroll), prompt com cwd, campo de comando.
  FIX de layout: tela ficava vazia com ScrollView de altura infinita dentro de VStack;
  passou a usar o padrão das outras telas (ScrollView externo + caixa de altura fixa).
- Testes RemoteTerminalTests. Verificado na tela: ls/cd teste/ls, cwd persistindo.

## 2026-07-15 — Servidor Passo 8b: Assistente de primeira configuração REAL
- ServerSetup.swift: 5 passos (Docker, firewall ufw liberando 22 antes de ativar,
  fail2ban, unattended-upgrades, desativar login por senha SSH via drop-in). Scripts
  fixos via sudo -n. status() checa os 5 em paralelo (id→bool).
- Nova seção Configuração (HomeLabSection.setup) no topo do menu. HLSetupView: lista de
  passos com check (aplicado/pendente), "Aplicar" abre RemoteTaskSheet (log ao vivo),
  reverifica ao fechar. Reaproveita TaskRequest/RemoteTaskSheet.
- Testes ServerSetupTests (shape + trava: allow 22 antes de enable). Verificado ao vivo:
  status correto (docker✓, resto pendente) e aplicar fail2ban → active. 217 testes.

## 2026-07-15 — Servidor Passo 8c: Backups (restic) REAIS
- RemoteBackup.swift: repositório restic LOCAL no servidor (/var/backups/uptend-restic).
  Senha gerada no servidor, arquivo só-root (--password-file) — nunca no Mac/argv.
  status (instalado/inicializado), snapshots (--json → parseSnapshots, mais recentes
  primeiro), prepareArgs (instala+init), backupArgs(folder), restoreArgs(id,target).
  Tudo sudo -n. folder/target validados por isSafeRemotePath.
- HLBackupsView real: "Backups locais" (preparar repo → fazer backup de pasta → lista de
  snapshots → restaurar com destino via alert). "Nuvem" = placeholder (próximo: backend
  B2/S3 + credenciais no Keychain). Reaproveita TaskRequest/RemoteTaskSheet.
- Testes RemoteBackupTests. Verificado ao vivo: init, backup (snapshot ec0f35ca),
  snapshots --json, restore (10 arquivos). 220 testes.

## 2026-07-15 — Servidor Passo 8d: Alertas no Mac (sino) REAIS
- ServerAlerts.swift (ServerAlertsService): check(hosts) verifica cada host — sem conexão,
  disco >85%, memória >92%, updates de segurança (apt|grep -c security) → [ServerAlert]
  (nível 1 atenção/2 problema + seção para navegar). Rede só na ação (botão), nada no launch.
- Integrado ao NotificationBell (badge += alertas) e à NotificationCenterView: botão
  "Verificar servidores" em "A fazer"; alertas viram TodoItems (vermelho/laranja) que
  navegam pro host+seção ao clicar. Injetado no app; smoke test atualizado.
- Verificado: lab com 2 updates de segurança → alerta dispara; disco/mem baixos → sem
  falso positivo. 220 testes.

## 2026-07-15 — Servidor Passo 8e: Deploy Mac→servidor REAL (plano 8 COMPLETO)
- RemoteDeploy.swift: transfer (scp -r da pasta local → /home/user/uptend-deploys/<name>,
  limpa deploy anterior), buildRunArgs (cd dir && docker build -t name . && rm -f + run -d
  [-p h:c] streamado). isValidPortMapping; nome via isValidDockerName; build no servidor
  (evita problema arm64/x86).
- "Meu projeto" como 2ª subseção do Catálogo. HLDeployView: escolher pasta (checa Dockerfile),
  nome, porta opcional → "Enviando…" (scp) → RemoteTaskSheet (build+run ao vivo).
- Testes RemoteDeployTests. Verificado ao vivo: projeto nginx → transfer+build+run,
  curl :8090 = "Deploy Uptend OK", limpo. 223 testes.

MÓDULO SERVIDOR COMPLETO: fundação SSH, Visão geral, Containers, Catálogo(templates)+Deploy,
Configuração(wizard), Serviços(systemd), Segurança(status+Lynis), Arquivos(SFTP), Discos,
Backups(restic), Rede, Atualizações(apt), Terminal, Alertas no sino. Proxmox/HomeLab-API e
discos destrutivos (formatar/RAID/cripto) + backup na nuvem ficam para hardware real.

## 2026-07-16 — Central de Segurança / Monitoramento (SIEM leve, item A) REAL
- SecurityMonitor.swift: scan() junta num painel de EVENTOS (linguagem simples + "como
  corrigir") — logins SSH falhos (journalctl), fail2ban (banned/total), serviços com falha
  (systemctl --failed), disco cheio (reusa RemoteDisks), e config/updates (reusa
  RemoteSecurity.status). Cada evento: categoria/título/detalhe/remediação/nível. Parsers
  puros (loginEvent, fail2banEvent, failedServiceEvents, number). Só leitura, sudo -n.
- Nova subseção Segurança ▸ Monitoramento (HLMonitorView): eventos ordenados por severidade
  (semáforo + tag de categoria + evidência + "como corrigir"), resumo "N críticos·N atenção".
- Testes SecurityMonitorTests (fixtures reais: fail2ban, serviços com falha). 224 testes.
- Nome amigável "Monitoramento" (evita jargão SIEM). PRÓXIMO: item B (Wazuh via Catálogo +
  painel embutido/WebView).

## 2026-07-16 — Monitoramento: correções com 1 clique (prévia transparente + reverter)
- SecurityMonitor.Fix + fix(for:id): correção conhecida por evento (reaproveita scripts do
  Assistente): firewall, login-por-senha, fail2ban, auto-updates, apt upgrade, restart de
  serviço. undoArgs opcional — reversível só onde é seguro (firewall→disable, ssh-senha→
  remove drop-in). apt upgrade/instalações = não reversível (honesto).
- HLMonitorView: botão "Corrigir…" nos eventos → FixPreviewSheet (a "lupinha"): mostra
  passos + comando exato + se é reversível, depois Aplicar com log ao vivo. Seção
  "Correções aplicadas nesta sessão" com Reverter (in-memory).
- Testes: fix(for:) reversibilidade + trava allow-22-antes-de-enable. Verificado ao vivo:
  aplicar firewall (SSH continuou OK) → reverter (inactive). 228 testes.
- Wazuh: fica como cartão OPCIONAL do Catálogo (item B), instala só quando o usuário clicar
  (hardware real 64/128GB) — sem risco de sobrecarregar a VM agora.

## 2026-07-16 — Servidor item B: painel embutido (WebView) + Metabase + Wazuh (stack opcional)
- WebPanel.swift: EmbeddedWeb (WKWebView) + ServicePanelSheet (recarregar + "Abrir no
  navegador") + PanelTarget. Info.plist do app empacotado ganhou NSAllowsLocalNetworking
  (WebView carrega http self-hosted da rede local; não libera http arbitrário).
- Catálogo: serviços instalados agora têm "Abrir painel" (embutido, com fallback navegador).
  Metabase adicionado como template single-container (BI self-hosted, port 3010→3000,
  volume+MB_DB_FILE). Nova seção "Stacks avançados" com Wazuh (SIEM/XDR) — script oficial
  single-node via git+compose, marcado pesado (~4GB), instala SÓ quando clicar (opcional).
- Testes: catálogo tem Metabase + stack Wazuh (shape/aviso RAM). Verificado ao vivo: deploy
  do Metabase → container up, HTTP 200 do Mac. Wazuh NÃO rodado (opcional, hardware real).
- Nota honesta: WebView embutida carrega http no app EMPACOTADO (ATS liberado); em `swift
  run` (dev) pode não renderizar http — o botão "Abrir no navegador" sempre funciona.

## 2026-07-16 — Pente-fino 100%: auditoria de código do programa todo + correções
- Auditoria com 3 agentes de revisão em paralelo (correção/segurança, robustez/UX, testes).
  Achados consolidados, verificados um a um e corrigidos. Build limpo, 239 testes passando
  (eram 228; +11 novos) e app relançado OK.
- Segurança (defesa em profundidade — InputValidator):
  - `isValidBrewToken`/`isValidServiceName`/`isValidFileName`/`isValidBundleID` agora
    bloqueiam `..` (path traversal) explicitamente; `isValidFileName` também barra `.`.
  - Novo `isValidContainerName` (só `[A-Za-z0-9][A-Za-z0-9_.-]*`, sem `/ : @`, sem `..`),
    usado no deploy (RemoteDeploy) e no Catálogo (ServiceTemplate.validate) — antes usava o
    `isValidDockerName` mais frouxo, que aceita refs de imagem.
  - `isValidRepoFullName` mais estrito (âncora no 1º char de owner e repo).
- Revalidação DENTRO das funções (não só no chamador):
  - RemoteDeploy.buildRunArgs: nome/porta inválidos → aborta ("deploy cancelado"), não monta
    o `docker run`. RemoteBackup.backupArgs/restoreArgs: caminho não-absoluto/perigoso e id
    não-hex → aborta ("inválido"), não roda o restic.
  - RemoteTask.redactedDisplay: ao exibir o comando no log, valores de
    password/token/secret viram `CHAVE=•••` (segredo nunca em log). Marcada `nonisolated`.
- Robustez:
  - Shell.stream: drena o resto do pipe no terminationHandler (últimas linhas do log não
    somem mais) e decodifica UTF-8 tolerante (não descarta chunk com multibyte cortado).
  - LinuxStats.parseCPUSample: total usa só os 8 primeiros campos de /proc/stat
    (guest/guest_nice já contam em user/nice — evita contar em dobro).
  - RemoteNetwork.ports: cai para `ss -tln` (sem sudo) se `sudo -n ss -tlnp` falhar/vier
    vazio — mostra as portas mesmo sem o nome do processo.
  - Stores (TapProviders) filtram programas inválidos ao decodificar (consistência).
- UX / estado ao trocar de host (evita mostrar/agir com dados do host anterior):
  - HLMonitorView: zera "correções aplicadas" ao trocar de host; Reverter agora pede
    confirmação (pode reduzir a segurança). FixPreviewSheet só marca aplicado no sucesso.
  - HLAuditView/HLStorageView: limpam resultados ao trocar de host.
  - HLDeployView: limpa o formulário ao trocar de host (não fazer deploy no servidor errado);
    canDeploy usa isValidContainerName. HLBackupsView recarrega ao trocar de sub-aba.
  - HLServicesView: parar/desabilitar serviço CRÍTICO (ssh, docker, rede, logind) agora pede
    confirmação (pode te desconectar ou derrubar containers, inclusive no boot).
  - Textos desatualizados ("prévia visual"/"protótipo") corrigidos em SettingsView, AppState
    e HomeLab.swift — todas as telas do Servidor usam dados reais via SSH.
- Testes novos: validadores (container/service/file/repo + bloqueio de `..`), abort do
  deploy/backup com entrada perigosa, redação de segredos no log, CPU sem guest, e smoke
  render de TODAS as telas do Servidor/HomeLab (HL*), que não tinham cobertura de render.
- Adiado ao roadmap (anotado, não feito agora): pinning de fingerprint no lugar de
  accept-new; IPv6; reuso de conexão SSH (ControlMaster); `--env-file` p/ segredos no deploy.

## 2026-07-17 — Auditoria Externa: Fase 1 (schema v1 + coletor + parser/pontuação)
- Coletor portátil `Uptend/Scripts/audit-collector.sh` (bash, read-only, sem rede, não
  ofuscado): detecta modo usuário vs admin (sudo -n/root), coleta máquina/hardware, SO+EOL,
  discos+SMART, e gera achados de hardening (SSH root/senha, firewall, fail2ban,
  atualizações automáticas, updates de segurança pendentes, SO EOL, portas expostas). Lynis
  opcional (UPTEND_RUN_LYNIS=1). Escreve JSON schema v1 + arquivo `.sha256` (cadeia de
  custódia) e imprime o caminho. JSON montado com escaper próprio (zero dependência).
- Schema v1 em `Sources/UptendCore/ExternalAudit.swift` (lógica pura, pública, testável):
  modelos Codable (collector/host/machine/os/disks/findings/lynis), `ExternalAuditParser`
  (decodifica, valida schema_version ≤ atual → erro amigável se for mais novo) e
  `AuditScoring.evaluate` → nota 0–100 (100 − deduções por severidade), contagem por
  severidade, semáforo por categoria (verde/amarelo/vermelho) e top riscos (piores primeiro,
  "ok" fora). `AuditSeverity` Comparable com peso.
- Verificado AO VIVO no uptend-lab (modo admin): JSON válido, discos limpos (só vda/vdb/vdc —
  filtra zram/nbd/loop/size 0), achou "1 update de segurança pendente" e "portas expostas
  22 3001 3010 8080 8888". Fixture real salva em Tests/UptendTests/Fixtures/lab-audit.json.
- Correções feitas na verificação: parse do modelo do disco (mostrava "disk"), coluna do
  lsblk, CPU model via lscpu com fallback e limpeza do "-" de kernels virtuais.
- Testes: 7 novos (ExternalAuditTests) — parse mínimo, rejeita versão futura/lixo, ordem+peso
  de severidade, cálculo de nota/semáforo/top-risco, piso 0, e decodificação da fixture REAL.
  Package.swift do testTarget ganhou `resources: [.copy("Fixtures")]`. Total: 246 testes.
- Próximo (Fase 2): aba "Auditoria Externa" no Uptend — importar/arrastar arquivo (ou rodar o
  coletor num host conectado via SSH) → painel (nota/semáforo/CIS/top-riscos/hardware EOL).

## 2026-07-17 — Auditoria Externa: Fase 2 (aba nova + importar/coletar + painel)
- Nova categoria "Auditoria Externa" (Category.auditoria) com subseções Painel / Importar-Coletar
  / Histórico, roteada em RootView. Ícone chart.bar.doc.horizontal.
- Serviço `ExternalAuditService` (@MainActor, injetado no app): importa arquivo `.json`
  (arrastar ou NSOpenPanel), valida via UptendCore (erro amigável se schema for mais novo),
  deduplica por hash SHA-256 do conteúdo, guarda histórico em
  ~/Library/Application Support/Uptend/audits e recarrega no init. `storeDirectory` injetável
  para testes (não toca no Application Support real).
- "Coletar de um host…": roda o coletor read-only num RemoteHost já cadastrado via SSH —
  envia o script por base64 (→ /tmp), executa, traz o JSON pela saída padrão e limpa os
  temporários. Uma passada, sem alterar o servidor.
- O coletor virou RECURSO do app: movido de Scripts/ para
  `Sources/Uptend/Resources/audit-collector.sh` (Package.swift: resources:[.copy(...)]),
  lido via Bundle.module para o envio por SSH.
- Painel (AuditDashboardView): selo de nota 0–100 (anel colorido pelo semáforo), resumo por
  severidade, TOP riscos (com impacto de negócio + recomendação), semáforo por categoria
  (grid), cartões de máquina/CPU/RAM/kernel/EOL/uptime, discos (SMART), Lynis e a lista
  completa de achados. Import view com zona de arrastar + nota honesta (read-only/consentimento).
- Verificado AO VIVO: a pipeline exata do "Coletar de host" (base64→run→cat→limpa) roda no
  uptend-lab e devolve JSON válido (7 achados). App relançado sem crash.
- Testes: +7 (ExternalAuditServiceTests: ingest/dedup/rejeita lixo+versão nova/persiste/remove)
  e smoke render das 3 telas da aba. Total: 253 testes.
- Próximo (Fase 3): relatório HTML com gráficos (autocontido) + Markdown (cru/IA) a partir da
  auditoria carregada.

## 2026-07-17 — Auditoria Externa vira ABA de topo própria (não mais dentro de "Este Mac")
- A pedido: promovida de categoria dentro de "Este Mac" para uma ABA de topo ao lado de
  Este Mac / HomeLab / Servidor, com barra lateral e área próprias (pensada para crescer com
  ferramentas específicas).
- `HostContext` ganhou o caso `.auditoria` (+ `isAuditoria`). AppState ganhou
  `auditoriaSection`/`auditoriaSubID` (+ subseção derivada). RootView roteia as 3 colunas
  para AuditoriaSidebar/ContentColumn/DetailColumn quando a aba está ativa.
- Novo `AuditoriaSection` enum (Painel/Importar-Coletar/Histórico) no lugar das subseções que
  antes ficavam em Category.auditoria (removida do menu de "Este Mac"). Chip "Auditoria
  Externa" adicionado ao HostTabBar. Navegação interna das telas passou a mexer em
  `state.auditoriaSection` (não mais `state.subID`).
- Build limpo; 253 testes (smoke agora cobre também as 3 colunas da aba). App relançado OK.

## 2026-07-17 — Auditoria Externa: Coletor avulso + Fase 3 (relatórios HTML/Markdown)
- Coletor avulso: na aba Importar/Coletar, cartão "Coletor avulso (pen drive / sem SSH)" com
  "Salvar coletor…" (NSSavePanel → escreve o audit-collector.sh e marca executável 0755) +
  instruções de uso passo-a-passo. `ExternalAuditService.exportCollector(to:)` /
  `collectorScript()`.
- Fase 3 — relatórios (lógica pura em `Sources/UptendCore/AuditReport.swift`, testável):
  - `AuditReport.markdown(_:)` — documento cru/estruturado (nota, resumo por severidade, top
    riscos c/ impacto+recomendação, máquina/SO, discos em tabela, semáforo por categoria,
    todos os achados, Lynis). Bom para arquivar e para IA reprocessar.
  - `AuditReport.html(_:)` — relatório AUTOCONTIDO: CSS inline + gauge SVG inline + barras de
    severidade + cartões + tabela de discos. Zero recurso externo (abre offline; será a base
    do PDF na Fase 4). Suporta claro/escuro (prefers-color-scheme) e tem regras de @media print.
    Todo texto do dado coletado passa por escape HTML (não injeta markup).
- UI: menu "Relatório" no painel → Ver (pré-visualização em WKWebView via novo
  `EmbeddedHTML`), Salvar HTML…, Salvar Markdown…, Copiar Markdown. Botão "Abrir no navegador"
  na pré-visualização (escreve HTML temporário e abre).
- Testes: +4 (AuditReportTests) — seções do Markdown, HTML autocontido/sem recurso externo,
  escape de texto perigoso (`<script>`), e nota refletida no MD. Usa a fixture real do lab.
  Total: 257 testes. App relançado OK.
- Próximo (Fase 4): PDF a partir do HTML (print-to-PDF); depois Power BI (dataset + .pbit) e
  histórico/comparativo temporal.

## 2026-07-17 — Auditoria: correção das barras + relatório EXECUTIVO + retenção/histórico
- Bug corrigido: as barras de "Resumo por severidade" no HTML não apareciam (o `<span>` de
  preenchimento era inline → width/height ignorados). Agora `display:block` + largura
  proporcional (mín. 6% p/ ficar visível; 0 quando não há achados).
- Relatório EXECUTIVO (diretoria) — `AuditReport.executiveHTML(_:)`: veredito em linguagem
  de negócio (boa/atenção/crítica), Panorama de risco (KPIs), alertas de continuidade
  (SO em EOL, updates de segurança, disco com falha), "Plano de ação recomendado" (sugestões
  priorizadas: o que fazer + por que importa, derivado de recommendation+businessImpact dos
  achados) e "O que já está protegido" (pontos fortes). Template próprio, mais limpo/whitespace,
  claro/escuro, print-friendly. Menu "Relatório" agora tem seções Executivo (diretoria) e
  Técnico; ambos com Ver (WebView) e Salvar.
- Histórico/retenção (no store de arquivos existente — sem SQLite): `retentionDays=90` com
  auto-poda na abertura (pruneOld), `clearAll()` (Limpar histórico, com confirmação) e
  `storageBytes()` (mostra espaço ocupado). Nova seção "Saúde ao longo do tempo": agrupa por
  servidor e mostra a evolução da nota (Sparkline + delta) quando há ≥2 coletas do mesmo host.
- Testes: +6 (executivo: negócio/autocontido/veredito por faixa/escape; serviço:
  clearAll/retenção poda antigas/mantém recentes). Total: 263. App relançado OK.
- Decisão: mantido o histórico em ARQUIVOS JSON (Application Support) em vez de SQLite —
  já funciona como base por-máquina, é transparente (dá para ler os arquivos) e simples;
  SQLite só compensaria com analytics pesado (aí o caminho é Metabase/Postgres do plano).

## 2026-07-17 — Auditoria: pente-fino no coletor + relatório executivo + PDF (Fase 4)
- Coletor expandido (pente-fino no SO), verificado ao vivo no uptend-lab:
  - Recursos/continuidade: uso do disco raiz (% e livres), swap, reinício pendente
    (/var/run/reboot-required), relógio sincronizado (NTP via timedatectl).
  - Contas/privilégios: nº de contas com login, membros de sudo/wheel, contas SEM senha
    (admin, /etc/shadow).
  - Novos achados: disco raiz cheio (≥90% alto / ≥80% médio), reinício pendente, relógio
    fora de sincronia, SSH MaxAuthTries alto, sudo NOPASSWD, /etc/shadow legível, senha vazia
    (crítico). Schema v1 ganhou `resources` e `users` (opcionais, retrocompatíveis).
- Relatórios agora mostram os novos dados (Markdown + HTML técnico + painel do app: cartões de
  uso de disco, swap, reinício, NTP, contas/sudo). Achados de recurso entram automaticamente
  no plano de ação do relatório executivo.
- Fase 4 — PDF: `HTMLToPDF` (WKWebView.createPDF, offline) converte o mesmo HTML autocontido
  em PDF. Menu "Relatório" ganhou "Salvar (PDF)…" para o executivo e o técnico.
- Fixture do lab regenerada (10 achados, com resources/users). Testes: fixture agora valida
  resources/users; +1 (relatórios incluem disco/sudo). Ajustado o teste que dependia de um
  achado transitório (update de segurança que o lab já aplicou). Total: 264 testes. App OK.

## 2026-07-17 — Auditoria: fix do Lynis + Docker/perfil do servidor + data-hora
- Bug do Lynis corrigido: o coletor agora LÊ o /var/log/lynis-report.dat já existente
  (sem re-rodar) — então a Auditoria Externa enxerga o índice/avisos mesmo quando o Lynis foi
  rodado antes (ex.: pelo botão do HomeLab). Toggle "Rodar Lynis (mais lento)" na coleta força
  uma execução nova (UPTEND_RUN_LYNIS=1). Verificado no lab (índice 67).
- Coletor + schema ganharam `docker` (containers: nome/imagem/estado/status) e `profile`
  (prontidão 0–100 por finalidade: Python/Node/Containers/Banco/Web/Segurança, com indícios
  presentes/ausentes e o propósito predominante). Detecção por comando/imagem/serviço/nº de
  containers. Verificado no lab: 6 containers, perfil "Plataforma de containers 100%".
- Relatórios: seção "Docker/containers" (com função amigável de cada imagem) e "Perfil do
  servidor" no técnico e no painel; no EXECUTIVO uma seção "Para que serve este servidor"
  (propósito predominante + barras de prontidão + lista dos serviços em execução com descrição
  em linguagem de negócio). Novo `AuditReport.containerPurpose(image:)` mapeia imagens comuns.
- Histórico/painel agora mostram DATA + HORA da coleta (AuditFormat.dateTime, fuso local) —
  distingue coletas feitas em sequência.
- Testes: +4 (Docker/perfil nos 3 relatórios, containerPurpose). Fixture regenerada (docker+
  profile+lynis). Total: 266 testes. App relançado OK.

## 2026-07-17 — Banco central (UptendVault/SQLite) + relatório SOC
- UptendVault: banco central do app em SQLite (libsqlite3 do sistema, sem dependência).
  Tabela `records` (id, kind, source, title, created_at, imported_at, size_bytes, payload).
  API: insert (dedup por id), records(kind:), payload(id:), delete, clear(kind:),
  pruneOlderThan, totalBytes, summary. `UptendVault.shared` (Application Support/Uptend/
  uptend.sqlite) + `.inMemory()` para testes.
- Auditoria Externa migrada do store de arquivos JSON para o Vault (kind=external_audit):
  persiste no banco, dedup por hash, retenção 90 dias (pruneOlderThan), Limpar e tamanho
  agora vêm do banco. `migrateLegacyFilesIfPresent()` importa uma vez as auditorias antigas
  (Application Support/Uptend/audits → banco; pasta renomeada p/ audits-migrado). Verificado:
  migração rodou, uptend.sqlite criado.
- Relatório SOC (segurança/operacional): `AuditReport.socHTML` — postura (nota + índice
  Lynis + críticos/altos), superfície de exposição (contas/sudo/containers), achados por
  severidade (crítico→baixo) com evidência/recomendação, tabela de Conformidade CIS
  (X/Y controles atendidos) e anexo Lynis. Menu "Relatório" agora tem seção Segurança (SOC)
  com Ver + Salvar PDF.
- Testes: +9 (UptendVaultTests: insert/dedup/filtro-limpeza por tipo/prune/tamanho/summary/
  persistência) e +1 SOC; ExternalAuditServiceTests reescritos sobre o Vault; smoke usa
  banco em memória (não toca no banco real). Total: 275 testes. App relançado OK.
- Próximo do banco central: plugar as outras abas (Este Mac etc.) e uma tela "Dados do app"
  com o resumo por tipo (vault.summary) + limpar por tipo.

## 2026-07-17 — "Este Mac" plugado no banco central + tela "Dados do app"
- UptendVault virou ObservableObject (revision bump nas escritas) e é injetado como
  environmentObject; ExternalAuditService continua usando a mesma instância `.shared`.
- Inventário do Mac (ReportData é Codable) agora pode ser guardado no banco: botão
  "Guardar no histórico" no ReportPanel salva um snapshot (kind=mac_report, source=nome do
  Mac, createdAt=generatedAt). Dedup por conteúdo. Cria histórico da máquina no tempo.
- Nova tela Configurações › "Dados e histórico" (AppDataView): resumo por tipo (Auditorias
  de servidores / Inventários do Mac) com quantidade e tamanho, limpar por tipo, limpar tudo,
  e lista de registros com data/hora e remover individual. Tudo local (SQLite).
- VaultKind ganhou macReport + label()/icon() amigáveis. Smoke cobre AppDataView; env de
  testes injeta UptendVault.inMemory(). Total: 275 testes. App relançado OK.
- Base pronta para plugar mais abas (scans de segurança, limpeza etc.) no mesmo banco.

## 2026-07-17 — Relatório do Mac vira categoria própria (removida a lupa global)
- Decisão de UX (a pedido): "relatório mora onde o assunto mora". A lupa global do topo
  (que gerava sempre o inventário do Mac, mesmo olhando um servidor) foi REMOVIDA.
- Novo `Category.report` ("Relatório", ícone doc.text.magnifyingglass) na barra lateral do
  Este Mac, com a subseção "Inventário do Mac" → ReportPanel inline. Só aparece em Este Mac
  (categorias primárias não são mostradas nos hosts remotos).
- Removidos `AppState.pendingReport` e a sheet de relatório do RootView (só o RootView os
  usava). Padrão agora uniforme: cada área gera o próprio relatório no seu contexto
  (Este Mac na lateral; servidores/Auditoria já têm o deles). 275 testes, app relançado OK.

## 2026-07-17 — Auditoria: "Relatórios" e "Dashboard (BI)" na barra lateral
- A pedido, mesma lógica do Este Mac: relatórios agora numa SEÇÃO da barra lateral da
  Auditoria (não mais no menuzinho do Painel). AuditoriaSection ganhou `relatorios` e `bi`.
- AuditReportsView: cartões dos 3 relatórios (Executivo/SOC/Técnico) com Ver + PDF + HTML
  (+ Markdown/Copiar no técnico). O Painel ganhou só um atalho "Relatórios". Helpers de
  exportação extraídos p/ `AuditExport` (saveText/copy/savePDF).
- Decisão de BI (usuário escolheu): Metabase embutido em vez de Power BI. AuditBIView:
  - Exporta DATASET CSV (lógica pura `AuditDataset` em UptendCore): resumo (1 linha por
    auditoria — séries temporais) e achados (1 linha por achado — drill-down), da auditoria
    atual OU do histórico completo. CSV RFC-4180 (escapa vírgula/aspas).
  - Metabase embutido: campo de URL (@AppStorage) → abre o painel numa WebView
    (ServicePanelSheet) + "Abrir no navegador". Orientação honesta (subir via Catálogo,
    criar admin, habilitar Uploads, subir o CSV; ~1–2 GB RAM; dados ficam self-hosted).
  - Honestidade registrada: .pbix é formato fechado da Microsoft — Uptend não lê/renderiza;
    por isso o caminho é Metabase (self-hosted, o app embute) + export CSV.
- Testes: +4 (AuditDataset: cabeçalhos/linhas/escape/vazio) + smoke das 2 telas. Total: 279.
  Verificado: Metabase do lab responde 200 em :3010 (dá para testar o embed).
- Pendente do BI: auto-carregar o CSV e provisionar dashboards via API do Metabase (fase 2).

## 2026-07-17 — Metabase: admin automático (API) + tela "Preparar ambiente"
- Auto-setup do Metabase (fim do passo manual no navegador): `MetabaseAPI` (URLSession) —
  setupToken (GET /api/session/properties → "setup-token"; nil = já configurado) e createAdmin
  (POST /api/setup cria o admin e finaliza). Na aba Dashboard (BI), card "Configurar admin
  automaticamente": usuário define o e-mail 1x; o app GERA senha forte, cria o admin, guarda
  no Keychain (MetabaseCredentials, 1 item por endereço — atualiza, não duplica) e copia a
  senha. Mostra e-mail + "Copiar senha" se já existir; detecta "já configurado".
- VERIFICADO AO VIVO: subi um Metabase novo no lab (porta 3011), o fluxo exato (get token →
  POST /api/setup) retornou HTTP 200 + id de sessão e o token sumiu depois. Instância de teste
  removida.
- Tela "Preparar ambiente" (Início › Preparar ambiente): detecta ferramentas do Mac
  (Homebrew, git, docker, lynis, clamav) por presença de binário e instala sob demanda com
  1 clique via BrewService (nunca em segundo plano). "Instalar tudo que falta"; banner com o
  comando oficial se o Homebrew faltar; re-detecta ao terminar cada instalação.
- Decisões do usuário: senha do admin gerada pelo app + Keychain (um item por Metabase, sem
  acumular); instalação de ferramentas via tela com 1 clique (não silenciosa no 1º uso).
- Testes: +3 (senha forte: complexidade/unicidade; credencial Codable) + smoke. Total: 282.

## 2026-07-17 — Metabase: painel abre já logado + guardar conta existente + UX do card
- "Abrir painel" agora AUTENTICA antes: `MetabaseAPI.login` (POST /api/session) → cookie
  `metabase.SESSION` injetado na WKWebView (EmbeddedWeb ganhou `cookie:`; ServicePanelSheet
  ganhou `sessionCookie:` + selo "Sessão automática"). Fim do login manual no painel embutido.
- VERIFICADO AO VIVO (Metabase novo, porta 3012): POST /api/session devolve id; requisição
  com Cookie metabase.SESSION responde autenticada (superuser: true); sem cookie = HTTP 401.
  Instância de teste removida.
- "Já tenho conta": para um Metabase que JÁ tem admin (caso do lab :3010), o usuário informa
  e-mail+senha, o app valida via login e guarda no Keychain → painel passa a abrir logado.
- Senha agora tem botão de MOSTRAR (olho) além de copiar.
- UX corrigida (o usuário não conseguia habilitar o botão): os cards "Metabase embutido" e
  "Configurar admin" viraram UM card em 2 passos numerados; campo do endereço fica destacado
  em laranja quando vazio; menu "Usar host…" preenche a URL a partir dos hosts cadastrados;
  aviso do motivo do botão desabilitado agora é laranja e visível. URL aceita sem "http://".
- 282 testes passando; app relançado.

## 2026-07-20 — Dashboard nativo (HTML/JS interativo) — decisão do usuário
- Decisão: dashboard rico em HTML/JS nativo (mantém SQLite; NÃO migrar p/ Postgres — evita
  acoplar o app ao Docker) + Metabase como opção AVANÇADA. Motivo: objetivo é apresentar/
  imprimir/PDF, e HTML nativo faz isso melhor (Metabase não imprime/PDF bem) e sem infra.
- `AuditDashboard.html(_ audits:)` em UptendCore (puro): página autocontida, offline, com
  gráficos SVG + JavaScript vanilla (sem CDN). Usa o HISTÓRICO: linha de nota ao longo do
  tempo (hover mostra data/nota), barras por severidade, chips de categoria, top riscos e
  tabela de servidores. Filtro por servidor (select) re-renderiza; "Todos" mostra barras da
  nota mais recente por servidor. @media print p/ imprimir/PDF.
- AuditBIView reorganizada: card "Dashboard visual" no topo (Ver / Salvar PDF / HTML), e
  Metabase + export CSV foram para um DisclosureGroup "Avançado". Preview via WKWebView
  (EmbeddedHTML executa o JS).
- VERIFICADO: node --check (sintaxe JS ok) + execução com DOM stubado (render() produz svg,
  barras, tabela, sub-título com host/coletas). Testes AuditDashboardTests (autocontido/sem
  http, JSON embutido válido, histórico vazio). Total: 285. App relançado.

## 2026-07-20 — Relatórios turbinados: mapeamento de frameworks (CIS/ISO/NIST/OWASP)
- `ComplianceMap` (UptendCore): relaciona cada achado a CIS, ISO/IEC 27001 (Anexo A),
  NIST CSF (função) e OWASP Top 10 2021, com chave-base normalizada (remove "-ok" e sufixo
  de disco) + CIS de reserva. `coverage()` calcula aderência por framework (atendidos/
  verificados). Nomes amigáveis de NIST/OWASP. Disclaimer honesto (cobertura parcial).
- Relatórios diferenciados por público:
  - EXECUTIVO: seção "Conformidade e boas práticas" (barras de aderência por framework em
    linguagem de negócio) + nota regulatória (LGPD quando há falha de acesso/credencial) +
    destaque do framework mais fraco. Sem tabela técnica.
  - SOC: "Aderência por framework" (barras) + "Mapeamento de controles" (tabela achado →
    CIS/ISO/NIST/OWASP + status) + chips de framework em cada achado.
  - TÉCNICO: chips de framework em cada achado + "Apêndice — mapeamento de conformidade"
    (barras + tabela).
  - MARKDOWN: seção "Conformidade (frameworks)" com tabela de aderência + mapeamento.
- CSS: chips coloridos por framework (.fw cis/iso/nist/owasp).
- Verificado: HTML dos 3 relatórios bem-formado (parser sem tags abertas) e diferenciação
  confirmada (exec=LGPD/ISO sem tabela; SOC=mapeamento; téc=chips+apêndice). Testes
  ComplianceMapTests (mapeamento/normalização/cobertura/nomes) + asserts nos relatórios.
  Total: 291 testes. App relançado.

## 2026-07-20 — Coletor ampliado: +10 verificações de hardening (mapeadas a frameworks)
- Novos achados (read-only, cada um mapeado a CIS/ISO/NIST/OWASP no ComplianceMap):
  - SSH: PermitEmptyPasswords, X11Forwarding, ClientAliveInterval (timeout de sessão).
  - MAC: AppArmor (Ubuntu/Debian) OU SELinux (RHEL/Fedora) — checa os dois, reporta o que
    existir (enforcing/ativo). No lab detectou AppArmor inativo.
  - auditd ativo (trilha de auditoria); ASLR (kernel.randomize_va_space); unicidade do UID 0;
    expiração de senha (login.defs PASS_MAX_DAYS); firewall default-deny (ufw verbose);
    presença de antimalware/rootkit (rkhunter/chkrootkit/clamav).
- Esclarecido: SELinux e AppArmor são complementares (não é só Fedora) — o coletor cobre
  ambos; um Fedora server futuro confirmará o SELinux.
- Verificado ao vivo no lab: 21 achados (era ~10). Fixture regenerada. ComplianceMap ganhou
  as chaves novas; +1 teste. Total: 292 testes. App relançado.
- Frameworks: mantidos CIS/ISO 27001/NIST CSF/OWASP; PCI-DSS, SOC 2 e LGPD/GDPR ficam como
  possível ampliação futura (LGPD já citada no executivo).

## 2026-07-20 — Relatórios com assinatura própria (remediação, MITRE, maturidade)
- Três mapas puros novos em UptendCore: `RemediationMap` (comando de correção exato + esforço
  ganho-rápido/projeto por achado), `MitreMap` (achado → técnica MITRE ATT&CK + tática) e
  `ComplianceMap.nistFunctionCoverage` (cobertura por função do NIST CSF).
- TÉCNICO ganhou o comando exato de correção em cada achado aberto (bloco <pre class=cmd>)
  + apêndice de conformidade. Markdown ganhou "Plano de remediação" com blocos ```bash``` e
  referência ATT&CK (bom p/ IA reprocessar).
- SOC ganhou "Cobertura por função (NIST CSF)" (barras I/P/D/R/R), "Mapeamento MITRE ATT&CK"
  (tabela achado→técnica→tática) e "Detecção e resposta recomendadas" (dicas derivadas dos
  achados). Já tinha aderência por framework + mapeamento de controles.
- EXECUTIVO ganhou nível de maturidade (Inicial/Básico/Gerenciado/Otimizado), seção "O que
  está em jogo" (consequências de negócio consolidadas) e, no plano de ação, o rótulo de
  esforço (Ganho rápido × Projeto) + contagem. Já tinha aderência/LGPD.
- Verificado: HTML dos 3 bem-formado (parser sem tags abertas), assinaturas presentes,
  tamanhos exec 16KB / SOC 21KB / téc 32KB (bem mais ricos). Testes RemediationMitreTests +
  eachReportHasItsSignature. Total: 297 testes. App relançado.

## 2026-07-20 — Coletor +7 verificações, PCI-DSS (5º framework), esforço no executivo
- Coletor ampliado (26 achados, era 21): SSH LoginGraceTime; /tmp partição separada+noexec;
  core dumps SUID (fs.suid_dumpable); SYN cookies; logs persistentes (journald); hash de
  senha (ENCRYPT_METHOD SHA512/YESCRYPT); umask padrão. Verificado no lab.
- PCI-DSS como 5º framework: ComplianceFramework.pci + FrameworkRefs.pci + pciTable (Req
  1/2/5/6/8/10 por área). Aparece nas barras de aderência, na tabela de mapeamento (coluna
  PCI-DSS) e nos chips (.fw.pci). RemediationMap+MitreMap cobrem os novos achados.
- Executivo: plano de ação agora estima esforço qualitativo ("ganhos rápidos = minutos;
  projetos = dias a semanas").
- Testes: pciDssIsMappedAndInCoverage + verificação PCI nos relatórios. Total: 298. App
  relançado. Frameworks agora: CIS, ISO 27001, NIST CSF, OWASP, PCI-DSS.

## 2026-07-20 — Nível empresarial: +5 checks, pontuação por área, acabamento profissional
- Coletor: 31 achados (era 26). Novos: SSH AllowTcpForwarding; hardening de rede do kernel
  (accept/send_redirects, rp_filter); vazamento de info do kernel (kptr_restrict/dmesg_restrict);
  permissões de /etc/passwd e /etc/group; complexidade de senha (pwquality minlen). Mapeados
  em ComplianceMap/PCI + RemediationMap + MitreMap.
- `AuditDomains` (UptendCore): pontuação 0–100 por ÁREA de risco (Acesso, Rede, Endurecimento,
  Atualizações, Registro, Discos) — barras nos 3 relatórios + tabela no Markdown.
- Acabamento profissional (todos os relatórios): faixa "CONFIDENCIAL", bloco de metadados
  (servidor/SO/data-hora/modo/escopo/ferramenta/ID), legenda de severidade e seção
  "Metodologia e frameworks". Executivo ganhou "Sumário executivo" (parágrafo) e H1s próprios
  ("Relatório Executivo/Técnico/SOC de Segurança"). Rodapé com classificação + data legível.
- Verificado: HTML dos 3 bem-formado (parser sem tags abertas), com CONFIDENCIAL + Pontuação
  por área + Metodologia; tamanhos exec 23KB / SOC 32KB / téc 48KB. Testes AuditDomainsTests
  + estrutura profissional. Total: 301. App relançado. Frameworks: CIS/ISO/NIST/OWASP/PCI-DSS.

## 2026-07-21 — +4 checks, CIS Controls v8 + SOC 2, comparação entre auditorias
- Coletor: 35 achados (era 31). Novos: /var e /home em partição separada; bloqueio de conta
  PAM (faillock/tally); permissões de arquivos sensíveis em massa (sshd_config, crontab,
  sudoers, passwd, group, shadow, gshadow — world-writable = high).
- Frameworks: agora SETE — CIS Benchmarks, ISO 27001, NIST CSF, OWASP, PCI-DSS, +CIS
  Controls v8 e +SOC 2. ComplianceMap refatorado com grupos por área (areaAuth/Net/Patch/
  Cfg/Log/Mal/Disk) → tabelas PCI/CISv8/SOC2 compactas. Aparecem nas barras de aderência.
- Comparação entre duas auditorias: `AuditCompare.compare` (resolvidos/novos/persistentes,
  delta de nota, variação por área). `AuditReport.comparisonHTML` (relatório de evolução).
  UI: botão "Comparar" na linha de tendência do Histórico (2 últimas coletas do host) →
  abre o relatório numa WebView.
- Verificado ao vivo (35 achados) + HTML bem-formado (comparação e SOC-com-7-frameworks,
  parser sem tags abertas). Testes: AuditCompareTests + cisV8AndSoc2Mapped. Total: 305.
  App relançado.

## 2026-07-21 — TLS: certificados (A) + config (B) no coletor + scanner nativo pentester (C)
- (A) Coletor lê a VALIDADE de certificados no disco (letsencrypt/live, certs referenciados
  no nginx/apache) via openssl (base do sistema) → achados cert-expired/expiring/ok.
  Verificado: cert de teste de 10 dias detectado como "expira em 9 dias". (B) lê ssl_protocols
  do nginx/Apache e reprova TLS 1.0/1.1. Mapeados em ComplianceMap (cert-tls/tls-config →
  ISO A.10.1.1/A.14.1.2, NIST PR.DS-2, OWASP A02, PCI 4, CISv8 3, SOC2 CC6.7) + Remediation +
  Mitre (T1557).
- (C) `TLSScanner` NATIVO (Network.framework + Security) — SEM nmap/openssl/dependências: o
  app Mac faz o handshake e lê versão TLS, cifra, certificado (validade/auto-assinado/chave)
  e se aceita TLS 1.0/1.1. Modo pentester opt-in: nova seção "Varredura ativa" (AuditPentestView)
  com aviso de sondagem ativa + checkbox de AUTORIZAÇÃO + host/portas.
  VERIFICADO ao vivo: subi openssl s_server (self-signed, 10 dias) na :4443 do lab → o scanner
  leu "TLS 1.3 / TLS_AES_256_GCM_SHA384 / cert lab-tls-test / expira em 9 dias / auto-assinado
  / 2048 bits". Endpoint e regra ufw removidos depois.
- Princípio reforçado (a pedido): o programa NÃO vira "agregador" — A/B usam só ferramentas
  base (openssl/grep); C usa frameworks nativos da Apple. Nunca nmap. Total: 305 testes.

## 2026-07-21 — Varredura TLS integrada ao relatório+nota + porta→serviço + tags
- Mecânica definida (a pedido): scan é standalone; botão "Adicionar à auditoria atual" mescla
  os achados de TLS na auditoria selecionada → relatórios e NOTA passam a incluí-los
  (`ExternalAuditService.mergeScanFindings`: re-codifica JSON convertToSnakeCase, substitui no
  Vault com novo hash, re-pontua; re-scan substitui os "tls-scan-*", não acumula). Verificado
  em teste de round-trip.
- `PortService` (UptendCore): mapa porta→serviço + descrição p/ leigo + se "espera TLS"
  (443/993/465/636/8443…). `TLSScanner.findings(from:)` converte cada porta alcançável em
  AuditFinding (id tls-scan-<porta> → mapeia a tls-config/OWASP A02; severidade: legado/expirado
  = alto, weak/self-signed = médio/baixo, sem-TLS-onde-esperado = médio, saudável = ok).
- UI da Varredura ativa enriquecida: por porta mostra serviço, "aberta/fechada", versão TLS,
  cert/cifra/chave/auto-assinado, e tag de criticidade colorida (Crítico/Atenção/OK). Nota:
  como os achados viram findings, entram no domínio "Rede e firewall" da pontuação por área.
- Testes: TLSScannerFindingsTests (conversão + merge/rescore/substituição). Total: 307.

## 2026-07-21 — Plano de profissionalização da Auditoria (PLANO-AUDITORIA-PRO.md)
- Avaliação honesta do módulo: entregável ~78/100 corporativo; plataforma ~50/100.
- Criado `PLANO-AUDITORIA-PRO.md`: roteiro em fases (A relatório 78→90%: white-label,
  assinatura digital, evidência bruta, risk register; B GRC: gap-assessment/SoA, aceitação de
  risco, drift, baseline; C SOC: CVE, Sigma/Falco, SIEM/ticketing; D arquiteto: frota,
  playbook Ansible, mapa de superfície; E escopo: CSPM nuvem, Windows, k8s, bancos; F produto:
  i18n, CLI, templates) com notas técnicas, critério de aceite, prioridade/esforço, backlog
  curto, sequência recomendada (A1+A2 → B2 → A4+B1 → A3 → D1) e decisões em aberto.

## 2026-07-21 — FASE A / A1: white-label (marca do relatório)
- `ReportBranding` (UptendCore): empresa auditora, auditor+cargo, contato, cliente, nº do
  relatório, aviso de confidencialidade editável, logo (data-URI PNG). `AuditReport` (exec/
  SOC/técnico/markdown/comparação) ganhou `branding:` opcional → renderiza capa (.cover: logo
  + empresa + título + cliente/auditor/nº) e usa o aviso customizado; sem marca = layout atual.
- App: `BrandingStore` (UserDefaults) + tela Configurações › "Marca do relatório" (BrandingView:
  campos + upload de logo reduzido p/ 400px e embutido como PNG base64). Injetado em
  AuditReportsView e na comparação do Histórico.
- Testes: BrandingTests (aparece nos relatórios, escapa HTML, isConfigured, layout padrão sem
  marca) + smoke da BrandingView. HTML verificado bem-formado com capa. Total: 311. App relançado.

## 2026-07-21 — FASE A / A2: assinatura digital (integridade / cadeia de custódia)
- `ReportSignature` (UptendCore): manifesto {hash SHA-256 do JSON, assinatura ECDSA raw b64,
  chave pública b64, impressão digital, auditor, data}. `AuditSigner` (app, CryptoKit P-256):
  chave privada gerada e guardada no Keychain; sign(auditJSON, auditor) → manifesto;
  verify(auditJSON, manifesto) = hash bate E assinatura válida.
- Relatórios (exec/SOC/técnico) ganharam `signature:` opcional → seção "Assinatura digital"
  no rodapé (assinado por, impressão digital agrupada, data, hash). Sem assinatura = sem bloco.
- UI (Relatórios): switch "Assinar digitalmente os relatórios" (@AppStorage) + impressão da
  chave; "Salvar assinatura (.sig.json)" (manifesto para terceiros) e "Verificar .sig…"
  (confere um manifesto contra a auditoria atual → VÁLIDA/INVÁLIDA).
- Testes AuditSignerTests: assina→verifica OK; adulterar 1 byte reprova; hash trocado reprova;
  metadados; bloco no relatório. Total: 316 testes. App relançado. Fase A: A1+A2 concluídos.

## 2026-07-21 — Ajustes UX: cor da verificação + marca movida para Relatórios
- Bug corrigido: "INVÁLIDA" contém "VÁLIDA", então a verificação inválida ficava verde. Agora
  banner com ícone e cor certa: verde (válida) / vermelho (inválida) / laranja (erro de leitura).
- "Marca do relatório" saiu de Configurações (era coisa do Mac) e virou subseção de
  **Auditoria Externa › Relatórios** (coluna do meio: "Relatórios" + "Marca / dados da empresa").
  Roteado em AuditoriaDetailColumn por auditoriaSubID; removido de Category.settings/RootView.
- 316 testes. App relançado.

## 2026-07-21 — FASE A / A3: evidência bruta por achado (reprodutibilidade)
- Schema: AuditFinding ganhou `evidenceRaw` opcional (retrocompatível). Coletor: add_finding
  aceita 9º arg (saída bruta) com `redact_raw` (redige password/token/secret/api_key/bearer/
  credential e blocos PEM — case-insensitive GNU sed; "segredo nunca em log"). Populado em SSH
  (trecho do sshd -T), firewall (ufw status verbose), portas expostas (ss -tlnp). Limite 4 KB.
- Relatório TÉCNICO: bloco colapsável "Ver evidência (saída bruta)" (<details><pre>) por achado
  aberto; Markdown ganhou bloco ```…``` de Evidência. Escapado (não injeta HTML).
- Verificado ao vivo: 4 achados com evidência bruta (trecho real da config SSH etc.); redação
  testada no servidor (API_KEY/TOKEN/Bearer/PEM redigidos). Testes EvidenceTests. Total: 321.
  App relançado. Fase A: A1+A2+A3 concluídos; falta A4 (risk register).

## 2026-07-21 — Fix: evidência (details) expandida no PDF
- Bug (reportado): no relatório interativo (WebView/HTML) o `<details>` "Ver evidência" abre ao
  clicar; mas no PDF ficava fechado (não dá para clicar) e a evidência sumia. Correção:
  AuditExport.savePDF abre todos os `<details>` (`<details` → `<details open`) só na geração
  do PDF — o documento estático mostra as evidências; o HTML/preview seguem interativos.
- 321 testes. App relançado.

## 2026-07-21 — FASE A / A4: registro de risco (risk register) — Fase A concluída
- `RiskRegister` (UptendCore): achados abertos → riscos com probabilidade×impacto (matriz 5×5).
  Probabilidade da severidade + boost p/ exposição/acesso/patch; impacto da severidade; nível
  Baixo/Médio/Alto/Crítico por pontuação (1–25). IDs R-001…, ordenado por pontuação.
  matrixCounts (célula impacto×prob), csv() export.
- `AuditReport.riskRegisterHTML`: matriz de calor 5×5 colorida (contagem por célula) + tabela
  de riscos priorizados (ID, categoria, prob, impacto, pontuação, nível, tratamento). Executivo
  ganhou uma seção "Matriz de risco" compacta.
- UI: card "Registro de risco (GRC)" em Relatórios com Ver / PDF / CSV. Verificado: HTML
  bem-formado, 18 riscos no lab. Testes RiskRegisterTests. Total: 326.
- FASE A CONCLUÍDA (A1 white-label, A2 assinatura, A3 evidência bruta, A4 risk register).
  Próximo no plano: B2 (aceitação de risco/exceções), depois B1 (gap-assessment/SoA).

## 2026-07-21 — Matriz de risco legível + FASE B2 (aceitação de risco/exceções)

**Matriz de risco (correção visual):**
- Feedback: células vazias apareciam "cinza" no modo escuro (eu pintava a cor do nível com
  13% de opacidade e o degradê sumia). Corrigido: grade 5×5 inteira colorida (vazias no mesmo
  tom a ~62%), números em "pílulas" escuras legíveis, legenda Baixo/Médio/Alto/Crítico, eixos
  rotulados ("Impacto ↓ / Prob. →") e texto "Como ler". Confirmado pelo usuário na tela.

**FASE B2 — Aceitação de risco / exceções (GRC):**
- Core: `RiskException` (findingId, título, justificativa, responsável, aceito em, válido até,
  referência; datas ISO "yyyy-MM-dd", comparação lexicográfica = cronológica) + `RiskExceptions`
  (`effective` remove achados com exceção vigente → sai da nota/matriz; `accepted`/`expired`;
  exceção expirada volta a contar automaticamente).
- App: `RiskExceptionStore` (ObservableObject, UserDefaults por host = machineID ?? hostname;
  accept/revoke/isAccepted). Injetado no `UptendApp`.
- UI (Relatórios): card "Aceitação de risco (exceções)" — lista riscos abertos com botão
  "Aceitar risco" → sheet `RiskAcceptSheet` (justificativa obrigatória, responsável pré-preenchido
  do branding, validade via DatePicker padrão 90 dias, referência opcional); lista aceitos com
  "Revogar"; aviso laranja de exceções expiradas.
- Efetivo aplicado a Executivo + SOC + Registro de Risco (nota e matriz descontam aceitos);
  Técnico mantém inventário completo (inclusive aceitos). Nova seção "Riscos aceitos (exceções
  formais)" no relatório de risco (justificativa/responsável/validade/referência — auditável).
- Verificado: 18 riscos → aceitar 2 → 16 na matriz; HTML bem-formado (0 tags soltas), sem refs
  externas; `RiskExceptionTests` (dia-limite ainda vale, expirado volta, accepted só existentes).
  Total: 332 testes.
- Próximo no plano: B1 (gap-assessment por framework + SoA).

## 2026-07-21 — FASE B1 (gap assessment + SoA ISO 27001:2022)

**O que foi feito:**
- Core `ComplianceCatalog`: catálogo **completo do Anexo A da ISO/IEC 27001:2022 (93 controles)**
  em português, cada um com tema (Organizacional/Pessoas/Físico/Tecnológico) e natureza
  (automatizável = a coleta do host consegue inspecionar / manual = exige processo, política,
  pessoas ou físico). Como o `ComplianceMap` emite refs no padrão 2013 (A.9.x, A.12.x…), criei um
  mapa de transição 2013→2022 dos ~18 refs usados, para o cruzamento ficar no padrão atual.
- `soaISO27001(audit)` cruza catálogo × achados e dá status a CADA controle:
  Coberto (verifica e conforme) / Não conforme (verifica e há achado aberto) / Não avaliado
  (técnico que poderíamos checar mas esta coleta não cobriu) / Manual (fora do alcance da coleta).
  `summary` com dois percentuais honestos: % sobre o que foi verificado e % sobre todo o escopo
  automatizável. Export CSV (94 linhas).
- Relatório `AuditReport.soaHTML`: resumo por status (chips coloridos + %), tabela completa por
  tema e um "como ler" explicando cada status. É a **Declaração de Aplicabilidade (SoA)** que a
  ISO 27001 exige — ponto de partida técnico, com a ressalva de que aplicabilidade/justificativa
  final são decisão do responsável pelo SGSI.
- UI (Relatórios): card "Declaração de Aplicabilidade (SoA) — ISO 27001:2022" com contadores por
  status e Ver / PDF / CSV.
- Verificado no lab: 93 controles → 2 cobertos, 12 não conformes, 8 não avaliados, 71 manuais;
  verif% 14, auto% 9; HTML bem-formado (0 tags soltas), sem refs externas. `ComplianceCatalogTests`
  (catálogo 93 únicos, transição, status por natureza, CSV, resumo). Total: 340 testes.
- Escopo v1: só ISO 27001. PCI-DSS (12 req.) e SOC 2 (CC) com catálogo completo ficam para depois.
- Próximo no plano: B3 (drift/monitoramento contínuo) ou B4 (baseline como código).

## 2026-07-21 — Aceitação vira subseção + FASE B3 (detecção de desvio/drift)

**UI — reorganização:** a gestão de aceitação de risco saiu da tela principal de Relatórios
e virou subseção própria na coluna do meio ("Relatórios › Aceitação de risco"), ao lado de
"Marca / dados da empresa". Nova `RiskAcceptanceView` com cabeçalho explicativo (banner azul)
reforçando a segregação de funções: **quem aceita o risco é o dono do produto/sistema, não o
auditor** — o auditor só registra; "Responsável" = quem aceitou, "Referência" = ticket/ata que
comprova. Tela principal de Relatórios ficou mais limpa.

**FASE B3 (v1 — detecção de desvio):**
- Core `DriftAnalysis` (puro): reusa `AuditCompare` e resume o desvio entre a coleta anterior e a
  atual do mesmo host em `DriftReport` — nível (Melhorou / Estável / Atenção / Crítico), delta de
  nota, novos achados severos, contagem de novos/resolvidos e razões em PT. Regras: novo achado
  alto/crítico ou queda de nota ≥15 = Crítico; queda ≥5 ou novo achado leve = Atenção; melhora de
  nota sem novos achados = Melhorou.
- `ExternalAuditService.previousAudit(for:)` acha a coleta anterior do mesmo host (chave
  machineID ?? hostname, por data de coleta).
- UI: banner de desvio no **Painel**, logo abaixo da nota — cor por nível, delta de nota, o que
  mudou e os novos achados severos; só aparece quando há ≥2 coletas do mesmo host.
- `DriftAnalysisTests` (novo severo = Crítico; novo leve = Atenção; correção = Melhorou; igual =
  Estável). Total: 344 testes.
- Falta v2: agendamento de coleta recorrente + notificação do macOS (precisa do atalho de coleta
  agendada). Registrado no plano.
- Próximo: B4 (baseline como código) ou D1 (frota/multi-host).

## 2026-07-21 — FASE B4 (baseline como código / policy-as-code)

**Decisão de escopo:** usuário optou por deixar o monitoramento automático (B3 v2) só no plano —
o uso dele é consultoria freelance sob demanda, não vigilância contínua de uma empresa fixa. Por
isso B4 (baseline portátil) é mais útil: o auditor carrega o MESMO padrão em cada cliente.

**O que foi feito:**
- Core `Baseline`/`BaselineItem` (Codable → JSON versionável) + `BaselineEngine`: `generate(from:)`
  captura todos os controles que o coletor avaliou (como obrigatórios); `assess` dá status a cada
  item — Conforme / Desvio / Não avaliado; `summary` com % de conformidade, contagem de desvios
  obrigatórios e veredito aprovado/reprovado; export CSV.
- **Correção importante:** o coletor emite ids diferentes para conforme e não-conforme que muitas
  vezes NÃO compartilham token (firewall-ok vs firewall-inactive, umask-strict-ok vs umask-loose,
  uid0-unique-ok vs uid0-multiple, updates-ok vs updates-pending, mac/auditd/fail2ban/rootkit/
  kernel-net/fw-default/auto-updates). Sem unificar, um baseline gerado numa máquina bem
  configurada NÃO casaria com uma máquina problemática (tudo viraria "não avaliado"). Criei
  `ComplianceMap.controlKey` com um alias canônico que unifica esses pares. Teste dedicado
  (`canonicalKeyUnifiesOkAndProblemVariants`) prova a propriedade.
- Relatório `AuditReport.baselineHTML`: veredito APROVADO/REPROVADO, % de conformidade, chips por
  status e tabela completa dos controles do baseline.
- App `BaselineStore` (UserDefaults + carregar/salvar arquivo JSON). Subseção nova
  "Relatórios › Baseline" (`BaselineView`): cabeçalho explicando o conceito; gerar baseline a
  partir da auditoria carregada / carregar arquivo / salvar arquivo / remover; card de
  conformidade da auditoria atual contra o baseline com Ver/PDF/CSV.
- Verificado no lab: baseline de 35 controles; contra a própria auditoria → 17 conforme / 18
  desvio / 0 não avaliado / 48%; HTML bem-formado, sem refs externas. `BaselineTests` (gerar,
  conforme/desvio, não avaliado, canônico ok↔problema, resumo reprova, round-trip Codable, relatório).
  Total: 351 testes.
- **FASE B (GRC) concluída:** B1 SoA, B2 aceitação de risco, B3 v1 drift, B4 baseline.
- Próximo sugerido: Fase D1 (frota / multi-host roll-up) ou C1 (enriquecimento de CVE).

## 2026-07-21 — Perfis de baseline recomendados (Rigoroso/Padrão/Básico)

**Contexto:** usuário perguntou se o programa gera o baseline automaticamente pelo "melhor padrão".
Não gerava — só transcrevia o que o coletor via. Ele então sugeriu ter arquivos de referência
("100%/70%/60%"); expliquei que baseline é ALVO, não nota — afrouxar regras pra fazer um "70%"
seria abaixar a régua. Reenquadrei para **níveis por risco/contexto** (como CIS Nível 1/2), e ele
aprovou os três perfis sugeridos.

**Implementado:**
- Core `BaselineProfile` (basico/padrao/rigoroso, com displayName e subtitle) + `BaselineEngine.
  curatedControls` (32 controles com CONFIRMAÇÃO POSITIVA no coletor — os que emitem "-ok"; deixei
  de fora os "problem-only" tipo ssh-maxauthtries/shadow-perms que dariam falso "não avaliado" em
  máquina boa) com título como exigência ("Firewall ativo", "SSH sem login de root"), nota e o
  perfil mínimo em que cada um vira obrigatório. `builtin(profile)` monta o baseline (mesmo
  catálogo nos três; muda só `mandatory`). Rigoroso ⊇ Padrão ⊇ Básico.
  Básico 8 obrig. / Padrão 21 / Rigoroso 32.
- UI: card "Perfis recomendados" em Relatórios › Baseline (sempre visível) com os três + botão
  "Usar" (1 clique define o baseline ativo) e contador de obrigatórios.
- Testes: aninhamento dos perfis; **toda chave curada é canônica** (`controlKey(k)==k`, garante que
  bate com os achados); perfil rigoroso reprova onde o básico aprova. Total: 354 testes.
- Próximo sugerido: C1 (enriquecimento de CVE) ou D1 (frota/multi-host).

## 2026-07-21 — FASE C1 (enriquecimento de CVE por versão)

**O que foi feito:**
- Coletor (v1.1.0): passa a colher versões de software-chave rodando só `--version` LOCAL
  (openssh via sshd/ssh -V, openssl, nginx, apache/httpd, sudo, bash) — leitura, SEM rede
  (mantém "coletor não exfiltra"). Emite campo `software` no JSON. Sed de extração validado
  contra saídas reais; bash -n ok.
- Schema: `ExternalAudit.SoftwarePackage` (name/version/source) + campo `software` opcional
  (init explícito com default nil → retrocompatível, não quebra construtores/fixture antiga).
- Core `CVE`/`CVEDatabase`: base CURADA e OFFLINE de ~10 CVEs de alto impacto (regreSSHion
  CVE-2024-6387, Heartbleed, OpenSSL punycode, Baron Samedit, sudoedit, Apache 41773/42013,
  nginx resolver 23017, Shellshock) com faixas de versão [introduzida, corrigida) e CVSS.
  `CVEMatcher`: comparador de versão tolerante (`9.6p1`→[9,6,1], `1.0.1f`→[1,0,1,6]); cruza
  host + imagens Docker; ordena por CVSS.
- Relatório `AuditReport.cveHTML` + card "Vulnerabilidades conhecidas (CVE)" em Relatórios
  (Ver/PDF/CSV).
- **HONESTIDADE (decisão de projeto):** distros aplicam BACKPORT da correção sem mudar a versão
  upstream → marquei tudo como "EXPOSIÇÃO POTENCIAL, confirme o patch da distro", NÃO injetei na
  nota/matriz (fica separado/informativo) e deixei explícito que é subconjunto curado, não NVD.
  Isso evita falso "vulnerável" e mantém a integridade da auditoria.
- Verificado: openssh 9.6p1 → regreSSHion; sudo 1.9.5p1 → Baron Samedit+sudoedit; nginx 1.18
  (Docker) → resolver; openssl 3.0.13 e bash 5.1.16 corretamente NÃO casam (pós-correção).
  HTML bem-formado, sem refs externas. `CVETests` (parser/compare/faixas/cruzamento/Docker/report).
  Total: 364 testes.
- Falta v2: base maior e atualizável (OSV/NVD feed), EPSS, versões de pacotes do host (dpkg/rpm).
- Próximo sugerido: D1 (frota/multi-host) ou C2 (Sigma/Falco).

## 2026-07-21 — Laboratório de teste (OrbStack: 4 distros × seguro/vulnerável)

**Limpeza:** apagadas as 8 VMs antigas do OrbStack (projetos finalizados + a própria
uptend-lab), ~15 GB liberados. Lab reconstruído do zero.

**Novo lab (8 VMs):** para cada família — Ubuntu 24.04, Debian 12 (apt) e Fedora 43,
Rocky 9 (dnf) — um par:
- `*-seguro`: endurecido (SSH sem root/senha, ufw/firewalld, fail2ban, auditd, sysctl,
  pwquality, TLS forte, sem NOPASSWD, shadow correto, updates).
- `*-vuln`: cheio de brechas (SSH root+senha+X11+empty, firewall off, MAC off, sysctl
  frouxo, UID 0 duplo, sudo NOPASSWD, shadow 644, porta extra, e — no apt — Docker com
  `nginx:1.18.0` vulnerável para o cruzamento de CVE).
Scripts de provisionamento duráveis em `lab/provision-apt.sh` / `lab/provision-dnf.sh`
+ `lab/README.md`. Os 8 cadastrados como hosts no app (`<nome>.orb.local`, chave dedicada
`~/.ssh/uptend_lab_ed25519`) → coleta 1 clique.

**Validação (coletor rodado nas 8):** contraste nítido —
Ubuntu vuln 27 / seguro 9 · Debian 21 / 9 · Fedora 25 / 10 · Rocky 26 / 11 (seguras sem
achado alto; ~8 achados ambientais inevitáveis pelo kernel compartilhado do OrbStack:
auditd/AppArmor/SELinux/partições/sudo-nopasswd).

**Bug de produto achado pelo lab → corrigido (coletor v1.1.1):** em Debian (e shells não
interativos) `/usr/sbin` não está no PATH, então nginx/sshd/ufw ficavam invisíveis. Adicionado
`export PATH=/usr/local/sbin:/usr/sbin:/sbin:$PATH` no topo do coletor. Depois disso, nginx
passou a ser detectado em todas as distros. bash -n ok, 364 testes ok, app recompilado.

## 2026-07-21 — Verificação do lab: cobertura das vulneráveis + 3 bugs de coletor

Pedido: revisar se as VMs vulneráveis exercitam TUDO que o coletor captura e se as
seguras estão realmente limpas. Feito cruzamento do catálogo completo (44 tipos de
achado) contra cada VM.

**Cobertura das vulneráveis: 27→33/40 conceitos** (após reforço). Adicionadas brechas
que faltavam: senha vazia (`empty-passwords`), `/etc/passwd` gravável (`etc-passwd-perms`
+ `sensitive-file-perms`), hash MD5 (`pass-hash`), reinício pendente (`reboot-required`),
e `pam-lockout` passou a disparar após o fix do coletor. **7 lacunas restantes são
estruturais:** 3 de kernel (aslr/info-leak/suid — teto do OrbStack, kernel compartilhado)
e 4 de condição especial (os-eol precisa distro EOL; disk-space precisa disco cheio;
time-sync precisa relógio dessincronizado; fw-default precisa firewall-ligado-mas-liberado).

**Seguras: 8 achados cada, TODOS ambientais do OrbStack, ZERO residual real de hardening.**
Após corrigir os últimos pendentes (minlen 14 no Ubuntu, fail2ban backend systemd no Debian,
drop-in SSH `00-lab.conf` p/ vencer o `50-redhat.conf` no RHEL, journald persistente no Rocky,
faillock real em todas). Os 8 restantes (auditd, SELinux/AppArmor, kernel-net, /tmp-/var-/home
sem partição, sudo-nopasswd do OrbStack, porta 80 do nginx) não são corrigíveis em VM leve.

**3 bugs de produto achados pelo lab → corrigidos (coletor v1.1.3):**
1. PATH sem `/usr/sbin` (v1.1.1) — nginx/sshd/ufw invisíveis em Debian.
2. `pam-lockout` (v1.1.2): considerava lockout ativo só pela existência de
   `/etc/security/faillock.conf` (falso negativo); agora exige `pam_faillock` referenciado
   no PAM, com `grep -R` (segue symlink — RHEL usa system-auth via authselect).
3. `auto-updates` (v1.1.3): só reconhecia `unattended-upgrades` (apt); agora também
   `dnf-automatic.timer` (RHEL). Antes dava falso positivo em Fedora/Rocky.

Scripts `lab/provision-apt.sh` e `lab/provision-dnf.sh` atualizados com todas as brechas/fixes
(reproduzíveis). 364 testes ok, app recompilado (coletor v1.1.3).

## 2026-07-21 — VM EOL + fw-default: cobertura 35/40; bug da tabela EOL

Criada 9ª VM `eol-fedora` (Fedora 42, fora de suporte) para exercitar o achado `os-eol`
(crítico) — nenhuma das 8 anteriores conseguia (todas em versões suportadas). Provisionada
como vulnerável = "pior servidor" (SO EOL + todas as brechas; 35 achados, 2 críticos).

**Bug de produto (coletor v1.1.4):** o check `os-eol` usa uma tabela de datas hardcoded que
estava desatualizada (parava em fedora 41 / ubuntu 24.04), então versões JÁ EOL como Fedora 42
não eram detectadas. Atualizada a tabela (fedora 42/43/44, ubuntu 26.04, debian 13, rocky 10,
oracle 8/9/10). Limitação estrutural do método: tabela envelhece (ideal futuro = feed
endoflife.date, mas exige rede — descartado no coletor).

`fw-default` coberto ligando ufw com default-allow na `debian-vuln` (o check só entende ufw,
não firewalld — outra limitação anotada).

**Cobertura final das vulneráveis: 35/40.** As 5 lacunas restantes são IMPOSSÍVEIS no OrbStack,
não descuido: kernel-aslr/info-leak/suid (kernel compartilhado), disk-space (disco esparso 555G),
time-sync (relógio sincronizado pelo hipervisor). Todas seriam trigáveis num servidor real.

`eol-fedora` cadastrada como 9º host no app. 364 testes ok, app recompilado (coletor v1.1.4).

## 2026-07-22 — FASE D1 (Frota / multi-host roll-up)

Retomado o plano (após o lab). Implementado o roll-up de frota:
- Core `FleetRollup`: `latestPerHost` (última auditoria de cada host por machineID/hostname),
  `rollup` → `Fleet` com hosts ordenados do pior ao melhor, nota média, distribuição por
  semáforo (vermelho/amarelo/verde), heatmap host × área (reusa `AuditDomains`) e os achados
  mais comuns na frota (por chave-base canônica, contando hosts). Export CSV.
- `AuditReport.fleetHTML`: relatório consolidado (panorama + heatmap + tabela de hosts do mais
  fraco ao mais forte + achados mais comuns).
- UI: nova seção "Frota" na aba Auditoria (`FleetView`) — cards de resumo (nota média +
  distribuição), heatmap host×área colorido, lista de hosts clicável (abre o painel do host),
  top achados, botões Ver/PDF/CSV, e **coleta em lote** (roda o coletor em todos os hosts
  cadastrados de uma vez).
- Validado com os 9 hosts reais do lab: nota média 32, 5 vermelhos / 4 amarelos, piores = as
  máquinas vulneráveis (nota 0); HTML bem-formado, sem refs externas. `FleetRollupTests`
  (dedup por data, ordenação, contagem de hosts por achado, CSV, relatório). Total: 369 testes.
- Próximo sugerido: D3 (mapa de superfície de ataque) ou C2 (Sigma/Falco).

## 2026-07-22 — UX: seletor de servidor + dashboard BI repaginado + relatórios mais largos

- **Bug corrigido:** legenda da matriz de risco no relatório Executivo aparecia grudada
  ("BaixoMédioAltoCrítico" sem quadradinhos) — o executivo usa um template próprio (`execPage`)
  que não tinha o CSS `.rlegend`/`.rsw`/`.rn`. Copiado. Também alarguei todos os relatórios
  (820/900 → 1080px) e a janela de preview (720 → ~1120px).
- **Seletor de servidor (menu em cascata):** novo componente `AuditHostPicker` (troca
  `service.selectedID`). No **Painel**, removidos os botões "Relatórios" e "Importar outra" e
  colocado o seletor (escolhe qualquer host do histórico). Mesmo seletor no cabeçalho de
  **Relatórios** (escolhe de qual servidor gerar os relatórios). Lista host · data, agrupado.
- **Dashboard BI (offline) repaginado:** `AuditDashboard.html` ganhou anel de nota (gauge SVG),
  donut de severidade, KPIs em tiles coloridos, cards com sombra, layout em 2 colunas e mini-barras
  na tabela de servidores. JS validado (node --check + execução headless das funções de render).
- 369 testes, app recompilado.

## 2026-07-22 — Bug: varredura ativa mesclava no host errado (corrigido)

Usuário notou: escaneou `ubuntu-vuln.orb.local` mas o botão dizia "Adicionar à auditoria
(debian-seguro)". Causa: `mergeScanFindings` usava `service.selected` (auditoria globalmente
selecionada), desacoplado do host escaneado — jogaria os achados de TLS no servidor errado.
Correção: `mergeScanFindings(_:into:)` agora recebe a auditoria-alvo explícita; a view acha a
auditoria (mais recente) que corresponde ao HOST ESCANEADO (casa por hostname / primeiro rótulo
DNS / nome de host cadastrado como ponte p/ IP). Botão mostra o host certo e fica desabilitado
com aviso se não houver auditoria daquele host. Teste `TLSScannerFindingsTests` atualizado. 369 testes.

## 2026-07-22 — UX: Importar/Coletar em 2 subseções + varredura ativa integrada à coleta

- **"Importar / Coletar"** virou 2 subseções na coluna do meio: **"Importar / Coletor"**
  (importar .json + gerar coletor pro cliente, com card de intro e instruções voltadas a instruir
  o cliente) e **"Coletar de servidor"** (SSH).
- **Coletar de servidor:** lista de hosts trocada por **menu em cascata** ("Coletar de um host…").
- **Varredura ativa integrada:** a seção separada "Varredura ativa" foi REMOVIDA e virou opção
  dentro de "Opções da coleta": abaixo do Lynis, um tique "Tenho autorização para varredura ativa"
  e outro "Rodar varredura ativa de TLS junto" — este só habilita se a autorização estiver marcada.
  Ao coletar, roda o coletor e (se marcado) a sondagem TLS no mesmo host, mesclando os achados na
  auditoria dele (`mergeScanFindings(into:)`). Campo de portas aparece quando ativado.
- Removida a struct `AuditPentestView` (função migrou pra coleta); smoke test atualizado. 369 testes.

## 2026-07-22 — Dashboard BI: modo apresentação interativo (reunião/TV)

Objetivo do usuário: usar o dashboard offline como apoio de reunião (TV, tela cheia), com
elementos clicáveis e explicações.
- Dados enriquecidos: cada auditoria agora leva os achados abertos com `rec` (recomendação) e
  `impact` (impacto de negócio) — `AuditDashboard.html`.
- Interatividade (delegação de clique, sobrevive a re-render): **riscos clicáveis** expandem
  "O que fazer" + "Impacto no negócio"; **categorias clicáveis** fazem drill-down dos achados
  daquela área.
- **Modo apresentação** (botão) aumenta fontes/espaços p/ TV; **Tela cheia** (requestFullscreen).
- JS validado (node --check + execução headless de hero/donut/cats/risks). 369 testes.
- Obs.: fullscreen pleno funciona melhor via "Abrir no navegador"; o modo apresentação (CSS)
  funciona no preview embutido também.

## 2026-07-22 — FASE E4 v1 (Auditoria de Banco de Dados + LGPD, modo estrutura)

Arquitetura decidida com o usuário: DENTRO de Auditoria Externa (BD = domínio "Banco de dados"
na mesma auditoria; sem aba separada, sem renomear). Modo Estrutura (LGPD-safe) — nunca lê dado.

- Core: `DatabaseSchema` (tabelas/colunas/tipos/chaves/índices, Codable) + `DatabaseAudit`
  (achados por NOME+TIPO da coluna, sem ler dado: senha/PII forte em texto plano = alto, PII comum
  = médio, sem PK / FK-sem-índice = baixo; `makeAudit` vira alvo de auditoria) + domínio
  "Banco de dados" no `AuditDomains`.
- Origem 1 — **arquivo SQLite anexado**: `SQLiteSchemaReader` (só `sqlite_master`+`pragma_*`,
  read-only, nunca SELECT em dado) + subseção "Banco de dados" em Importar/Coletar (anexar/arrastar
  → achados → Adicionar à auditoria como alvo próprio).
- Origem 2 — **Postgres no servidor**: coletor v1.1.5 com `UPTEND_DB_AUDIT=1` extrai schema via
  `sudo -u postgres psql` (só `information_schema`; o próprio Postgres monta o JSON) → campo
  `databases` (`ExternalAudit.databases`); `enrichedWithDatabaseFindings()` deriva os achados na
  ingestão e re-serializa; tique "Auditar bancos" nas Opções da coleta.
- Verificado no lab: SQLite com PII (5 achados corretos) e Postgres instalado na ubuntu-vuln com
  banco `loja` (senha/cpf/email/logs → 4 achados), TUDO só lendo schema (nunca os dados inseridos).
  `DatabaseAuditTests`. Total: 378 testes.
- Falta v2: MySQL, modo Completo (amostragem em memória p/ confirmar hash vs texto plano, PII real),
  lente/relatório LGPD dedicado, charset/engine legado.

## 2026-07-22 — Bancos fictícios em todas as VMs (teste de auditoria de BD)

Melhoria no auditor: check de PII "média" agora respeita indício de cifra no nome (`email_encrypted`
não dispara). Populadas as 9 VMs com Postgres: `*-vuln`+eol com `loja_insegura` (PII em texto plano,
senha sem hash, tabelas sem PK → ~21 achados, 8 altos); `*-seguro` com `loja_segura` (PII em bytea,
senha_hash, PKs, FK indexada → 0 achados). Setup reproduzível em `lab/setup-db.sh` +
`lab/db-insecure.sql` / `lab/db-secure.sql`. Verificado via coletor (só schema, nunca dados). 378 testes.

## 2026-07-22 — Credenciais de serviço (banco) no cadastro do host

Pedido do usuário: no cenário real, o banco pode exigir senha. Solução: credencial de banco
JUNTO do cadastro do servidor, reutilizada em todo o programa.
- `RemoteHost.db: DBCredential?` (kind/user/host/port/database — SÓ metadados, retrocompatível).
  Senha no **Keychain** via `DBCredentialStore` (nunca em UserDefaults/arquivo/log).
- `AddHostSheet` ganhou seção "Banco de dados (opcional)" (DisclosureGroup): usuário + senha
  (SecureField) + host/porta/banco. Recomenda usuário read-only.
- Coletor v1.1.6: caminho de auth por SENHA (env `UPTEND_PG_USER/PASSWORD/HOST/PORT/DB`, psql via
  `PGPASSWORD`+`-h -U`) além do peer auth. `runCollector` passa as credenciais (senha do Keychain)
  por env sobre o SSH criptografado quando "Auditar bancos" está ligado e o host tem credencial.
- Verificado no lab: usuário read-only `auditor` com senha auditou `loja_insegura` via `-h localhost`
  (md5), só schema. 378 testes.
- Segurança: senha só no Keychain, transmitida por env sobre SSH (não em disco/JSON/log), auditoria
  read-only/estrutura, recomenda-se usuário read-only dedicado.

## 2026-07-22 — "Fazer tudo": bastion + lente LGPD + MySQL + modo completo

Quatro entregas de uma vez (verificadas):
1. **Bastion / jump host:** `RemoteHost.jumpHost` (ProxyJump); SSH usa `-J` quando preenchido;
   campo no cadastro (disclosure "Conexão avançada"). Resolve servidor em rede privada via ponte.
2. **Lente LGPD:** Core `LGPDLens` mapeia os achados (sistema + banco) às obrigações de SEGURANÇA
   da LGPD (art. 46 / 6º-VII / 37) — não é silo, atravessa tudo; ignora o que não é LGPD (disco).
   `AuditReport.lgpdHTML` (por artigo, com ressalva "não é parecer jurídico") + card em Relatórios.
3. **MySQL/MariaDB no coletor (v1.1.6):** extração de schema via `information_schema` (JSON montado
   pelo MySQL), peer auth (`sudo mysql`) ou senha (`UPTEND_MY_*`). Engine picker (Postgres/MySQL)
   no cadastro do host; `runCollector` passa `UPTEND_MY_*` quando kind=mysql. Verificado na
   debian-vuln (auditou Postgres E MySQL na mesma coleta).
4. **Modo completo (SQLite anexado):** `SQLiteSchemaReader.samplePasswordColumns` amostra em memória
   SÓ as colunas de senha (nunca armazena); `DatabaseAudit.valuesLookHashed` + `findings(passwordSamples:)`
   confirmam hash vs texto plano (limpa falso positivo ou confirma "texto plano CONFIRMADO"). Toggle
   "Modo completo" na subseção Banco de dados.
- Segurança: bastion usa a mesma chave; senha de BD no Keychain, por env sobre SSH; modo completo lê
  só colunas de senha, em memória, opt-in. `LGPDLensTests` + `DatabaseCompleteModeTests`. 382 testes.

## 2026-07-22 — FASE C2 (regras de detecção Sigma/Falco compensatórias)

Core `DetectionRules`: para cada LACUNA aberta, gera uma regra de detecção compensatória
("não corrigiu? então detecte"): força-bruta SSH (fail2ban/senha ausentes → Sigma T1110),
login root SSH (T1078.003), leitura de /etc/shadow (auditd ausente → Falco T1003.008), sudo
NOPASSWD (Falco T1548.003), novo listener (firewall/portas → Sigma T1571), binário em área
gravável (sem rootkit-tool → Falco T1059). `bundle()` agrupa Sigma/Falco. `AuditReport.
detectionRulesHTML` (regras em <pre> + MITRE + "não substitui a correção"). Card em Relatórios
(Visualizar + Salvar .yml + Copiar). `DetectionRulesTests`. 387 testes.

## 2026-07-22 — FASE D2 (playbook de hardening com backup/rollback)

Core `HardeningPlaybook.generate(for:)`: gera um SCRIPT BASH revisável a partir dos achados
abertos (via `RemediationMap`, dedup por controle). Correções AUTO-aplicáveis (comando de shell
direto, sem placeholder `<...>` nem `visudo`) entram no script; as demais viram notas MANUAIS
comentadas. Estrutura: backup dos configs de segurança (`/var/backups/uptend-hardening`, preserva
o original), aplica as correções, `reload_all`, e modo `rollback` (restaura o backup). Cabeçalho
com avisos (revisar, janela de manutenção, acesso alternativo — hardening de SSH pode derrubar a
sessão). `AuditReport.playbookHTML` (aviso + como usar + script em <pre>) + card em Relatórios
(Visualizar + Salvar .sh + Copiar). **NUNCA executado pelo app** — só gerado p/ revisão.
Verificado: playbook da ubuntu-vuln = 21 correções automáticas, `bash -n` VÁLIDO. `HardeningPlaybookTests`.
391 testes.

## 2026-07-22 — Playbook (e relatórios) conscientes da distro (apt × dnf)

Os comandos de correção passaram a se adaptar ao SO auditado. `OSFamily.from(distro)` (apt=
Debian/Ubuntu/Kali; dnf=Fedora/Rocky/Alma/RHEL/CentOS/Oracle). `RemediationMap.familyTable`:
comandos específicos por família (firewall ufw×firewalld, pacote apt-get×dnf, MAC AppArmor×SELinux,
auto-update unattended-upgrades×dnf-automatic, upgrade). `remediation(for:family:)` (default apt,
retrocompatível). `HardeningPlaybook` usa a família da distro do host + mostra o SO no cabeçalho;
relatório técnico e Markdown (plano de remediação) também. Verificado nas auditorias reais:
ubuntu→apt, rocky/fedora→firewalld+dnf+SELinux. `HardeningPlaybookTests` (distroAware). 393 testes.

## 2026-07-22 — D3: Mapa de superfície de ataque (fecha a Fase D)

Novo relatório "Superfície de ataque": deriva das portas expostas já colhidas (parse do achado
`exposed-ports`) + status TLS + contêineres Docker um diagrama SVG autocontido (banda Rede →
chips de porta coloridos por risco → servidor) mais tabela e legenda. `AttackSurfaceMap` (Core,
puro): mapa porta→serviço; risco por porta (dados/admin públicos = alto; SSH/HTTP = médio;
HTTPS com TLS = ok, rebaixado a médio se TLS fraco); SSH sempre presente. Card em Relatórios
(`surfaceCard`). Tests `AttackSurfaceTests` (5432→alto, SSH sempre, TLS fraco rebaixa 443,
SVG/HTML autocontidos). Verificado real: ubuntu-vuln 22/80/8080/8081, rocky-vuln 22/80/8081.
397 testes. Fase D (D1 frota, D2 playbook, D3 superfície) concluída.

## 2026-07-22 — Auditoria completa de ponta a ponta (pente-fino + correções)

Revisão de todo o código (Core + App + coletor) por 7 revisores paralelos + varredura própria,
medida contra PADROES.md. 17 defeitos reais corrigidos, cada um com teste de regressão; base
subiu de 397 → **423 testes, 0 warnings**. Nenhuma injeção de comando SSH (Process+argv +
shellQuote) nem crash/force-unwrap nas áreas grandes — a base já era disciplinada.

**Altos (4):**
- **machine_id nunca decodificava**: `machineID` + `.convertFromSnakeCase` (→ `machineId`) não
  casavam → identificador de host sempre nil (hosts homônimos se fundiam na frota; exceções de
  risco vazavam/perdiam-se). Renomeado `machineID`→`machineId` em todo o projeto.
- **Senha do BD no argv remoto** (visível em `ps`/`/proc/cmdline`): extraído `collectorInvocation`
  (puro/testável); a senha agora vai por **stdin** (`read` no prelúdio → export), nunca no comando.
- **XSS**: campo `cis` (vindo do JSON do coletor) interpolado sem `esc()` na tabela de mapeamento
  (relatórios Técnico + SOC). Escapado.
- **Leak de memória**: `ReportWindow.open` vazava NSWindow+WKWebView a cada relatório em janela
  (observer retinha o bloco). Corrigido com token guardado + `removeObserver` no fechamento.

**Médios (9):** injeção SQL no coletor MySQL (agora `DATABASE()` + `myqd -D`, nome do banco só
como argumento de conexão; loops linha-a-linha; `isValidDatabaseName`; coletor v1.1.7 verificado
no lab) · `AuditCompare` passou a usar `controlKey` (drift "Crítico" espúrio quando só o motivo
mudava) · **nota unificada**: painel/cartões/histórico/frota/BI passam a descontar riscos aceitos
(via `RiskExceptionStore.effectiveScore`), igual aos relatórios · Keychain: **NÃO** migrado para
data-protection (provado empiricamente que quebra num app ad-hoc/sem entitlements — mantido login
keychain, documentado; upgrade fica para a assinatura de distribuição) · `DatabaseAuditView` não
relê mais o SQLite a cada render (materializado em @State) · `AddHostSheet` com ScrollView +
rodapé de botões fixo · clique na frota abre a coleta certa (por `collectedAt`, igual ao rollup) ·
22 métodos async de View anotados `@MainActor` (mutação de @State fora da main) · fingerprint SSH:
mantido `accept-new` (TOFU), documentado.

**Baixos (12):** `RiskException.isActive` respeita `acceptedAt` e normaliza datas · `HostStore.remove`
limpa a senha órfã no Keychain · `AuditSigner` cacheia a chave (não diverge se o Keychain falhar) ·
`comparisonHTML` aceita assinatura · `esc()` também escapa `'` · `markdown()` escapa `|` em células ·
`jumpHost` validado (`isValidJumpHost`) · `scp` aspa o caminho remoto (arquivo com espaço) ·
`LatencyMonitor` valida o host · `CleanupService` reporta falhas da Lixeira · corrida do `cancelScan`
do ClamAV fechada · `ForEach id:\.self` sobre listas com possíveis duplicatas → índice.

**Testes novos:** CryptoTools, Keychain (round-trip), AuditSigner (chave trocada/base64 malformado/
estabilidade), UptendVault (injeção-como-literal/blob binário), validadores (database/jumpHost),
RemoteHost (limpeza de credencial), + regressões dos altos/médios.
