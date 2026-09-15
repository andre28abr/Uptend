# Brainstorm — Uptend

> Arquivo vivo de ideias. Aqui juntamos funcionalidades, usos, princípios e vamos atualizando conforme as ideias surgem. Nada aqui é decisão final — é o espaço de pensar livre. Decisões fechadas ficam em `DECISOES.md`.

**Última atualização:** 2026-07-07

---

## Visão geral (o que é o projeto)

**Uptend** — app estilo DMG para Mac, pessoal, para ser instalado toda vez que o Mac for reiniciado/formatado. Serve como central única para:

1. Instalar as coisas essenciais que eu uso (Homebrew, apps, ferramentas).
2. Quando não der pra instalar via script, lembrar de instalar manualmente (com link).
3. Atualizar tudo do Homebrew e apps num só lugar, sem ficar rodando comando.
4. Sincronizar pastas Git (pull/push/status) e mostrar o que está ou não sincronizado.
5. Limpeza básica estilo CleanMyMac (mais simples): lixeira, caches, etc.
6. Desinstalar programas de forma fácil.

---

## Princípios de design (definidos)

- Interface bonita, amigável, **estilo Mac nativo**.
- Layout baseado em **listas**.
- **Sem muitas animações** — foco em ser rápido e direto.
- **Não usar emojis** em lugar nenhum (nem na UI, nem nesta documentação).
- Ícones sempre no **estilo flat**.
- Suporte a **tema escuro e tema claro**.
- Ícones **pequenos, somente o ícone** (sem rótulo fixo ao lado).
  - Ao passar o mouse (**tooltip no hover**): mostrar uma breve explicação do que o ícone faz.
  - Se o ícone for **totalmente intuitivo** (ex.: engrenagem = Configurações), o tooltip mostra apenas o **nome** (ex.: "Configurações").

---

## Funcionalidades — Fase 1 (núcleo)

### Instalação de essenciais
- [ ] Instalar por categorias: Desenvolvimento, Segurança, Design, Produtividade, Utilidades…
- [ ] Seleção múltipla + "Instalar tudo" da categoria
- [ ] Para apps que não dá pra instalar via script (ex.: Xcode, App Store): mostrar como lembrete com link direto
- [ ] Indicador de estado por item: instalado / não instalado / desatualizado

### Central de atualizações
- [ ] Botão único: `brew update` + `brew upgrade` + `brew cleanup`
- [ ] Listar o que tem update pendente antes de aplicar
- [ ] Atualizar apps casks (GUI) junto com fórmulas

### Sincronização Git
- [ ] Selecionar/adicionar pastas que são repositórios Git
- [ ] Mostrar status: sincronizado / atrás / à frente / com alterações locais
- [ ] Ações rápidas: pull, push, fetch
- [ ] Visão consolidada de todos os repositórios monitorados

### Limpeza básica (estilo CleanMyMac, simplificado)
- [ ] Esvaziar Lixeira
- [ ] Limpar caches de usuário (`~/Library/Caches`)
- [ ] Limpar logs antigos
- [ ] Limpar downloads antigos / arquivos temporários
- [ ] `brew cleanup` (versões antigas de fórmulas)
- [ ] Mostrar quanto espaço será/foi liberado
- [ ] Sempre pedir confirmação antes de apagar

### Desinstalador de programas
- [ ] Listar apps instalados (via brew cask e `/Applications`)
- [ ] Desinstalar com um clique
- [ ] Remover também arquivos residuais (configs, caches do app)
- [ ] Diferenciar o que foi instalado via Homebrew do que foi manual

### Dashboard / Status geral
- [ ] Visão inicial: quantos apps instalados, updates pendentes, repos dessincronizados, espaço em disco
- [ ] Health check (`brew doctor`, FileVault ligado?, etc.)

---

## Funcionalidades — Fase 2 (próximo momento, já confirmadas)

- [ ] **Profiles / Brewfile** — salvar a seleção de apps como perfil exportável. Numa próxima formatação, carregar o perfil e instalar tudo de uma vez (basicamente um `Brewfile` com UI bonita).
- [ ] **Dotfiles & configs** — restaurar `.zshrc`, `.gitconfig`, chaves SSH, configs do VS Code a partir de um repo/backup.
- [ ] **Segurança** — checar/ligar FileVault, firewall, atualizações do sistema.
- [ ] **Log / histórico de ações** — o que foi instalado/removido/limpo e quando.
- [ ] **Modo "primeira vez"** — um wizard passo a passo pós-formatação.
- [ ] **Busca** — campo pra achar rápido um app na lista.
- [ ] **Agendamento** — lembrar de rodar limpeza/updates a cada X dias.

---

## Ideias a explorar — modo Canivete Suíço (candidatas)

> Uso pessoal, tudo-em-um. Candidatas ainda não confirmadas. "(top)" = mais úteis no dia a dia, prioritárias caso a gente promova. Escolher quais viram Fase 2/3.

### Sistema e manutenção
- [ ] Itens de inicialização — ver/desativar login items e launch agents (top)
- [ ] Monitor rápido — CPU/RAM/disco + matar processo pesado (top)
- [ ] Analisador de espaço — o que ocupa o disco (estilo DaisyDisk simplificado)
- [ ] Toggles do sistema — arquivos ocultos, extensões, flush DNS, reindexar Spotlight, caminho no Finder (top)
- [ ] Limpezas de dev — Xcode DerivedData, node_modules órfãos, cache npm/pip/brew, Docker parado

### Desenvolvimento
- [ ] Portas em uso — listar quem usa a porta X e matar (top)
- [ ] Gerador de chave SSH — criar e copiar a pública pro clipboard
- [ ] Versões de runtime — trocar Node/Python/Ruby (nvm/pyenv) pela UI
- [ ] Docker — painel gráfico que pilota o Docker instalado: listar containers (ativos/parados), imagens, volumes e redes; iniciar/parar/remover, ver logs; se não houver Docker, oferecer instalar via Homebrew
- [ ] Repos favoritos — clonar a lista de projetos de uma vez (combina com Profiles)

### Segurança
- [ ] Painel de segurança — FileVault, Firewall, Gatekeeper, SIP num só lugar (top; expande a Fase 2)
- [ ] Gerador de senhas
- [ ] Ferramentas de hash — md5/sha e verificação de integridade de downloads
- [ ] Conexões de rede ativas

### Utilidades (coração do canivete)
- [ ] Caixa de conversores — JSON formatter, Base64, timestamp/data, hex/rgb, unidades (top)
- [ ] Histórico de clipboard
- [ ] Converter/redimensionar imagens (arrastar e soltar)
- [ ] Gerador de QR code

### Rede e info
- [ ] IP local/público, ping, velocidade
- [ ] Sobre este Mac turbinado — specs, uptime, ciclos de bateria, temperatura

### Nota de arquitetura
- Manter o núcleo (Fase 1) enxuto e tratar cada item acima como uma **ferramenta independente** na barra lateral. No SwiftUI, cada ferramenta vira uma tela própria, fácil de agregar aos poucos.

---

## Nome — DEFINIDO: Uptend

Escolhido em 2026-07-08. *up* (uptime/upkeep/up-to-date) + *tend* (cuidar/manter) = "manter o Mac em dia". Ver `DECISOES.md` [D009].

Histórico: o nome inicial era **MacForge** (D001), mas foi trocado porque já existe um app conhecido com esse nome (framework de plugins para macOS). Após busca ampla, quase toda palavra comum estava ocupada no espaço de software; "Uptend" (inventado) é único, fácil de falar/escrever e registrável.
Outros descartados: MacForge, Fettlekit, Macsmith, Kilnix, Habile.

---

## Stack — DEFINIDA: SwiftUI nativo

Escolhida em 2026-07-07. Ver `DECISOES.md` [D002].
Candidatos descartados: Tauri, Electron.

---

## Notas soltas

- Muitas ações exigem permissões/privilégios — pensar em UX de confirmação e senha (sudo).
- Segurança: como o app roda comandos de shell, tomar cuidado com o que é executado.

---

## HomeLab (módulo futuro) — ver HOMELAB.md

Ideia grande: usar o Uptend para gerenciar um HomeLab (servidor Linux) além do Mac —
conexão via SSH, painel administrativo nativo. Navegação por **abas** de host (Este Mac +
HomeLab, estilo abas do Terminal). Reaproveita o executor de comandos abstraído para rodar
Docker/Git/serviços/discos remoto. Detalhes completos, segurança, roteiro em fases e
discussão de SO em `HOMELAB.md`. Status: em design, sem código.

---

## Auditoria Externa (arma futura) — ver AUDITORIA-EXTERNA.md

Coletor de auditoria portátil (roda em qualquer servidor: remoto/local/pen drive),
read-only + sem rede + transparente, gera JSON estruturado que o Uptend importa (arrastar
arquivo) e vira painel de auditoria + relatórios: Markdown (cru/IA), HTML com gráficos e
PDF (stakeholders/leigos), e dataset+template Power BI (apresentação). Foco em valor de
negócio, priorização, conformidade CIS e hardware em fim de vida. Não é malware se
read-only/sem exfiltração/com consentimento — mas será logado por SIEM/EDR (coordenar, não
esconder). Plano completo em AUDITORIA-EXTERNA.md. Status: design, sem código.
