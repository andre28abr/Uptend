# Laboratório de teste do auditor Uptend (OrbStack)

VMs criadas no OrbStack para validar o coletor/auditor: para cada família de distro,
um par **seguro** (endurecido, deve sair quase limpo) e **vulnerável** (cheio de
brechas, para ver o coletor pegar o máximo de achados).

## Máquinas (8)

| VM | Distro | Papel |
|---|---|---|
| `ubuntu-seguro` / `ubuntu-vuln` | Ubuntu 24.04 (apt) | AppArmor / ufw / unattended-upgrades |
| `debian-seguro` / `debian-vuln` | Debian 12 (apt) | idem família Debian |
| `fedora-seguro` / `fedora-vuln` | Fedora 43 (dnf) | SELinux / firewalld / dnf-automatic (mais novo) |
| `rocky-seguro` / `rocky-vuln`   | Rocky 9 (dnf)   | SELinux / firewalld (enterprise/RHEL) |
| `eol-fedora` (só vulnerável)    | Fedora 42 (EOL) | "pior servidor": SO fora de suporte + todas as brechas |

Endereço no app: `<nome>.orb.local` · usuário `andresouza` · chave `~/.ssh/uptend_lab_ed25519`.
Os 8 estão cadastrados como hosts (`kind: server`) no Uptend → coleta com 1 clique em
**Auditoria › Importar/Coletar**.

## Re-provisionar

```bash
# família apt (Ubuntu/Debian)
orbctl run -m <vm> bash -s -- <seguro|vuln>  < lab/provision-apt.sh
# família dnf (Fedora/Rocky)
orbctl run -m <vm> bash -s -- <seguro|vuln>  < lab/provision-dnf.sh
```

## Teto do OrbStack (esperado)

VMs do OrbStack usam **kernel compartilhado** → a máquina "segura" nunca zera 100%:
`auditd`, AppArmor/SELinux enforcing, partições separadas (`/tmp`,`/var`,`/home`),
alguns `sysctl` e o `sudo-nopasswd` do próprio OrbStack ficam como achados ambientais
(baixo/médio). Num servidor real (bare-metal/VM cheia) seriam corrigíveis. Isso NÃO
atrapalha o teste — o contraste seguro×vulnerável continua nítido.

## Resultado da validação (2026-07-21, coletor v1.1.3)

| Distro | vulnerável (abertos) | segura (abertos) |
|---|---|---|
| Ubuntu | 33 | 8 (todos ambientais) |
| Debian | 32 | 8 (todos ambientais) |
| Fedora | 31 | 8 (todos ambientais) |
| Rocky  | 32 | 8 (todos ambientais) |

**Cobertura das vulneráveis: 35/40 conceitos do catálogo.** `os-eol` coberto pela `eol-fedora`;
`fw-default` coberto pela `debian-vuln` (ufw ligado mas default-allow). As **5 lacunas restantes
são impossíveis no OrbStack** (não são descuido): `kernel-aslr`/`kernel-info-leak`/`kernel-suid`
(kernel compartilhado ignora os sysctl), `disk-space` (disco esparso de 555G, inviável encher) e
`time-sync` (o hipervisor sincroniza o relógio da VM). Num servidor real seriam trigáveis.

**Seguras: os 8 achados restantes são 100% ambientais do OrbStack** (auditd, SELinux/AppArmor,
kernel-net, /tmp-/var-/home sem partição própria, sudo-nopasswd do OrbStack, porta 80 do nginx).
Nenhum é falha de hardening — num servidor real seriam corrigíveis/inexistentes.

As vulneráveis têm openssh em faixa do regreSSHion e (apt) imagem Docker `nginx:1.18.0` para
o cruzamento de CVE.

> ⚠️ As máquinas `*-vuln` são **deliberadamente inseguras** — só para laboratório local
> isolado. Nunca expor à internet.

## Bancos de dados (E4) — PostgreSQL fictício em cada VM

Cada VM tem um Postgres com um banco fictício, para testar a auditoria de BD (modo estrutura):
- **`*-vuln` + `eol-fedora`** → `loja_insegura` (PII em texto plano, senha sem hash, tabelas sem PK)
  → ~21 achados de BD (8 altos).
- **`*-seguro`** → `loja_segura` (PII cifrada em `bytea`, `senha_hash`, todas com PK, FK indexada)
  → 0 achados.

Reproduzir:
```bash
orbctl run -m <vm> bash -s < lab/setup-db.sh                       # instala/inicia Postgres
orbctl run -m <vm> bash -c 'sudo -u postgres psql -f -' < lab/db-insecure.sql   # ou db-secure.sql
```
Para auditar: **Coletar de servidor** com o tique "Auditar bancos de dados" (o coletor lê só o
schema via `information_schema`, nunca os dados). As `*-vuln` têm o Postgres exposto/config de lab
só para exercitar os achados.
