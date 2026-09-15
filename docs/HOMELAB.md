# HomeLab — Uptend (documento de ideias/design)

> Módulo futuro: usar o Uptend para gerenciar um HomeLab (servidor caseiro), além do
> Mac. Documento **vivo** de design — ainda em discussão, **sem código ainda**. Decisões
> fechadas migram para `DECISOES.md`; quando virar plano de execução, entra no `ROADMAP.md`.
> Tudo aqui deve respeitar o `PADROES.md` (segurança, privacidade, testes).

**Criado:** 2026-07-15 · **Última atualização:** 2026-07-15

---

## 1. Ideia central

O André quer comprar um HomeLab e gerenciá-lo pelo Uptend — conectar o Mac ao servidor,
e ter uma espécie de painel administrativo nativo no Mac. O HomeLab será usado para:
virtualizar várias VMs, rodar containers Docker, programar, e servir de ambiente de
experimentação. Provável SO: Linux (ver seção 8).

Uso pretendido: VMs (KVM/Proxmox), containers Docker, programação, laboratório.

## 2. Por que encaixa bem tecnicamente

O Uptend já roda tudo por um **executor de comandos abstraído** (`Shell.capture` /
`CommandRunning` + `LiveCommandRunner`/`MockRunner`). "Rodar comando na minha máquina" e
"rodar o mesmo comando no HomeLab via SSH" são a mesma operação, mudando **onde** executa.
Logo, muita coisa já existente pode ser **reaproveitada apontando para o servidor**.

Transporte natural: **SSH**. Já temos meio caminho — o Uptend **gera chave SSH** e já
**envia chave pro GitHub**; enviar a mesma chave pro HomeLab é o mesmo padrão.

### O que mapeia Mac → Linux

| Função | Mac | HomeLab (Linux) | Reaproveita? |
|---|---|---|---|
| Docker | Docker CLI | Docker CLI (idêntico) | Quase 100% |
| Git | git | git | 100% |
| Serviços | brew services | systemd (`systemctl`) | Conceito igual, parser novo |
| Pacotes | Homebrew | apt/dnf/pacman | UI parecida, backend novo |
| Discos/Espaço | df/du | df/du/lsblk/smartctl | Parcial |
| Rede | ifconfig/netstat | ip/ss | Parcial |
| Segurança | spctl/csrutil | ufw/fail2ban/SSH audit | Novo, mesma "cara" |
| Não faz sentido | — | Bateria, Xcode, Homebrew-como-tal | — |

## 3. Organização da interface

### 3.1 Navegação entre hosts — DECIDIDO: ABAS (não seletor)

O André prefere **abas**, no estilo do Terminal do Mac (ver as abas ativas, adicionar
nova aba), em vez de um seletor/dropdown. Faz sentido porque ele terá **poucos hosts**
(no máximo 2 HomeLabs). Diretrizes:
- **"Este Mac" é a primeira aba, fixa/permanente** — o HomeLab é aditivo, nunca substitui.
- Botão **"+"** para adicionar um novo host (abre fluxo de conexão).
- Cada aba com **ponto de status** (online/offline), como já usamos nas categorias.
- Trocar de aba **re-escopa a barra lateral** para as categorias relevantes daquele host.

Esboço:

```
┌──────────────────────────────────────────────────────────┐
│  [ Este Mac ]  [ HomeLab ● ]  [ + ]     ← abas de host     │
├──────────────┬───────────────────────────────────────────┤
│ SIDEBAR       │  DETALHE                                   │
│ (muda por host)│  Ex. HomeLab ▸ Visão geral:               │
│  Visão geral  │   CPU 12% · RAM 40% · Disco 61%            │
│  Docker       │   Uptime 12d · 3 VMs · 8 containers        │
│  Serviços     │   Temp 44°C · RAID: saudável               │
│  Discos/RAID  │                                            │
│  Máquinas VM  │                                            │
│  Rede / Git   │                                            │
│  Segurança    │                                            │
│  Terminal     │                                            │
└──────────────┴───────────────────────────────────────────┘
```

### 3.2 Princípios de UI

- "Este Mac" continua exatamente como está hoje; HomeLab é adição.
- Cada host tem uma **Visão geral estilo painel** (tiles de saúde: CPU/RAM/disco/uptime/
  temperatura/VMs/containers), reaproveitando os medidores do monitor atual.
- Mesma linguagem visual (cards, tags, tooltips) — a pessoa nem sente que mudou de máquina.

## 4. Ideias de funções pro HomeLab

- **Máquinas virtuais**: listar/ligar/desligar VMs (KVM/libvirt ou Proxmox), uso por VM.
- **Discos & RAID visual**: mapa de discos, saúde **SMART** com semáforo, status do array
  (mdadm/ZFS) num painel visual.
- **Backups**: status de jobs (restic/borg/rsync/snapshots ZFS) — "último backup há 2h ✓".
- **Atualizações do servidor**: pacotes desatualizados + aplicar com log ao vivo (como o brew).
- **Wake-on-LAN / ligar-desligar** o servidor a partir do Mac.
- **Terminal embutido**: começa mostrando saída de comandos (folha de log); depois interativo.
- **"Primeira configuração do servidor"**: assistente que instala Docker, firewall, cria
  usuário, endurece o SSH — a pegada de "setup" do Uptend, agora pro lab.

## 5. Segurança (o diferencial do Uptend)

- **Chaves SSH no Keychain**, nunca senha em argv/config/log. Auth por chave, não por senha.
- **Verificação da chave do host (known_hosts)** com confirmação explícita na 1ª conexão;
  aviso claro se a chave mudar (possível man-in-the-middle).
- **Tensão do sudo**: localmente o Uptend nunca pede admin; num servidor, admin é o ponto.
  Proposta coerente: conecta com um usuário; para ações privilegiadas, o Uptend **mostra o
  comando exato** e ou o usuário tem `sudo` liberado pra aquilo, ou o Uptend **recusa e
  mostra o comando pra rodar manualmente** (igual "abrir no Terminal" do brew). Nunca
  guardar senha de sudo.
- **Sutileza técnica**: local evita shell (`Process` + args); mas SSH **reintroduz um shell
  no lado remoto** → todo argumento remoto passa por `InputValidator` + camada de aspas
  segura. (Ponto que muita ferramenta erra.)
- **Operações destrutivas** (formatar disco, montar RAID): confirmação dupla, por último,
  com as maiores travas.

## 6. Projetos existentes (posicionamento honesto)

Já existem e são bons: **Cockpit** (painel web da Red Hat, bem parecido), **Proxmox**
(VMs/LXC, com API REST), **Portainer** (Docker), **TrueNAS** (RAID/storage), **Grafana**
(monitoramento). Conselho: **não reinventar** Proxmox/TrueNAS. Nicho do Uptend = controle
**nativo no Mac** que unifica máquina + lab num app só, com a mesma UX limpa e postura de
segurança — e, quando fizer sentido, **integrar** (ex.: API do Proxmox) em vez de competir.

## 7. Como implementar (roteiro em fases) — ainda não iniciado

1. **Fundação**: modelo `Host` (local vs SSH) + *runner* injetável que executa local **ou**
   remoto. Hoje os serviços chamam `Shell.capture` direto → esse é o refactor de base
   (com testes de parsers puros, seguindo o padrão).
2. **Conexão**: tela/aba de host (adicionar/testar/known_hosts), reaproveitando a chave SSH.
3. **Primeiro painel remoto (só leitura)**: "Visão geral" do HomeLab (CPU/RAM/disco/uptime).
   Baixo risco, prova a tubulação inteira.
4. **Docker remoto** (UI já existe).
5. **Serviços (systemd), Discos (leitura), Atualizações.**
6. **Por último, com mais travas**: VMs, RAID, backups, ações destrutivas.

## 8. Decisão em aberto: sistema operacional do HomeLab

Candidatos que o André cogitou: Ubuntu Server, Fedora ("vedor"?), Rocky Linux (com receio
do episódio Red Hat 2023 — ver nota). Objetivo dele: pacotes atualizados / tecnologias
atuais, com foco em rodar **containers**.

**Insight importante**: para cargas em **containers**, a "frescura" dos pacotes do SO base
importa **pouco** — o container traz o próprio userland atualizado. O que importa no host é:
kernel moderno + Docker/Podman atualizados + bom storage (btrfs/zfs). Ou seja, uma base
"estável" (Ubuntu LTS/Debian) serve muito bem mesmo parecendo "mais velha".

Notas por opção:
- **Ubuntu Server 24.04 LTS** — melhor equilíbrio: ecossistema gigante, Docker impecável,
  toneladas de tutoriais. Recomendado como base simples.
- **Debian 12** — sólido, pacotes mais conservadores. Ótimo "instala e esquece".
- **Fedora Server** — pacotes bem novos (systemd/podman/cgrov2/btrfs), mas ciclo curto
  (~13 meses de suporte) → mais churn de upgrade. Bom se quiser bleeding edge.
- **Rocky/Alma (família RHEL)** — estáveis, suporte longo. Rocky **está vivo e mantido**;
  o episódio de 2023 foi a Red Hat restringir o **código-fonte** do RHEL, e Rocky/Alma se
  adaptaram. Porém a família RHEL é **conservadora** em novidade de pacotes → menos ideal
  se o objetivo é "tecnologias mais atuais".
- **Proxmox VE** (base Debian) — se **VMs são centrais** (e são), é o rei do homelab:
  hipervisor + LXC + painel web. Pode ser **a base**, rodando VMs Ubuntu/Docker por dentro.
  Bônus: casa com uma futura integração Uptend ↔ API do Proxmox.

**Recomendação atual (a confirmar quando o hardware chegar):**
- Se VMs importam (importam) → **Proxmox VE como base**, com **VMs Ubuntu Server LTS** para
  as cargas Docker. Setup clássico e poderoso de homelab.
- Se preferir uma única caixa simples → **Ubuntu Server 24.04 LTS**.
- A preocupação com "pacotes atuais" fica em grande parte resolvida pelos **containers**.

## 8.1 Integração Proxmox (dois níveis)

Se o SO central for **Proxmox VE** (instalado bare metal; base Debian + hipervisor), o
Uptend fala com ele em dois níveis:
1. **Genérico via SSH** — Proxmox é Debian, então Docker/discos/serviços funcionam como
   em qualquer Linux.
2. **Nativo via API REST do Proxmox** (porta 8006, auth por token) — listar/ligar/desligar
   VMs e LXC, uso de recursos, status de nós/storage, de forma gráfica. **Reaproveita
   exatamente o padrão do cliente GitHub** (API REST + token no Keychain + rede só na ação).

Pilha típica: Hardware → Proxmox VE → VMs (Ubuntu+Docker) / LXC. Proxmox é a melhor opção
se VMs forem centrais; Ubuntu direto na máquina é a alternativa simples (VMs menos centrais).

## 8.2 Estratégia de teste: OrbStack (decidido, enquanto não há hardware)

O André já tem **OrbStack** no Mac. OrbStack roda **VMs Linux reais** com IP e **acesso SSH**
→ serve de "HomeLab de mentira" pra desenvolver e verificar **toda a fundação** antes de
comprar hardware:
- Testável no OrbStack: fluxo de conexão SSH (host/chave/known_hosts), rodar comandos e
  parsear saída (Docker, systemd, df/du, atualizações), Visão geral só-leitura, Docker remoto.
  Sandbox rápido de criar/destruir → seguro até pra testar comando destrutivo.
- **Não** testável no OrbStack (fica pro hardware real): hardware físico (SMART, RAID,
  temperatura, wake-on-LAN) e a **API do Proxmox** (Proxmox quer bare metal). A camada SSH
  genérica — que é a fundação — testa 100%.

Plano: desenvolver a fundação (runner SSH + conexão + painéis genéricos) contra uma VM
Ubuntu do OrbStack; plugar Proxmox/hardware por cima quando o servidor existir.

## 8.3 Ideia futura: Central de Segurança / Monitoramento (SIEM "fácil")

Camada amigável de monitoramento contínuo de segurança (evitar a sigla "SIEM" na UI — é
jargão que espanta leigo). Detectar → avisar em linguagem simples → dizer como corrigir.
Fazer em **camadas**:
- **A) Nativo leve (padrão):** expande os Alertas já construídos + lê fontes fáceis de log
  (auth.log/SSH falhos, banimentos fail2ban, quedas de serviço, disco cheio, drift de
  config SSH/firewall, updates de segurança). Sem instalar nada pesado. Centraliza num
  painel só o que já temos espalhado (fail2ban + ufw + auth + Lynis + SMART + updates).
- **B) Turbinar (opcional):** subir o **Wazuh** (SIEM/XDR open-source, Docker) pelo Catálogo
  e o Uptend vira o rosto amigável: top alertas traduzidos + dashboard embutido (WebView,
  como o Metabase) + correção. Não reinventar o motor.

**Ponto crítico (24/7):** o Mac não fica sempre ligado → vigilância real precisa de algo
**no servidor** (Wazuh ou script leve) que **empurre** o alerta (Telegram/ntfy/e-mail). O
Uptend é o **configurador** + **front amigável** (ver/corrigir quando abrir). Complementa a
Auditoria Externa (foto pontual) com vigilância contínua. Status: ideia, sem código.

## 9. Outras decisões que moldam o design (quando o hardware chegar)

- **Plataforma — DECIDIDO**: **Proxmox VE como base** (bare metal) + **TrueNAS SCALE rodando
  como VM** (com passthrough dos discos). Ganha gestão de VM do Proxmox + storage/backup
  (ZFS + Cloud Sync) do TrueNAS. Implica: Uptend terá integração via **API do Proxmox** para
  VMs/LXC e, mais adiante, possivelmente API do TrueNAS para storage/backup. Backup nuvem em
  si é OS-agnóstico (restic/borg/rclone/kopia). Complexidade extra: passthrough de disco.
- **Usuário de acesso** (em aberto): root direto (comum em homelab, menos seguro) vs usuário
  comum + sudo específico (mais seguro, mais setup).

## 10. Lab de testes (OrbStack) — configurado em 2026-07-15

Máquina de teste que faz o papel de "Servidor Linux" (Proxmox não roda no OrbStack).
- **Nome:** uptend-lab · Ubuntu · **IP:** (IP privado da VM) · **usuário:** andresouza
- **Acesso:** SSH por IP + chave `~/.ssh/uptend_lab_ed25519` (sudo sem senha)
- **Configurado:** Docker + containers nginx/redis/postgres; systemd (docker/ssh/cron ativos)
- Acesso alternativo pelo OrbStack: `ssh uptend-lab@orb`

## 11. Progresso — Passo 1 (fundação) INICIADO em 2026-07-15

Feito (compila + 8 testes com fixtures reais do uptend-lab):
- `RemoteHost` (metadados: nome/kind/address/user/port/keyPath; `isValid`) + `HostStore`
  (persistência UserDefaults, add/remove/hosts(of:)).
- `SSHRunner`: executa comando remoto via `/usr/bin/ssh` (Process+args, chave, BatchMode,
  ConnectTimeout, accept-new). `test()` roda `uname -sr`. Só comandos fixos por enquanto
  (ssh reintroduz shell remoto — entrada de usuário será validada quando entrar).
- `LinuxStats` (parsers puros): loadavg, uptime (+humanUptime), meminfo (fração usada),
  df raiz, /proc/stat CPU (amostragem). `InputValidator.isValidUnixUser`. HostKind agora Codable.

A FAZER (próximo): ligar na UI — substituir hosts de exemplo do HostTabBar por `HostStore`
real; "Adicionar Servidor" real (formulário → SSHRunner.test → salva); Visão geral lendo
dados reais via SSHRunner. Segurança pendente: confirmação de fingerprint (known_hosts) no
Passo 2 (hoje usa accept-new).

## 12. Módulo Servidor — ideias aprovadas (2026-07-15) e ordem de construção

Foco: só "Servidor" (Linux via SSH); Proxmox fica pro hardware. Uptend = central única,
sem terminal, sem web do Proxmox. Tudo via Docker onde fizer sentido.

Ideias aprovadas:
1. **Templates prontos (Docker)**: catálogo de serviços self-hosted; form de config →
   gera docker compose → sobe no servidor; link pro painel do serviço. (Firewall real é
   host/VM, não container — mas Pi-hole/AdGuard/NPM/WireGuard/CrowdSec/Vaultwarden viram
   container ótimo.)
2. Catálogo por categoria (rede/seg, nuvem/arquivos, mídia, dev, monitoramento, automação,
   painel). Docker/compose confirmado como melhor forma.
3. **Atualizações**: apt/dnf do servidor (log ao vivo); update de imagens de container;
   (auto-update do próprio Uptend = escopo à parte). Sudo com confirmação.
4. **Arquivos (SFTP)** Mac↔servidor + **Discos** (lsblk/SMART leitura → montar → formatar/
   RAID/LUKS por último, destrutivo travado).
5. **Rede** (ping/portas ss/dns/speedtest) + **Segurança** no servidor (ClamAV/Lynis/gitleaks
   são Linux nativo! + ufw/fail2ban/rkhunter/hardening SSH).
6. Central sem terminal (terminal = saída de emergência).

Extras sugeridos: setup wizard do servidor; monitor ao vivo (gráficos); processos (matar);
systemd (start/stop/logs journalctl); visualizador de logs; backups restic/borg (agendar/
restaurar); usuários & chaves SSH; HTTPS via proxy reverso; wake-on-LAN/desligar; dashboard
de serviços; deploy Mac→servidor; configs no GitHub privado; alertas no Mac (sininho).

Ordem de construção: 1) Containers(Docker) 2) Templates 3) systemd+Atualizações 4) Segurança
5) Rede 6) Arquivos(SFTP) 7) Discos 8) setup wizard/backups/alertas/deploy.
