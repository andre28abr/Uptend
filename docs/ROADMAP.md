# Roadmap — Uptend

> O que falta fazer, organizado por etapas. Documento **vivo**: marcar `[x]` conforme concluir e adicionar novas ideias (as ideias soltas ficam no `BRAINSTORM.md`; quando viram plano, entram aqui). Cada item deve respeitar o `PADROES.md` (testes + segurança + privacidade + Definition of Done).

**Última atualização:** 2026-07-08

---

## Estado atual (o que já funciona de verdade)

- [x] Homebrew — buscar, instalar, essenciais, instalados, atualizações, manutenção
- [x] Aplicativos — listar `/Applications` e desinstalar (Lixeira + residuais)
- [x] Sistema — informações, itens de inicialização, ajustes rápidos
- [x] Base: layout 3 colunas, tema claro/escuro, log ao vivo, testes (14), validação de entrada

**Ainda em mock (não fazem nada real):** Limpeza, Git, Docker, Segurança, Ferramentas.

---

## Etapa 3 — Ligar as categorias reais (maior parte do valor) ✅ CONCLUÍDA (2026-07-08)

Ordem seguida: Git → Limpeza → Segurança → Docker → Ferramentas. Todas ligadas à lógica real.

### Git ✅ (concluído 2026-07-08)
- [x] Adicionar/remover pastas monitoradas (com persistência via UserDefaults)
- [x] Detectar se a pasta é repositório; ler `git status`, branch, à frente/atrás
- [x] Ações reais: fetch, pull, push
- [x] Visão consolidada + filtros (todos / com alterações / dessincronizados)
- [ ] (futuro) Log detalhado de pull/push numa folha, como no Homebrew
- [ ] (futuro) Bookmarks com escopo de segurança (se um dia o app virar sandbox)

### Limpeza ✅ (concluído 2026-07-08)
- [x] Calcular tamanhos reais (lixeira, caches, logs, downloads antigos, dev)
- [x] Esvaziar lixeira; limpar caches/logs (mover para Lixeira quando possível = reversível)
- [x] Limpezas de dev: Xcode DerivedData, cache npm, CocoaPods, `brew cleanup`
- [x] Confirmações e total de espaço liberado; aviso de reversibilidade
- [ ] (futuro) node_modules órfãos (buscar em pastas de projeto), cache pip, imagens Docker paradas

### Segurança ✅ (concluído 2026-07-08)
- [x] Status real: FileVault (`fdesetup status`), Firewall (`socketfilterfw`), Gatekeeper (`spctl`), SIP (`csrutil status`)
- [x] Atualizações do sistema pendentes (`softwareupdate -l`, sob demanda)
- [x] Ferramentas: gerador de senhas (local) e hash SHA-256 de arquivos (CryptoKit)
- [ ] (futuro) Ações para corrigir (ligar firewall etc.) via autenticação nativa
- [ ] (futuro) Conexões de rede ativas

### Docker ✅ (concluído 2026-07-08)
- [x] Detectar Docker (OrbStack/Docker Desktop); 3 estados: ausente / parado / rodando
- [x] Se ausente, instalar via Homebrew; se parado, botão para abrir o app
- [x] Listar containers/imagens/volumes/redes reais (parse do JSON do docker)
- [x] Iniciar/parar/remover containers, remover imagens/volumes, ver logs

### Ferramentas (canivete) ✅ (concluído 2026-07-08)
- [x] Conversores (JSON, Base64, hex/rgb, timestamp)
- [x] Gerador de senhas (na aba e reaproveitado da Segurança)
- [x] Hash de arquivos (SHA-256)
- [x] Gerador de QR Code (CoreImage, local)
- [x] IP local/público, ping
- [x] Histórico de clipboard (em memória, enquanto o app está aberto)
- [x] Gerar chave SSH (ed25519) e copiar pública
- [x] Portas em uso (ver e encerrar processo)

---

## Etapa 4 — Completar o núcleo e o UX

- [x] **Categoria Rede** (separada das Ferramentas): velocidade ao vivo (mini-gráficos), IP local/público, ping, DNS
- [x] **Ícone na barra de menu** com mini dashboard (CPU, memória, rede + mini-gráficos) e acesso rápido
- [x] **Rede expandida**: Wi-Fi ao vivo (sinal/canal/banda/taxa), Qualidade (latência/perda/jitter com gráfico), Visão geral turbinada (Swift Charts + totais da sessão), Endereços+ (gateway/DNS/MAC/ISP), Conexões ativas, Teste de velocidade
- [x] SSID via permissão de Localização (LocationService + botão "Mostrar nome" no Wi-Fi)
- [ ] (futuro Rede) uso de rede por app
- [ ] (futuro barra de menu) opção de "minimizar só para a barra" (ocultar do Dock)
- [ ] Persistência (UserDefaults): repos Git, preferências, perfil de essenciais
- [ ] Dashboard 100% real (contagem de repos, health checks reais)
- [ ] Autenticação de admin (sudo via prompt nativo do macOS) para ações que exigem
- [x] Auto-scroll do log ao vivo; toasts de sucesso/erro; aviso de manutenção vencida no Início
- [x] Tradução completa para PT-BR (rótulos + menus do sistema via Info.plist pt-BR)
- [x] Ícone do app e identidade visual (seta de up-trend em squircle azul→teal; `make-icon.swift` gera o .icns, embutido pelo build-app.sh)
- [ ] Refinar estados vazios/carregando e mensagens de erro
- [ ] Itens de inicialização com API moderna (SMAppService) além do System Events

---

## Etapa 5 — Funcionalidades Fase 2 ✅ CONCLUÍDA (2026-07-08)

Nova categoria **Setup** (Primeira vez, Perfis, Dotfiles) + Atividade no Início + Agendamento nas Configurações.

- [x] Profiles / Brewfile — exportar (`brew bundle dump`) e restaurar (`brew bundle install`) a seleção de apps
- [x] Dotfiles & configs — restaurar dotfiles de uma pasta de backup (allowlist fixa, backup .uptend.bak, confirmação)
- [x] Modo "primeira vez" — wizard passo a passo que guia por Homebrew → Essenciais → Perfil → Dotfiles → Ajustes
- [x] Log / histórico de ações — `ActionLog` persistente; Início > Atividade registra install/remove/limpeza/git/update
- [x] Agendamento — intervalos (dias) para limpeza/updates, status vencido/em dia, "rodar agora" e "marcar como feito"
- [ ] (futuro) Agendamento em segundo plano (launchd) e notificações locais

---

## Etapa 6 — Qualidade e segurança (contínuo + antes de distribuir)

- [x] Revisão de segurança (auditoria adversarial; achados corrigidos: path traversal via bundleID, option injection, confirmação de login item) — 2026-07-08
- [ ] Ao empacotar: App Sandbox/hardened runtime + entitlements mínimos
- [ ] Ampliar cobertura de testes conforme cada feature real entra
- [ ] Tratamento de erros consistente em todos os serviços
- [ ] Revisão de acessibilidade e dos tooltips

---

## Etapa 7 — Distribuição

- [x] Ícone e identidade final
- [x] Empacotar DMG (`make-dmg.sh` → build/Uptend.dmg, via hdiutil)
- [x] README público + licença (MIT) + `.gitignore`
- [x] Repositório público no GitHub (set/2026), tag `v0.1.0` e release com `Uptend.dmg`
- [ ] Assinatura Developer ID + notarização na Apple (exige conta paga do usuário)
- [x] Publicado como cask do Homebrew: tap `andre28abr/uptend`, `Casks/uptend.rb` com sha256 do dmg da release (set/2026)
- [x] Versionamento SemVer (v0.1.0); changelog vive em `docs/HISTORICO.md`

---

## Etapa 8 — Extras de manutenção ✅ CONCLUÍDA (2026-07-08)

- [x] Analisador de espaço em disco (Limpeza > Espaço)
- [x] Comparador de Brewfile (Setup > Comparar)
- [x] Saúde de bateria e SSD/SMART (Sistema > Saúde)
- [x] Modo foco (Sistema > Modo foco)
- [x] Versões de runtime — Node/Python/Ruby (Ferramentas > Versões)
- [x] Repos favoritos — clonar lista (Git > Favoritos)
- [x] Relatório do sistema em Markdown (Sistema > Relatório)
- [x] Agendamento em segundo plano via launchd + notificação (Configurações > Agendamento)

## Etapa 9 — Central de notificações (2026-07-08)

- [x] Sininho no topo direito com badge, abrindo popover com "A fazer" (atualizações pendentes, manutenção vencida, segurança) e "Atividade recente"

## Ideias a avaliar (ainda soltas)

_(puxar do `BRAINSTORM.md` conforme forem amadurecendo — ex.: monitor de CPU/RAM por app, backup de configs de apps, modo apresentação, etc.)_

---

## Módulo futuro: HomeLab (em design — ver HOMELAB.md)

- [ ] Fundação: modelo `Host` (local vs SSH) + runner injetável (local/remoto)
- [ ] Aba/tela de conexão de host (SSH via chave, known_hosts)
- [ ] Visão geral remota (CPU/RAM/disco/uptime) — só leitura
- [ ] Docker remoto, Serviços (systemd), Discos (leitura), Atualizações
- [ ] VMs, RAID, backups, ações destrutivas (por último, com travas)

Navegação por **abas** de host (decidido). SO provável: Ubuntu Server LTS ou Proxmox VE.

---

## Arma futura: Auditoria Externa (em design — ver AUDITORIA-EXTERNA.md)

- [x] Schema JSON v1 + coletor portátil (bash, read-only, modo user/admin, Lynis + próprio) — feito 2026-07-17, verificado no lab
- [x] Aba "Auditoria Externa": importar arquivo (ou coletar via SSH) → painel (nota/semáforo/CIS/hardware EOL) — feito 2026-07-17, verificado no lab
- [~] Relatórios: HTML+Markdown+PDF (técnico e executivo) FEITOS 2026-07-17; falta dataset+template Power BI
- [ ] Valor de negócio (impacto/risco/priorização), histórico/comparativo, hardware

---

## Melhorias de segurança/robustez adiadas (levantadas no pente-fino 2026-07-16)

- [ ] Pinning de fingerprint da chave do host no lugar de `StrictHostKeyChecking=accept-new`
      (guardar a fingerprint no HostStore e comparar; hoje aceita a 1ª conexão às cegas).
- [ ] Suporte a IPv6 (endereço, `-6`, colchetes em scp/ssh).
- [ ] Reuso de conexão SSH (ControlMaster/ControlPersist) — menos latência em telas que
      disparam vários comandos.
- [ ] `--env-file` para segredos no deploy/templates em vez de `-e KEY=valor` (some do
      `docker inspect`/histórico de processos do servidor).

---

## Profissionalização da Auditoria (nível empresarial)

Plano detalhado em **`PLANO-AUDITORIA-PRO.md`** (fases A–F: relatório white-label/assinado, GRC/SoA, SOC/CVE, frota, nuvem/Windows). Sequência sugerida: A1+A2 → B2 → A4+B1 → A3 → D1.
