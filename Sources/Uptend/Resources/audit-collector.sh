#!/usr/bin/env bash
# =============================================================================
# Uptend — Coletor de Auditoria Externa (schema v1)
#
# Roda UMA passada num servidor Linux e escreve um arquivo JSON estruturado que o
# Uptend importa e transforma em painel + relatórios.
#
# PRINCÍPIOS INEGOCIÁVEIS (é o que separa "auditor" de "malware"):
#   • Read-only: NÃO modifica config, NÃO instala, NÃO cria persistência (cron/serviço).
#   • Sem rede: só escreve um arquivo local. Zero conexão de saída.
#   • Transparente: texto puro, legível, não ofuscado. Gera sha256 para conferência.
#   • Consentimento: rode apenas em sistema AUTORIZADO (seu, ou cliente com escopo assinado).
#
# Dois modos (detectados automaticamente):
#   • usuário: sem privilégio — coleta o que der, fricção zero.
#   • admin:   com sudo -n (ou root) — auditoria completa (sshd -T, dmidecode, smartctl…).
#
# Uso:   bash audit-collector.sh [pasta-de-saida]
#        UPTEND_RUN_LYNIS=1 bash audit-collector.sh   # também roda o Lynis (mais lento)
# =============================================================================

set -u
# Garante os diretórios sbin no PATH: em Debian (e shells não-interativos) /usr/sbin
# não vem no PATH do usuário, e binários como nginx/sshd/ufw ficam invisíveis.
export PATH="/usr/local/sbin:/usr/sbin:/sbin:$PATH"
COLLECTOR_NAME="uptend-audit"
COLLECTOR_VERSION="1.1.7"
SCHEMA_VERSION=1

OUTDIR="${1:-$HOME}"
COLLECTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

# ---- Modo (usuário vs admin) -------------------------------------------------
SUDO=""
MODE="user"
if [ "$(id -u)" = "0" ]; then
    MODE="admin"
elif sudo -n true 2>/dev/null; then
    MODE="admin"; SUDO="sudo -n"
fi

# ---- Helpers de JSON ---------------------------------------------------------
# Escapa uma string para caber com segurança dentro de aspas JSON.
json_escape() {
    local s=$1
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\t'/\\t}
    s=${s//$'\r'/\\r}
    s=${s//$'\n'/\\n}
    printf '%s' "$s"
}
# String JSON entre aspas (sempre válida).
jstr() { printf '"%s"' "$(json_escape "$1")"; }
# String OU null se vazia.
jstrn() { if [ -z "${1:-}" ]; then printf 'null'; else jstr "$1"; fi; }
# Número inteiro OU null se não for inteiro.
jnum() { if printf '%s' "${1:-}" | grep -Eq '^-?[0-9]+$'; then printf '%s' "$1"; else printf 'null'; fi; }
# Booleano a partir de yes/true/1 · no/false/0 · senão null.
jbool() {
    case "$(printf '%s' "${1:-}" | tr 'A-Z' 'a-z')" in
        yes|true|1|active|passed) printf 'true' ;;
        no|false|0|inactive|failed) printf 'false' ;;
        *) printf 'null' ;;
    esac
}
have() { command -v "$1" >/dev/null 2>&1; }
trim() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

# Redige segredos da evidência bruta (senha/token/segredo/chave = •••) e blocos de chave.
# Case-insensitive (flag I do GNU sed, do servidor Linux). Segredo nunca em log (PADRÕES).
redact_raw() {
    printf '%s' "$1" \
        | sed -E '/-----BEGIN/,/-----END/c\[bloco de chave redigido]' \
        | sed -E 's/(password|passwd|token|secret|api[_-]?key|private[_-]?key|bearer|credential)([":= ]+)[^[:space:]",}]+/\1\2***/Ig' \
        | head -c 4000
}

# ---- Acumulador de achados ---------------------------------------------------
FINDINGS=""   # objetos JSON separados por vírgula
add_finding() {
    # id title severity category cis evidence recommendation business_impact [evidence_raw]
    local obj raw="${9:-}"
    [ -n "$raw" ] && raw="$(redact_raw "$raw")"
    obj=$(printf '{"id":%s,"title":%s,"severity":%s,"category":%s,"cis":%s,"evidence":%s,"recommendation":%s,"business_impact":%s,"evidence_raw":%s}' \
        "$(jstr "$1")" "$(jstr "$2")" "$(jstr "$3")" "$(jstr "$4")" \
        "$(jstrn "$5")" "$(jstrn "$6")" "$(jstrn "$7")" "$(jstrn "$8")" "$(jstrn "$raw")")
    if [ -z "$FINDINGS" ]; then FINDINGS="$obj"; else FINDINGS="$FINDINGS,$obj"; fi
}

# =============================================================================
# COLETA
# =============================================================================

HOSTNAME_VAL="$(hostname 2>/dev/null || echo desconhecido)"
MACHINE_ID="$(cat /etc/machine-id 2>/dev/null || echo '')"

# ---- Máquina / hardware ------------------------------------------------------
VIRT="$( (have systemd-detect-virt && systemd-detect-virt) 2>/dev/null || echo none)"
if [ "$VIRT" = "none" ] || [ -z "$VIRT" ]; then IS_VIRTUAL=false; else IS_VIRTUAL=true; fi

CPU_MODEL="$(trim "$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2)")"
[ -z "$CPU_MODEL" ] && CPU_MODEL="$(trim "$(grep -m1 -i 'Model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2)")"
[ -z "$CPU_MODEL" ] && have lscpu && CPU_MODEL="$(trim "$(LC_ALL=C lscpu 2>/dev/null | grep -m1 -i 'Model name' | cut -d: -f2)")"
[ -z "$CPU_MODEL" ] && CPU_MODEL="$(trim "$(grep -m1 'Hardware' /proc/cpuinfo 2>/dev/null | cut -d: -f2)")"
[ "$CPU_MODEL" = "-" ] && CPU_MODEL=""   # lscpu devolve "-" em alguns kernels virtuais
CPU_CORES="$(nproc 2>/dev/null || echo '')"
RAM_KB="$(grep -m1 MemTotal /proc/meminfo 2>/dev/null | grep -Eo '[0-9]+')"
RAM_BYTES=""
[ -n "$RAM_KB" ] && RAM_BYTES=$((RAM_KB * 1024))

SYS_VENDOR=""; SYS_MODEL=""; BIOS_VENDOR=""; BIOS_VERSION=""; BIOS_DATE=""
if [ -r /sys/class/dmi/id/sys_vendor ]; then
    SYS_VENDOR="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)"
    SYS_MODEL="$(cat /sys/class/dmi/id/product_name 2>/dev/null)"
    BIOS_VENDOR="$(cat /sys/class/dmi/id/bios_vendor 2>/dev/null)"
    BIOS_VERSION="$(cat /sys/class/dmi/id/bios_version 2>/dev/null)"
    BIOS_DATE="$(cat /sys/class/dmi/id/bios_date 2>/dev/null)"
elif [ "$MODE" = "admin" ] && have dmidecode; then
    SYS_VENDOR="$($SUDO dmidecode -s system-manufacturer 2>/dev/null | head -1)"
    SYS_MODEL="$($SUDO dmidecode -s system-product-name 2>/dev/null | head -1)"
    BIOS_VENDOR="$($SUDO dmidecode -s bios-vendor 2>/dev/null | head -1)"
    BIOS_VERSION="$($SUDO dmidecode -s bios-version 2>/dev/null | head -1)"
    BIOS_DATE="$($SUDO dmidecode -s bios-release-date 2>/dev/null | head -1)"
fi

# ---- Sistema operacional -----------------------------------------------------
OS_ID=""; OS_VERSION=""; OS_PRETTY=""
if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID="${ID:-}"; OS_VERSION="${VERSION_ID:-}"; OS_PRETTY="${PRETTY_NAME:-}"
fi
KERNEL="$(uname -r 2>/dev/null)"
UPTIME_SEC="$(cut -d' ' -f1 /proc/uptime 2>/dev/null)"

# Data de fim de suporte (EOL) — tabela embutida das distros comuns.
os_eol() {
    case "${OS_ID}:${OS_VERSION}" in
        ubuntu:26.04) echo 2031-04-30 ;;
        ubuntu:24.04) echo 2029-05-31 ;;
        ubuntu:22.04) echo 2027-04-01 ;;
        ubuntu:20.04) echo 2025-05-29 ;;
        ubuntu:18.04) echo 2023-05-31 ;;
        debian:13)    echo 2030-06-30 ;;
        debian:12)    echo 2028-06-30 ;;
        debian:11)    echo 2026-08-31 ;;
        debian:10)    echo 2024-06-30 ;;
        rocky:10|almalinux:10|rhel:10|oracle:10) echo 2035-05-31 ;;
        rocky:9|almalinux:9|rhel:9|centos:9|oracle:9) echo 2032-05-31 ;;
        rocky:8|almalinux:8|rhel:8|centos:8|oracle:8) echo 2029-05-31 ;;
        fedora:44)    echo 2027-05-13 ;;
        fedora:43)    echo 2026-11-26 ;;
        fedora:42)    echo 2026-05-13 ;;
        fedora:41)    echo 2025-11-30 ;;
        fedora:40)    echo 2025-05-31 ;;
        *) echo '' ;;
    esac
}
OS_EOL="$(os_eol)"

# Atualizações pendentes (total / segurança) — sem rede (usa cache do apt).
UPD_TOTAL=""; UPD_SECURITY=""
if [ -x /usr/lib/update-notifier/apt-check ]; then
    APTCHK="$(/usr/lib/update-notifier/apt-check 2>&1)"   # "total;security"
    UPD_TOTAL="${APTCHK%%;*}"; UPD_SECURITY="${APTCHK##*;}"
elif have apt-get; then
    SIM="$(LC_ALL=C apt-get -s upgrade 2>/dev/null | grep -c '^Inst')"
    UPD_TOTAL="$SIM"
    UPD_SECURITY="$(LC_ALL=C apt-get -s upgrade 2>/dev/null | grep '^Inst' | grep -ci security)"
fi

# ---- Discos + SMART ----------------------------------------------------------
DISKS=""
if have lsblk; then
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        # Colunas: NAME SIZE ROTA TYPE MODEL(pode ter espaços, vem por último)
        DNAME="$(echo "$line" | awk '{print $1}')"
        DTYPE="$(echo "$line" | awk '{print $4}')"
        [ "$DTYPE" != "disk" ] && continue
        # Ignora pseudo-discos (RAM/swap/loop/network-block) — não são hardware real.
        case "$DNAME" in zram*|loop*|ram*|nbd*|sr*) continue ;; esac
        DSIZE="$(echo "$line" | awk '{print $2}')"
        # Sem tamanho (dispositivo sem mídia) → não é um disco de verdade para o relatório.
        [ "$DSIZE" = "0" ] && continue
        DROTA="$(echo "$line" | awk '{print $3}')"
        DMODEL="$(echo "$line" | awk '{$1=$2=$3=$4=""; sub(/^ +/,""); print}')"
        ROT_JSON=false; [ "$DROTA" = "1" ] && ROT_JSON=true

        SMART_AVAIL=false; SMART_HEALTHY=null; POH=""; REALLOC=""
        if [ "$MODE" = "admin" ] && have smartctl; then
            SOUT="$($SUDO smartctl -H -A "/dev/$DNAME" 2>/dev/null)"
            if echo "$SOUT" | grep -qi 'SMART overall-health\|SMART Health Status'; then
                SMART_AVAIL=true
                if echo "$SOUT" | grep -qi 'PASSED\|OK'; then SMART_HEALTHY=true; else SMART_HEALTHY=false; fi
                POH="$(echo "$SOUT" | grep -i 'Power_On_Hours' | awk '{print $NF}' | grep -Eo '[0-9]+' | head -1)"
                REALLOC="$(echo "$SOUT" | grep -i 'Reallocated_Sector' | awk '{print $NF}' | grep -Eo '[0-9]+' | head -1)"
            fi
        fi

        DOBJ="$(printf '{"name":%s,"model":%s,"size_bytes":%s,"rotational":%s,"smart_available":%s,"smart_healthy":%s,"power_on_hours":%s,"reallocated_sectors":%s}' \
            "$(jstr "$DNAME")" "$(jstrn "$(trim "$DMODEL")")" "$(jnum "$DSIZE")" "$ROT_JSON" \
            "$SMART_AVAIL" "$SMART_HEALTHY" "$(jnum "$POH")" "$(jnum "$REALLOC")")"
        if [ -z "$DISKS" ]; then DISKS="$DOBJ"; else DISKS="$DISKS,$DOBJ"; fi

        # Achados de disco
        if [ "$SMART_HEALTHY" = "false" ]; then
            add_finding "disk-smart-$DNAME" "Disco /dev/$DNAME com falha SMART" "high" "Discos & resiliência" "" \
                "SMART reprovado em /dev/$DNAME" "Faça backup imediato e substitua o disco." \
                "Disco prestes a falhar = risco de perda de dados e parada não planejada."
        elif [ -n "$REALLOC" ] && [ "$REALLOC" -gt 0 ] 2>/dev/null; then
            add_finding "disk-realloc-$DNAME" "Disco /dev/$DNAME com setores realocados" "medium" "Discos & resiliência" "" \
                "$REALLOC setores realocados" "Monitore de perto e planeje a troca." \
                "Setores realocados indicam desgaste — sinal de fim de vida do hardware."
        fi
    done <<< "$(lsblk -dn -b -o NAME,SIZE,ROTA,TYPE,MODEL 2>/dev/null)"
fi

# ---- Recursos / estado operacional -------------------------------------------
# Uso do disco raiz (risco de encher = parada), swap, reinício pendente, hora.
DROOT_PCT=""; DROOT_FREE=""; DROOT_TOTAL=""
if have df; then
    read -r DR_TOTAL_KB DR_AVAIL_KB DR_PCT <<< "$(LC_ALL=C df -P / 2>/dev/null | awk 'NR==2{gsub("%","",$5); print $2, $4, $5}')"
    printf '%s' "${DR_TOTAL_KB:-}" | grep -Eq '^[0-9]+$' && DROOT_TOTAL=$((DR_TOTAL_KB * 1024))
    printf '%s' "${DR_AVAIL_KB:-}" | grep -Eq '^[0-9]+$' && DROOT_FREE=$((DR_AVAIL_KB * 1024))
    printf '%s' "${DR_PCT:-}" | grep -Eq '^[0-9]+$' && DROOT_PCT="$DR_PCT"
fi
SWAP_TOTAL="$(grep -m1 SwapTotal /proc/meminfo 2>/dev/null | grep -Eo '[0-9]+')"
[ -n "$SWAP_TOTAL" ] && SWAP_TOTAL=$((SWAP_TOTAL * 1024))

REBOOT_REQ=false
[ -f /var/run/reboot-required ] && REBOOT_REQ=true

TIME_SYNCED=null
if have timedatectl; then
    TS="$(timedatectl show -p NTPSynchronized --value 2>/dev/null)"
    [ "$TS" = "yes" ] && TIME_SYNCED=true
    [ "$TS" = "no" ] && TIME_SYNCED=false
fi

# Achados de recursos
if printf '%s' "$DROOT_PCT" | grep -Eq '^[0-9]+$'; then
    if [ "$DROOT_PCT" -ge 90 ]; then
        add_finding "disk-space-root" "Disco raiz quase cheio (${DROOT_PCT}%)" "high" "Discos & resiliência" "" \
            "Uso do / em ${DROOT_PCT}%" "Libere espaço ou aumente o disco com urgência." \
            "Disco cheio derruba serviços e pode corromper dados — risco de parada iminente."
    elif [ "$DROOT_PCT" -ge 80 ]; then
        add_finding "disk-space-root" "Disco raiz enchendo (${DROOT_PCT}%)" "medium" "Discos & resiliência" "" \
            "Uso do / em ${DROOT_PCT}%" "Planeje limpeza ou aumento do disco." \
            "Perto do limite: sem folga, uma atualização ou log pode encher e parar o servidor."
    else
        add_finding "disk-space-ok" "Espaço em disco saudável (${DROOT_PCT}%)" "ok" "Discos & resiliência" "" \
            "Uso do / em ${DROOT_PCT}%" "" ""
    fi
fi
if [ "$REBOOT_REQ" = true ]; then
    add_finding "reboot-required" "Reinício pendente (atualizações aplicadas)" "medium" "Atualizações" "" \
        "/var/run/reboot-required presente" "Agende uma reinicialização em janela de manutenção." \
        "Correções (inclusive de kernel/segurança) só valem após o reinício — até lá o risco continua."
fi
if [ "$TIME_SYNCED" = "false" ]; then
    add_finding "time-not-synced" "Relógio do sistema sem sincronização (NTP)" "low" "Sistema operacional" "" \
        "NTPSynchronized=no" "Ative a sincronização de hora (systemd-timesyncd/chrony)." \
        "Hora errada quebra certificados, logs e correlação de eventos em auditoria/forense."
fi

# ---- Usuários e privilégios --------------------------------------------------
LOGIN_USERS=""; SUDO_USERS_JSON="[]"; EMPTY_PW_JSON="[]"
if [ -r /etc/passwd ]; then
    LOGIN_USERS="$(awk -F: '($7 ~ /(bash|zsh|sh|ksh|fish)$/){c++} END{print c+0}' /etc/passwd 2>/dev/null)"
fi
# Membros do grupo sudo/wheel (governança de acesso privilegiado)
SUDO_MEMBERS="$( { getent group sudo 2>/dev/null; getent group wheel 2>/dev/null; } | cut -d: -f4 | tr ',' '\n' | sed '/^$/d' | sort -u )"
if [ -n "$SUDO_MEMBERS" ]; then
    acc=""
    while IFS= read -r u; do
        [ -z "$u" ] && continue
        q="$(jstr "$u")"
        if [ -z "$acc" ]; then acc="$q"; else acc="$acc,$q"; fi
    done <<< "$SUDO_MEMBERS"
    SUDO_USERS_JSON="[$acc]"
fi
# Contas com senha vazia (só admin lê /etc/shadow) → crítico
if [ "$MODE" = "admin" ]; then
    EMPTY_PW="$($SUDO awk -F: '($2==""){print $1}' /etc/shadow 2>/dev/null)"
    if [ -n "$EMPTY_PW" ]; then
        acc=""
        while IFS= read -r u; do
            [ -z "$u" ] && continue
            q="$(jstr "$u")"
            if [ -z "$acc" ]; then acc="$q"; else acc="$acc,$q"; fi
        done <<< "$EMPTY_PW"
        EMPTY_PW_JSON="[$acc]"
        add_finding "empty-passwords" "Conta(s) com senha vazia" "critical" "Segurança / Contas" "5.4.2" \
            "Sem senha: $(printf '%s' "$EMPTY_PW" | tr '\n' ' ')" "Defina senha ou bloqueie as contas (passwd -l)." \
            "Conta sem senha é entrada livre no servidor — comprometimento imediato."
    fi
    # sudo sem senha (NOPASSWD)
    NOPASSWD="$($SUDO grep -rhE '^[^#].*NOPASSWD' /etc/sudoers /etc/sudoers.d 2>/dev/null | grep -v secure_path)"
    if [ -n "$NOPASSWD" ]; then
        add_finding "sudo-nopasswd" "Sudo sem senha (NOPASSWD) configurado" "medium" "Segurança / Contas" "5.3.4" \
            "Regra(s) NOPASSWD em sudoers" "Exija senha no sudo, salvo automações estritamente necessárias." \
            "Sudo sem senha faz uma sessão comprometida virar root sem barreira."
    fi
    # Permissão do /etc/shadow (não pode ser legível por outros)
    SHADOW_PERM="$($SUDO stat -c '%a' /etc/shadow 2>/dev/null)"
    if printf '%s' "$SHADOW_PERM" | grep -Eq '^[0-9]+$'; then
        LAST_DIGIT="${SHADOW_PERM: -1}"
        if [ "$LAST_DIGIT" != "0" ]; then
            add_finding "shadow-perms" "/etc/shadow legível além do dono (perm $SHADOW_PERM)" "high" "Segurança / Contas" "6.1.3" \
                "Permissão $SHADOW_PERM" "Ajuste para 640 root:shadow (ou 600)." \
                "Se hashes de senha vazam, atacantes quebram senhas offline."
        fi
    fi
fi

# =============================================================================
# ACHADOS DE SEGURANÇA / HARDENING
# =============================================================================

# ---- SSH ---------------------------------------------------------------------
SSHD_CFG=""
if [ "$MODE" = "admin" ] && have sshd; then
    SSHD_CFG="$($SUDO sshd -T 2>/dev/null)"
fi
if [ -z "$SSHD_CFG" ] && [ -r /etc/ssh/sshd_config ]; then
    SSHD_CFG="$(grep -vE '^[[:space:]]*#' /etc/ssh/sshd_config 2>/dev/null | tr 'A-Z' 'a-z')"
fi
if [ -n "$SSHD_CFG" ]; then
    CFG_LC="$(printf '%s' "$SSHD_CFG" | tr 'A-Z' 'a-z')"
    # Trecho relevante da config efetiva do SSH (evidência bruta).
    SSH_EXCERPT="$(printf '%s\n' "$CFG_LC" | grep -iE 'permitrootlogin|passwordauthentication|permitemptypasswords|x11forwarding|maxauthtries|clientaliveinterval|logingracetime|allowtcpforwarding' | head -20)"
    ROOTLOGIN="$(printf '%s\n' "$CFG_LC" | grep -E '^\s*permitrootlogin' | awk '{print $2}' | tail -1)"
    PWDAUTH="$(printf '%s\n' "$CFG_LC" | grep -E '^\s*passwordauthentication' | awk '{print $2}' | tail -1)"
    case "$ROOTLOGIN" in
        yes) add_finding "ssh-root-login" "Login de root por SSH permitido" "high" "Segurança / SSH" "5.2.8" \
                "PermitRootLogin yes" "Defina PermitRootLogin prohibit-password (ou no)." \
                "Root exposto por SSH facilita invasão por força-bruta — porta de entrada crítica." "$SSH_EXCERPT" ;;
        *) add_finding "ssh-root-login-ok" "Login direto de root por SSH bloqueado" "ok" "Segurança / SSH" "5.2.8" \
                "PermitRootLogin ${ROOTLOGIN:-prohibit-password}" "" "" "$SSH_EXCERPT" ;;
    esac
    case "$PWDAUTH" in
        yes) add_finding "ssh-password-auth" "SSH aceita senha (sem exigir chave)" "medium" "Segurança / SSH" "5.2.10" \
                "PasswordAuthentication yes" "Use chaves e defina PasswordAuthentication no." \
                "Autenticação por senha é vulnerável a força-bruta e vazamento de credenciais." "$SSH_EXCERPT" ;;
        no) add_finding "ssh-password-auth-ok" "SSH exige chave (senha desativada)" "ok" "Segurança / SSH" "5.2.10" \
                "PasswordAuthentication no" "" "" "$SSH_EXCERPT" ;;
    esac
    MAXAUTH="$(printf '%s\n' "$CFG_LC" | grep -E '^\s*maxauthtries' | awk '{print $2}' | tail -1)"
    if printf '%s' "$MAXAUTH" | grep -Eq '^[0-9]+$' && [ "$MAXAUTH" -gt 4 ]; then
        add_finding "ssh-maxauthtries" "SSH permite muitas tentativas de senha (MaxAuthTries $MAXAUTH)" "low" "Segurança / SSH" "5.2.7" \
            "MaxAuthTries $MAXAUTH" "Reduza para 3–4 (MaxAuthTries 4)." \
            "Muitas tentativas por conexão facilitam ataques de força-bruta."
    fi
    # PermitEmptyPasswords
    EMPTYPW_SSH="$(printf '%s\n' "$CFG_LC" | grep -E '^\s*permitemptypasswords' | awk '{print $2}' | tail -1)"
    if [ "$EMPTYPW_SSH" = "yes" ]; then
        add_finding "ssh-permit-empty" "SSH aceita senha vazia" "high" "Segurança / SSH" "5.2.11" \
            "PermitEmptyPasswords yes" "Defina PermitEmptyPasswords no." \
            "Aceitar senha vazia por SSH é entrada praticamente livre no servidor."
    else
        add_finding "ssh-permit-empty-ok" "SSH bloqueia senha vazia" "ok" "Segurança / SSH" "5.2.11" "PermitEmptyPasswords no" "" ""
    fi
    # X11Forwarding
    X11_SSH="$(printf '%s\n' "$CFG_LC" | grep -E '^\s*x11forwarding' | awk '{print $2}' | tail -1)"
    if [ "$X11_SSH" = "yes" ]; then
        add_finding "ssh-x11" "Encaminhamento X11 habilitado no SSH" "low" "Segurança / SSH" "5.2.6" \
            "X11Forwarding yes" "Desative se não usar apps gráficos (X11Forwarding no)." \
            "X11 forwarding amplia a superfície de ataque da sessão SSH."
    fi
    # Timeout de sessão ociosa
    CALIVE="$(printf '%s\n' "$CFG_LC" | grep -E '^\s*clientaliveinterval' | awk '{print $2}' | tail -1)"
    if ! printf '%s' "$CALIVE" | grep -Eq '^[1-9][0-9]*$' || [ "${CALIVE:-0}" -gt 900 ] 2>/dev/null; then
        add_finding "ssh-idle-timeout" "SSH sem timeout de sessão ociosa" "low" "Segurança / SSH" "5.2.16" \
            "ClientAliveInterval=${CALIVE:-0}" "Defina ClientAliveInterval 300 e ClientAliveCountMax 3." \
            "Sessões esquecidas abertas facilitam sequestro de sessão."
    else
        add_finding "ssh-idle-timeout-ok" "SSH encerra sessões ociosas" "ok" "Segurança / SSH" "5.2.16" "ClientAliveInterval=$CALIVE" "" ""
    fi
    # LoginGraceTime (janela de autenticação)
    LOGINGRACE="$(printf '%s\n' "$CFG_LC" | grep -E '^\s*logingracetime' | awk '{print $2}' | tail -1)"
    if printf '%s' "$LOGINGRACE" | grep -Eq '^[0-9]+$' && [ "$LOGINGRACE" -gt 60 ]; then
        add_finding "ssh-logingrace" "SSH com janela de login longa (${LOGINGRACE}s)" "low" "Segurança / SSH" "5.2.17" \
            "LoginGraceTime $LOGINGRACE" "Reduza para 60 (LoginGraceTime 60)." \
            "Janela de autenticação longa mantém conexões pendentes abertas — vetor de negação de serviço."
    fi
fi

# ---- MAC (AppArmor / SELinux) ------------------------------------------------
# AppArmor é padrão em Ubuntu/Debian; SELinux em RHEL/Fedora/Rocky. Checa os dois.
MAC_OK=false; MAC_NAME=""; MAC_EVID=""
if have aa-status || have apparmor_status || have aa-enabled; then
    MAC_NAME="AppArmor"
    if { have aa-enabled && $SUDO aa-enabled 2>/dev/null | grep -qi "yes"; } || systemctl is-active apparmor >/dev/null 2>&1; then
        MAC_OK=true; MAC_EVID="AppArmor ativo"
    else
        MAC_EVID="AppArmor presente mas inativo"
    fi
elif have getenforce || have sestatus; then
    MAC_NAME="SELinux"
    SEMODE="$( (have getenforce && getenforce) 2>/dev/null || echo Unknown)"
    MAC_EVID="SELinux: $SEMODE"
    [ "$SEMODE" = "Enforcing" ] && MAC_OK=true
fi
if [ -n "$MAC_NAME" ]; then
    if [ "$MAC_OK" = true ]; then
        add_finding "mac-ok" "Controle de acesso obrigatório ativo ($MAC_NAME)" "ok" "Segurança / Hardening" "1.6.1.1" "$MAC_EVID" "" ""
    else
        add_finding "mac-inactive" "Controle de acesso obrigatório inativo ($MAC_NAME)" "medium" "Segurança / Hardening" "1.6.1.1" \
            "$MAC_EVID" "Ative e coloque em modo enforcing ($MAC_NAME)." \
            "Sem MAC (AppArmor/SELinux), um serviço comprometido tem acesso mais amplo ao sistema."
    fi
else
    add_finding "mac-missing" "Sem AppArmor nem SELinux" "medium" "Segurança / Hardening" "1.6.1.1" \
        "Nenhum framework de MAC detectado" "Habilite AppArmor (Debian/Ubuntu) ou SELinux (RHEL/Fedora)." \
        "MAC contém o estrago de um serviço invadido — sua ausência aumenta o impacto de uma invasão."
fi

# ---- auditd (registro de auditoria do kernel) --------------------------------
if have systemctl && systemctl is-active auditd >/dev/null 2>&1; then
    add_finding "auditd-ok" "Auditoria do sistema ativa (auditd)" "ok" "Segurança / Logs" "4.1.1.1" "auditd ativo" "" ""
else
    add_finding "auditd-missing" "Auditoria do sistema (auditd) inativa" "medium" "Segurança / Logs" "4.1.1.1" \
        "serviço auditd não está ativo" "Instale e ative o auditd para trilha de auditoria." \
        "Sem auditd, ações no servidor não deixam trilha confiável para investigação (forense/compliance)."
fi

# ---- Kernel: ASLR ------------------------------------------------------------
ASLR="$(cat /proc/sys/kernel/randomize_va_space 2>/dev/null)"
if [ "$ASLR" = "2" ]; then
    add_finding "kernel-aslr-ok" "ASLR ativo (proteção de memória)" "ok" "Segurança / Hardening" "1.5.1" "randomize_va_space=2" "" ""
elif [ -n "$ASLR" ]; then
    add_finding "kernel-aslr" "ASLR não está no nível máximo" "low" "Segurança / Hardening" "1.5.1" \
        "randomize_va_space=$ASLR" "Defina kernel.randomize_va_space=2." \
        "ASLR dificulta a exploração de falhas de memória; reduzi-lo facilita ataques."
fi

# ---- Contas: unicidade do UID 0 ----------------------------------------------
if [ -r /etc/passwd ]; then
    UID0="$(awk -F: '($3==0){print $1}' /etc/passwd 2>/dev/null | tr '\n' ' ')"
    UID0="$(trim "$UID0")"
    if [ "$UID0" = "root" ]; then
        add_finding "uid0-unique-ok" "Apenas root tem UID 0" "ok" "Segurança / Contas" "6.2.9" "$UID0" "" ""
    elif [ -n "$UID0" ]; then
        add_finding "uid0-multiple" "Mais de uma conta com UID 0 (root)" "high" "Segurança / Contas" "6.2.9" \
            "Contas UID 0: $UID0" "Deixe apenas root com UID 0." \
            "Contas extras com UID 0 são root disfarçado — porta dos fundos clássica."
    fi
fi

# ---- Política de senha (login.defs) ------------------------------------------
if [ -r /etc/login.defs ]; then
    PMAX="$(grep -E '^\s*PASS_MAX_DAYS' /etc/login.defs 2>/dev/null | awk '{print $2}' | tail -1)"
    if printf '%s' "$PMAX" | grep -Eq '^[0-9]+$' && [ "$PMAX" -le 365 ]; then
        add_finding "pass-max-days-ok" "Expiração de senha configurada (${PMAX} dias)" "ok" "Segurança / Contas" "5.5.1.1" "PASS_MAX_DAYS $PMAX" "" ""
    elif printf '%s' "$PMAX" | grep -Eq '^[0-9]+$'; then
        add_finding "pass-max-days" "Senhas sem expiração adequada (${PMAX} dias)" "low" "Segurança / Contas" "5.5.1.1" \
            "PASS_MAX_DAYS $PMAX" "Defina PASS_MAX_DAYS 365 (ou menos)." \
            "Senhas que nunca expiram permanecem válidas indefinidamente se vazarem."
    fi
fi

# ---- Firewall: política padrão de entrada ------------------------------------
if have ufw; then
    UFWV="$($SUDO ufw status verbose 2>/dev/null)"
    if printf '%s' "$UFWV" | grep -qi "Status: active"; then
        if printf '%s' "$UFWV" | grep -qiE "deny \(incoming\)"; then
            add_finding "fw-default-deny-ok" "Firewall nega entrada por padrão" "ok" "Segurança / Rede" "3.5.1.7" "default deny (incoming)" "" ""
        else
            add_finding "fw-default-allow" "Firewall não nega entrada por padrão" "medium" "Segurança / Rede" "3.5.1.7" \
                "política de entrada não é deny" "Defina a política padrão de entrada para deny (ufw default deny incoming)." \
                "Sem negar por padrão, novos serviços ficam expostos automaticamente."
        fi
    fi
fi

# ---- Antimalware / rootkit ---------------------------------------------------
if have rkhunter || have chkrootkit || have clamscan; then
    RKNAME="$(have rkhunter && echo rkhunter || (have chkrootkit && echo chkrootkit || echo clamav))"
    add_finding "rootkit-tool-ok" "Ferramenta antimalware/rootkit presente ($RKNAME)" "ok" "Segurança / Malware" "" "$RKNAME instalado" "" ""
else
    add_finding "rootkit-tool-missing" "Sem ferramenta de detecção de rootkit/malware" "low" "Segurança / Malware" "" \
        "rkhunter/chkrootkit/clamav ausentes" "Considere instalar rkhunter ou chkrootkit." \
        "Sem varredura de rootkit, comprometimentos podem passar despercebidos."
fi

# ---- Hardening extra (sistema de arquivos, kernel, logs, senhas) -------------
# /tmp em partição separada
if have findmnt; then
    if findmnt -n /tmp >/dev/null 2>&1; then
        TMPOPTS="$(findmnt -no OPTIONS /tmp 2>/dev/null)"
        if printf '%s' "$TMPOPTS" | grep -q noexec; then
            add_finding "tmp-partition-ok" "/tmp isolado (partição própria com noexec)" "ok" "Segurança / Hardening" "1.1.2.1" "$TMPOPTS" "" ""
        else
            add_finding "tmp-partition" "/tmp separado, mas sem noexec" "low" "Segurança / Hardening" "1.1.2.1" \
                "opções: $TMPOPTS" "Adicione noexec,nosuid,nodev à montagem de /tmp." \
                "Sem noexec, um atacante pode executar binários gravados em /tmp."
        fi
    else
        add_finding "tmp-partition" "/tmp não é uma partição separada" "low" "Segurança / Hardening" "1.1.2.1" \
            "/tmp no mesmo sistema de arquivos que /" "Considere /tmp em partição/tmpfs própria com noexec,nosuid,nodev." \
            "Isolar /tmp limita o que um invasor consegue executar a partir de arquivos temporários."
    fi
fi

# Core dumps de binários SUID (fs.suid_dumpable)
SUIDDUMP="$(cat /proc/sys/fs/suid_dumpable 2>/dev/null)"
if [ "$SUIDDUMP" = "0" ]; then
    add_finding "kernel-suid-dumpable-ok" "Core dumps de SUID desativados" "ok" "Segurança / Hardening" "1.5.3" "fs.suid_dumpable=0" "" ""
elif [ -n "$SUIDDUMP" ]; then
    add_finding "kernel-suid-dumpable" "Core dumps de binários SUID permitidos" "low" "Segurança / Hardening" "1.5.3" \
        "fs.suid_dumpable=$SUIDDUMP" "Defina fs.suid_dumpable=0." \
        "Core dumps de processos privilegiados podem vazar segredos da memória."
fi

# Proteção contra SYN flood (tcp_syncookies)
SYNCK="$(cat /proc/sys/net/ipv4/tcp_syncookies 2>/dev/null)"
if [ "$SYNCK" = "1" ]; then
    add_finding "kernel-syncookies-ok" "Proteção contra SYN flood ativa" "ok" "Segurança / Rede" "3.2.8" "tcp_syncookies=1" "" ""
elif [ -n "$SYNCK" ]; then
    add_finding "kernel-syncookies" "Proteção contra SYN flood desativada" "low" "Segurança / Rede" "3.2.8" \
        "tcp_syncookies=$SYNCK" "Defina net.ipv4.tcp_syncookies=1." \
        "Sem SYN cookies, o servidor é mais vulnerável a negação de serviço (SYN flood)."
fi

# Logs persistentes (journald)
if [ -d /var/log/journal ]; then
    add_finding "logs-persistent-ok" "Logs do sistema persistentes (journald)" "ok" "Segurança / Logs" "4.2.1.1" "/var/log/journal presente" "" ""
else
    add_finding "logs-persistent" "Logs do sistema não persistem após reinício" "low" "Segurança / Logs" "4.2.1.1" \
        "/var/log/journal ausente" "Habilite logs persistentes: mkdir /var/log/journal." \
        "Sem persistência, os logs somem ao reiniciar — atrapalha investigação de incidentes."
fi

# Algoritmo de hash de senha + umask (login.defs)
if [ -r /etc/login.defs ]; then
    ENC="$(grep -E '^\s*ENCRYPT_METHOD' /etc/login.defs 2>/dev/null | awk '{print $2}' | tail -1)"
    case "$ENC" in
        SHA512|YESCRYPT) add_finding "pass-hash-ok" "Hash de senha forte ($ENC)" "ok" "Segurança / Contas" "5.4.1" "ENCRYPT_METHOD $ENC" "" "" ;;
        MD5|DES) add_finding "pass-hash" "Hash de senha fraco ($ENC)" "high" "Segurança / Contas" "5.4.1" \
            "ENCRYPT_METHOD $ENC" "Use SHA512 ou YESCRYPT." \
            "Hashes fracos (MD5/DES) são quebrados rapidamente se o /etc/shadow vazar." ;;
    esac
    UMASKV="$(grep -E '^\s*UMASK' /etc/login.defs 2>/dev/null | awk '{print $2}' | tail -1)"
    case "$UMASKV" in
        027|077) add_finding "umask-strict-ok" "umask padrão restritivo ($UMASKV)" "ok" "Segurança / Hardening" "5.5.5" "UMASK $UMASKV" "" "" ;;
        022|002|"") : ;;  # comum, mas frouxo — reporta só quando explicitamente frouxo
    esac
    if [ "$UMASKV" = "022" ] || [ "$UMASKV" = "002" ]; then
        add_finding "umask-loose" "umask padrão permissivo ($UMASKV)" "low" "Segurança / Hardening" "5.5.5" \
            "UMASK $UMASKV" "Defina UMASK 027 em /etc/login.defs." \
            "umask frouxo faz novos arquivos nascerem legíveis por outros usuários."
    fi
fi

# SSH: encaminhamento de TCP
if [ -n "${CFG_LC:-}" ]; then
    TCPFWD="$(printf '%s\n' "$CFG_LC" | grep -E '^\s*allowtcpforwarding' | awk '{print $2}' | tail -1)"
    if [ "$TCPFWD" = "no" ]; then
        add_finding "ssh-tcp-forward-ok" "Encaminhamento TCP do SSH desativado" "ok" "Segurança / SSH" "5.2.14" "AllowTcpForwarding no" "" ""
    elif [ "$TCPFWD" = "yes" ]; then
        add_finding "ssh-tcp-forward" "Encaminhamento TCP do SSH habilitado" "low" "Segurança / SSH" "5.2.14" \
            "AllowTcpForwarding yes" "Desative se não for necessário (AllowTcpForwarding no)." \
            "Túneis TCP por SSH podem ser usados para contornar controles de rede (pivoting)."
    fi
fi

# Kernel: hardening de rede (redirects / rp_filter)
NET_HARDENED=true; NET_EVID=""
for kv in "net.ipv4.conf.all.accept_redirects=0" "net.ipv4.conf.all.send_redirects=0" "net.ipv4.conf.all.rp_filter=1"; do
    key="${kv%=*}"; want="${kv#*=}"; path="/proc/sys/$(printf '%s' "$key" | tr '.' '/')"
    cur="$(cat "$path" 2>/dev/null)"
    [ -n "$cur" ] && [ "$cur" != "$want" ] && { NET_HARDENED=false; NET_EVID="$NET_EVID $key=$cur"; }
done
if [ "$NET_HARDENED" = true ]; then
    add_finding "kernel-net-ok" "Parâmetros de rede do kernel endurecidos" "ok" "Segurança / Rede" "3.3.1" "redirects/rp_filter ok" "" ""
else
    add_finding "kernel-net-hardening" "Parâmetros de rede do kernel frouxos" "low" "Segurança / Rede" "3.3.1" \
        "$(trim "$NET_EVID")" "Ajuste os sysctl de rede (accept_redirects=0, send_redirects=0, rp_filter=1)." \
        "ICMP redirects e ausência de filtro de rota facilitam spoofing e ataques na rede."
fi

# Kernel: vazamento de informação (kptr_restrict / dmesg_restrict)
KPTR="$(cat /proc/sys/kernel/kptr_restrict 2>/dev/null)"
DMESG="$(cat /proc/sys/kernel/dmesg_restrict 2>/dev/null)"
if [ "${KPTR:-0}" != "0" ] && [ "$DMESG" = "1" ]; then
    add_finding "kernel-info-leak-ok" "Kernel oculta ponteiros e restringe dmesg" "ok" "Segurança / Hardening" "1.5.1" "kptr_restrict=$KPTR dmesg_restrict=$DMESG" "" ""
elif [ -n "$KPTR" ] || [ -n "$DMESG" ]; then
    add_finding "kernel-info-leak" "Kernel expõe informação útil a atacantes" "low" "Segurança / Hardening" "1.5.1" \
        "kptr_restrict=${KPTR:-?} dmesg_restrict=${DMESG:-?}" "Defina kernel.kptr_restrict=1 e kernel.dmesg_restrict=1." \
        "Ponteiros do kernel e dmesg abertos ajudam a contornar proteções em exploração local."
fi

# Permissões de /etc/passwd e /etc/group (não podem ser graváveis por outros)
PW_PERM="$(stat -c '%a' /etc/passwd 2>/dev/null)"
GR_PERM="$(stat -c '%a' /etc/group 2>/dev/null)"
if printf '%s' "$PW_PERM" | grep -Eq '^[0-9]+$'; then
    PWLAST="${PW_PERM: -1}"; GRLAST="${GR_PERM: -1}"
    if [ "$PWLAST" -le 4 ] 2>/dev/null && [ "${GRLAST:-4}" -le 4 ] 2>/dev/null; then
        add_finding "etc-passwd-perms-ok" "/etc/passwd e /etc/group com permissões corretas" "ok" "Segurança / Contas" "6.1.2" "passwd=$PW_PERM group=$GR_PERM" "" ""
    else
        add_finding "etc-passwd-perms" "/etc/passwd ou /etc/group graváveis por outros" "high" "Segurança / Contas" "6.1.2" \
            "passwd=$PW_PERM group=$GR_PERM" "Ajuste para 644 root:root." \
            "Se usuários comuns editam passwd/group, podem criar contas e escalar privilégio."
    fi
fi

# Complexidade de senha (pwquality)
if [ -r /etc/security/pwquality.conf ]; then
    MINLEN="$(grep -E '^\s*minlen' /etc/security/pwquality.conf 2>/dev/null | grep -Eo '[0-9]+' | tail -1)"
    if printf '%s' "$MINLEN" | grep -Eq '^[0-9]+$' && [ "$MINLEN" -ge 14 ]; then
        add_finding "pass-complexity-ok" "Política de complexidade de senha definida (minlen $MINLEN)" "ok" "Segurança / Contas" "5.5.1" "minlen=$MINLEN" "" ""
    elif printf '%s' "$MINLEN" | grep -Eq '^[0-9]+$'; then
        add_finding "pass-complexity" "Comprimento mínimo de senha baixo (minlen $MINLEN)" "low" "Segurança / Contas" "5.5.1" \
            "minlen=$MINLEN" "Defina minlen 14 (e regras de complexidade) em pwquality.conf." \
            "Senhas curtas são quebradas por força-bruta com facilidade."
    fi
else
    add_finding "pass-complexity" "Sem política de complexidade de senha (pwquality)" "low" "Segurança / Contas" "5.5.1" \
        "pwquality.conf ausente" "Instale libpam-pwquality e defina minlen 14." \
        "Sem regras, usuários definem senhas fracas facilmente adivinháveis."
fi

# /var e /home em partições separadas
if have findmnt; then
    for MP in /var /home; do
        MPID="$(printf '%s' "$MP" | tr -d '/')"
        if findmnt -n "$MP" >/dev/null 2>&1; then
            add_finding "${MPID}-partition-ok" "$MP em partição separada" "ok" "Segurança / Hardening" "1.1" "$MP isolado" "" ""
        else
            add_finding "${MPID}-partition" "$MP não é uma partição separada" "low" "Segurança / Hardening" "1.1" \
                "$MP no mesmo sistema de arquivos que /" "Considere $MP em partição própria." \
                "Isolar $MP evita que o preenchimento dessa área derrube o sistema inteiro."
        fi
    done
fi

# Bloqueio de conta após tentativas falhas (PAM faillock/tally)
# Exige pam_faillock/tally2 REFERENCIADO no stack do PAM — a mera presença de
# /etc/security/faillock.conf (vem por padrão) não ativa bloqueio nenhum.
PAM_LOCK=false
# -R segue symlink: no RHEL o system-auth é symlink (authselect); -r não seguiria.
if grep -RlqE '^[^#]*pam_(faillock|tally2)\.so' /etc/pam.d 2>/dev/null; then PAM_LOCK=true; fi
if [ "$PAM_LOCK" = true ]; then
    add_finding "pam-lockout-ok" "Bloqueio de conta após tentativas falhas ativo" "ok" "Segurança / Contas" "5.4.2" "pam_faillock/tally configurado" "" ""
else
    add_finding "pam-lockout" "Sem bloqueio de conta após tentativas falhas" "low" "Segurança / Contas" "5.4.2" \
        "pam_faillock/tally2 não configurado" "Configure pam_faillock (deny=5, unlock_time=900)." \
        "Sem bloqueio, um atacante pode tentar senhas indefinidamente (força-bruta)."
fi

# Permissões de arquivos sensíveis (não podem ser graváveis por outros)
SENS_WW=""
for SF in /etc/ssh/sshd_config /etc/crontab /etc/sudoers /etc/passwd /etc/group /etc/shadow /etc/gshadow; do
    [ -e "$SF" ] || continue
    SP="$($SUDO stat -c '%a' "$SF" 2>/dev/null)"
    case "${SP: -1}" in 2|3|6|7) SENS_WW="$SENS_WW $SF" ;; esac
done
SENS_WW="$(trim "$SENS_WW")"
if [ -n "$SENS_WW" ]; then
    add_finding "sensitive-file-perms" "Arquivo(s) sensível(is) gravável(is) por outros" "high" "Segurança / Contas" "6.1" \
        "graváveis por 'outros': $SENS_WW" "Ajuste as permissões (ex.: chmod o-w) desses arquivos." \
        "Arquivos de sistema graváveis por qualquer usuário permitem escalonamento de privilégio."
else
    add_finding "sensitive-file-perms-ok" "Arquivos sensíveis com permissões adequadas" "ok" "Segurança / Contas" "6.1" "nenhum gravável por outros" "" ""
fi

# ---- TLS: validade de certificados + configuração (read-only) ----------------
# (A) Validade dos certificados encontrados no disco.
if have openssl; then
    CERT_FILES="$( { ls /etc/letsencrypt/live/*/fullchain.pem 2>/dev/null;
        grep -rhoE 'ssl_certificate[[:space:]]+[^;]+' /etc/nginx 2>/dev/null | awk '{print $2}' | tr -d ';';
        grep -rhoiE 'SSLCertificateFile[[:space:]]+\S+' /etc/apache2 /etc/httpd 2>/dev/null | awk '{print $2}'; } | sort -u )"
    NOW_EPOCH="$(date +%s)"
    while IFS= read -r CF; do
        [ -z "$CF" ] && continue
        END="$(openssl x509 -noout -enddate -in "$CF" 2>/dev/null | cut -d= -f2)"
        [ -z "$END" ] && END="$($SUDO openssl x509 -noout -enddate -in "$CF" 2>/dev/null | cut -d= -f2)"
        [ -z "$END" ] && continue
        EXP="$(date -d "$END" +%s 2>/dev/null)"
        [ -z "$EXP" ] && continue
        DAYS=$(( (EXP - NOW_EPOCH) / 86400 ))
        BN="$(basename "$(dirname "$CF")")/$(basename "$CF")"
        CID="$(printf '%s' "$CF" | tr -c 'A-Za-z0-9' '-')"
        if [ "$DAYS" -lt 0 ]; then
            add_finding "cert-expired-$CID" "Certificado TLS EXPIRADO ($BN)" "high" "Segurança / TLS" "" \
                "expirou há $(( -DAYS )) dias ($END)" "Renove o certificado imediatamente." \
                "Certificado expirado quebra HTTPS e passa insegurança/erro aos usuários e clientes."
        elif [ "$DAYS" -lt 30 ]; then
            add_finding "cert-expiring-$CID" "Certificado TLS expira em breve ($DAYS dias — $BN)" "medium" "Segurança / TLS" "" \
                "expira em $DAYS dias ($END)" "Renove/renove-automático o certificado (ex.: certbot renew)." \
                "Deixar o certificado expirar derruba o serviço e afeta a confiança do cliente."
        else
            add_finding "cert-ok-$CID" "Certificado TLS válido ($DAYS dias — $BN)" "ok" "Segurança / TLS" "" "expira em $DAYS dias" "" ""
        fi
    done <<< "$CERT_FILES"
fi

# (B) Protocolos TLS configurados no nginx/Apache (sem TLS 1.0/1.1).
if [ -d /etc/nginx ]; then
    NPROT="$(grep -rhoiE 'ssl_protocols[^;]*' /etc/nginx 2>/dev/null | tr 'A-Z' 'a-z' | tr '\n' ' ')"
    if [ -n "$NPROT" ]; then
        if printf '%s' "$NPROT" | grep -qE '(^| )tlsv1(\.1)?([^.0-9]|$)'; then
            add_finding "tls-weak-nginx" "nginx aceita TLS 1.0/1.1 (obsoleto)" "medium" "Segurança / TLS" "" \
                "$(trim "$NPROT")" "Use apenas ssl_protocols TLSv1.2 TLSv1.3." \
                "TLS 1.0/1.1 têm falhas conhecidas — dados em trânsito ficam mais expostos."
        else
            add_finding "tls-nginx-ok" "nginx usa apenas TLS moderno" "ok" "Segurança / TLS" "" "$(trim "$NPROT")" "" ""
        fi
    fi
fi
if [ -d /etc/apache2 ] || [ -d /etc/httpd ]; then
    APROT="$(grep -rhoiE 'SSLProtocol[^\n]*' /etc/apache2 /etc/httpd 2>/dev/null | tr 'A-Z' 'a-z' | tr '\n' ' ')"
    if printf '%s' "$APROT" | grep -qE 'tlsv1(\.1)?([^.0-9]|$)' && ! printf '%s' "$APROT" | grep -q '\-tlsv1'; then
        add_finding "tls-weak-apache" "Apache aceita TLS 1.0/1.1 (obsoleto)" "medium" "Segurança / TLS" "" \
            "$(trim "$APROT")" "Restrinja: SSLProtocol -all +TLSv1.2 +TLSv1.3." \
            "TLS 1.0/1.1 têm falhas conhecidas — dados em trânsito ficam mais expostos."
    fi
fi

# ---- Firewall ----------------------------------------------------------------
FW_ACTIVE=false; FW_RAW=""
if have ufw; then
    FW_RAW="$($SUDO ufw status verbose 2>/dev/null | head -25)"
    if printf '%s' "$FW_RAW" | grep -qi 'Status: active'; then FW_ACTIVE=true; fi
fi
if [ "$FW_ACTIVE" = false ] && have nft; then
    NFT_RAW="$($SUDO nft list ruleset 2>/dev/null | head -25)"
    [ -n "$NFT_RAW" ] && { FW_ACTIVE=true; FW_RAW="$NFT_RAW"; }
fi
if [ "$FW_ACTIVE" = true ]; then
    add_finding "firewall-ok" "Firewall ativo" "ok" "Segurança / Rede" "3.5.1" "" "" "" "$FW_RAW"
else
    add_finding "firewall-inactive" "Firewall inativo" "high" "Segurança / Rede" "3.5.1" \
        "ufw/nftables sem regras ativas" "Ative o firewall e libere só as portas necessárias." \
        "Sem firewall, qualquer serviço fica exposto na rede — superfície de ataque ampla." "$FW_RAW"
fi

# ---- fail2ban ----------------------------------------------------------------
if have systemctl && systemctl is-active fail2ban >/dev/null 2>&1; then
    add_finding "fail2ban-ok" "fail2ban ativo (proteção contra força-bruta)" "ok" "Segurança / SSH" "" "" "" ""
else
    add_finding "fail2ban-missing" "fail2ban ausente/inativo" "low" "Segurança / SSH" "" \
        "serviço fail2ban não está ativo" "Instale e ative o fail2ban." \
        "Sem fail2ban, tentativas de invasão por força-bruta não são bloqueadas automaticamente."
fi

# ---- Atualizações automáticas ------------------------------------------------
AUTO_UPD=false
# apt: unattended-upgrades · RHEL/dnf: dnf-automatic(.timer) / dnf-automatic-install.timer
if have systemctl && { systemctl is-enabled unattended-upgrades >/dev/null 2>&1 \
    || systemctl is-enabled dnf-automatic.timer >/dev/null 2>&1 \
    || systemctl is-enabled dnf-automatic-install.timer >/dev/null 2>&1; }; then AUTO_UPD=true; fi
if [ "$AUTO_UPD" = true ]; then
    add_finding "auto-updates-ok" "Atualizações de segurança automáticas ativas" "ok" "Atualizações" "" "" "" ""
else
    add_finding "auto-updates-missing" "Atualizações automáticas de segurança desativadas" "medium" "Atualizações" "" \
        "unattended-upgrades não habilitado" "Habilite as atualizações automáticas de segurança." \
        "Sem patch automático, falhas conhecidas ficam abertas por mais tempo."
fi

# ---- Atualizações pendentes --------------------------------------------------
if printf '%s' "${UPD_SECURITY:-}" | grep -Eq '^[0-9]+$' && [ "${UPD_SECURITY}" -gt 0 ]; then
    add_finding "updates-security-pending" "$UPD_SECURITY atualização(ões) de segurança pendente(s)" "high" "Atualizações" "" \
        "$UPD_SECURITY pacote(s) de segurança para atualizar" "Aplique as atualizações de segurança." \
        "Cada correção pendente é uma falha conhecida ainda aberta — risco direto de exploração."
elif printf '%s' "${UPD_TOTAL:-}" | grep -Eq '^[0-9]+$' && [ "${UPD_TOTAL}" -gt 0 ]; then
    add_finding "updates-pending" "$UPD_TOTAL atualização(ões) pendente(s)" "low" "Atualizações" "" \
        "$UPD_TOTAL pacote(s) para atualizar" "Aplique as atualizações." \
        "Sistema desatualizado acumula correções de estabilidade e segurança."
elif printf '%s' "${UPD_TOTAL:-}" | grep -Eq '^[0-9]+$'; then
    add_finding "updates-ok" "Sistema atualizado" "ok" "Atualizações" "" "" "" ""
fi

# ---- Fim de suporte do SO (EOL) ----------------------------------------------
if [ -n "$OS_EOL" ]; then
    TODAY="$(date -u +%Y-%m-%d)"
    if [ "$OS_EOL" \< "$TODAY" ]; then
        add_finding "os-eol" "Sistema operacional fora de suporte (EOL)" "critical" "Sistema operacional" "" \
            "${OS_PRETTY:-$OS_ID $OS_VERSION} — fim de suporte em $OS_EOL" \
            "Planeje a migração para uma versão com suporte." \
            "SO sem suporte não recebe mais patches de segurança = risco alto e não-conformidade."
    else
        add_finding "os-eol-ok" "Sistema operacional dentro do suporte" "ok" "Sistema operacional" "" \
            "Suporte até $OS_EOL" "" ""
    fi
fi

# ---- Portas expostas na rede -------------------------------------------------
if have ss; then
    SS_RAW="$($SUDO ss -tlnp 2>/dev/null | head -30)"
    [ -z "$SS_RAW" ] && SS_RAW="$(ss -tln 2>/dev/null | head -30)"
    EXPOSED="$(ss -tlnH 2>/dev/null | awk '{print $4}' | grep -E '^(0\.0\.0\.0|\*|\[::\]):' | sed -E 's/.*:([0-9]+)$/\1/' | sort -un | tr '\n' ' ')"
    EXPOSED="$(trim "$EXPOSED")"
    NON_SSH="$(printf '%s' "$EXPOSED" | tr ' ' '\n' | grep -v '^22$' | tr '\n' ' ')"
    NON_SSH="$(trim "$NON_SSH")"
    if [ -n "$NON_SSH" ]; then
        add_finding "exposed-ports" "Portas expostas na rede além do SSH" "medium" "Segurança / Rede" "" \
            "Escutando em todas as interfaces: $EXPOSED" \
            "Confirme se cada porta precisa estar exposta; restrinja por firewall o que for interno." \
            "Cada porta exposta é uma possível porta de entrada — reduza ao mínimo necessário." "$SS_RAW"
    else
        add_finding "exposed-ports-ok" "Nenhuma porta desnecessária exposta" "ok" "Segurança / Rede" "" \
            "Expostas: ${EXPOSED:-nenhuma}" "" "" "$SS_RAW"
    fi
fi

# =============================================================================
# LYNIS (opcional — reaproveita o motor reconhecido pelo mercado)
# =============================================================================
LYNIS_AVAILABLE=false; LYNIS_INDEX=""; LYNIS_WARN="[]"; LYNIS_SUG="[]"
if have lynis; then LYNIS_AVAILABLE=true; fi
REPORT="/var/log/lynis-report.dat"
# Roda o Lynis SÓ se pedido (UPTEND_RUN_LYNIS=1) — é lento. Caso contrário, aproveita
# um relatório já existente (ex.: rodado antes pelo Uptend) — sem re-executar.
if [ "$LYNIS_AVAILABLE" = true ] && [ "${UPTEND_RUN_LYNIS:-0}" = "1" ]; then
    $SUDO lynis audit system --quick --quiet >/dev/null 2>&1
fi
if [ "$LYNIS_AVAILABLE" = true ] && $SUDO test -r "$REPORT" 2>/dev/null; then
    LYNIS_INDEX="$($SUDO grep -E '^hardening_index=' "$REPORT" 2>/dev/null | tail -1 | cut -d= -f2)"
    # Warnings/suggestions: campos warning[]=... / suggestion[]=... (texto até o 1º '|').
    json_lines() {
        local out=""
        while IFS= read -r l; do
            [ -z "$l" ] && continue
            local txt="${l#*=}"; txt="${txt%%|*}"
            [ -z "$txt" ] && continue
            local q; q="$(jstr "$txt")"
            if [ -z "$out" ]; then out="$q"; else out="$out,$q"; fi
        done
        printf '[%s]' "$out"
    }
    LYNIS_WARN="$($SUDO grep -E '^warning\[\]=' "$REPORT" 2>/dev/null | json_lines)"
    LYNIS_SUG="$($SUDO grep -E '^suggestion\[\]=' "$REPORT" 2>/dev/null | json_lines)"
fi

# =============================================================================
# DOCKER — o que o servidor hospeda (containers)
# =============================================================================
DOCKER_INSTALLED=false; DOCKER_CONTAINERS=""; DOCKER_RUNNING=0; DOCKER_TOTAL=0; IMAGES=""
DCMD=""
if have docker; then
    if docker ps >/dev/null 2>&1; then DCMD="docker"
    elif [ "$MODE" = "admin" ] && $SUDO docker ps >/dev/null 2>&1; then DCMD="$SUDO docker"; fi
fi
if [ -n "$DCMD" ]; then
    DOCKER_INSTALLED=true
    while IFS='|' read -r cname cimage cstate cstatus; do
        [ -z "$cname" ] && continue
        DOCKER_TOTAL=$((DOCKER_TOTAL + 1))
        [ "$cstate" = "running" ] && DOCKER_RUNNING=$((DOCKER_RUNNING + 1))
        IMAGES="$IMAGES $cimage"
        OBJ="$(printf '{"name":%s,"image":%s,"state":%s,"status":%s}' \
            "$(jstr "$cname")" "$(jstr "$cimage")" "$(jstrn "$cstate")" "$(jstrn "$cstatus")")"
        if [ -z "$DOCKER_CONTAINERS" ]; then DOCKER_CONTAINERS="$OBJ"; else DOCKER_CONTAINERS="$DOCKER_CONTAINERS,$OBJ"; fi
    done <<< "$($DCMD ps -a --format '{{.Names}}|{{.Image}}|{{.State}}|{{.Status}}' 2>/dev/null)"
fi
IMAGES="$(printf '%s' "$IMAGES" | tr 'A-Z' 'a-z')"

# =============================================================================
# PERFIL DO SERVIDOR — para que ele está preparado (prontidão 0–100 por finalidade)
# =============================================================================
# Um "indício" pode ser um comando (cmd), imagem de container (img, regex), serviço
# systemd ativo (svc) ou nº de containers rodando (run).
sig_present() {
    case "$1" in
        cmd) have "$2" ;;
        img) printf '%s' "$IMAGES" | grep -Eqi "$2" ;;
        svc) have systemctl && systemctl is-active "$2" >/dev/null 2>&1 ;;
        run) [ "$DOCKER_RUNNING" -ge "$2" ] ;;
        *) return 1 ;;
    esac
}
PROFILE_PURPOSES=""; PROFILE_PRIMARY=""; PROFILE_BEST=-1
add_purpose() {
    # key label "tipo:padrao:Nome amigável;tipo:padrao:Nome;..."
    local key=$1 label=$2 spec=$3
    local present="" missing="" total=0 got=0 s stype rest pat friendly q
    local OLDIFS="$IFS"; IFS=';'
    for s in $spec; do
        IFS="$OLDIFS"
        [ -z "$s" ] && { IFS=';'; continue; }
        stype="${s%%:*}"; rest="${s#*:}"; pat="${rest%%:*}"; friendly="${rest#*:}"
        total=$((total + 1))
        if sig_present "$stype" "$pat"; then
            got=$((got + 1)); q="$(jstr "$friendly")"
            [ -z "$present" ] && present="$q" || present="$present,$q"
        else
            q="$(jstr "$friendly")"
            [ -z "$missing" ] && missing="$q" || missing="$missing,$q"
        fi
        IFS=';'
    done
    IFS="$OLDIFS"
    local score=0; [ "$total" -gt 0 ] && score=$(( got * 100 / total ))
    local obj="$(printf '{"key":%s,"label":%s,"score":%s,"present":[%s],"missing":[%s]}' \
        "$(jstr "$key")" "$(jstr "$label")" "$score" "$present" "$missing")"
    [ -z "$PROFILE_PURPOSES" ] && PROFILE_PURPOSES="$obj" || PROFILE_PURPOSES="$PROFILE_PURPOSES,$obj"
    if [ "$score" -gt "$PROFILE_BEST" ]; then PROFILE_BEST="$score"; PROFILE_PRIMARY="$label"; fi
}

add_purpose python "Aplicações Python" \
    "cmd:python3:Python 3;cmd:pip3:pip (pacotes);cmd:git:Git;img:python:Container Python"
add_purpose node "Aplicações Node.js" \
    "cmd:node:Node.js;cmd:npm:npm;cmd:git:Git;img:node:Container Node"
add_purpose containers "Plataforma de containers" \
    "cmd:docker:Docker;run:1:Containers em execução;run:3:Vários containers (3+)"
add_purpose database "Banco de dados" \
    "cmd:psql:Cliente PostgreSQL;img:postgres:Container PostgreSQL;img:redis:Container Redis;img:(mysql|mariadb):Container MySQL/MariaDB;img:mongo:Container MongoDB"
add_purpose web "Hospedagem web" \
    "cmd:nginx:nginx;cmd:apache2:Apache;img:nginx:Container nginx;img:(caddy|traefik):Proxy (Caddy/Traefik);img:httpd:Container Apache"
add_purpose security "Segurança e monitoramento" \
    "svc:fail2ban:fail2ban ativo;cmd:lynis:Lynis;svc:ufw:Firewall ufw;img:(wazuh|crowdsec|suricata):SIEM/IDS;img:(grafana|prometheus):Métricas (Grafana/Prometheus);img:uptime-kuma:Monitor de uptime"

# =============================================================================
# VERSÕES DE SOFTWARE (para cruzamento com CVE no Mac) — FASE C1
# Só executa `--version` local (leitura, sem rede). O cruzamento com a base de CVE
# acontece no Mac — o coletor nunca faz consulta externa.
# =============================================================================
SW_PACKAGES=""
add_sw() {   # nome versao
    [ -z "$2" ] && return
    local entry; entry="$(printf '{"name": %s, "version": %s, "source": "host"}' "$(jstr "$1")" "$(jstr "$2")")"
    if [ -z "$SW_PACKAGES" ]; then SW_PACKAGES="$entry"; else SW_PACKAGES="$SW_PACKAGES,$entry"; fi
}

# OpenSSH e OpenSSL (sshd -V / ssh -V escrevem em stderr: "OpenSSH_9.6p1, OpenSSL 3.0.13 ...")
SSH_VLINE=""
if have sshd; then SSH_VLINE="$(sshd -V 2>&1 | head -1)"; fi
[ -z "$SSH_VLINE" ] && have ssh && SSH_VLINE="$(ssh -V 2>&1 | head -1)"
add_sw openssh "$(printf '%s' "$SSH_VLINE" | sed -nE 's/.*OpenSSH_([0-9][0-9a-zA-Z._]*).*/\1/p')"
if have openssl; then
    add_sw openssl "$(openssl version 2>/dev/null | awk '{print $2}')"
else
    add_sw openssl "$(printf '%s' "$SSH_VLINE" | sed -nE 's/.*OpenSSL ([0-9][0-9a-zA-Z._]*).*/\1/p')"
fi

# Servidores web
if have nginx; then add_sw nginx "$(nginx -v 2>&1 | sed -nE 's|.*nginx/([0-9.]+).*|\1|p')"; fi
if have apache2; then add_sw apache "$(apache2 -v 2>&1 | sed -nE 's|.*Apache/([0-9.]+).*|\1|p')"
elif have httpd; then add_sw apache "$(httpd -v 2>&1 | sed -nE 's|.*Apache/([0-9.]+).*|\1|p')"; fi

# sudo e bash (--version não pede senha)
if have sudo; then add_sw sudo "$(sudo -V 2>/dev/null | sed -nE 's/.*version ([0-9][0-9a-z.p]*).*/\1/p' | head -1)"; fi
if have bash; then add_sw bash "$(bash --version 2>/dev/null | sed -nE 's/.*version ([0-9][0-9.]*).*/\1/p' | head -1)"; fi

# =============================================================================
# BANCOS DE DADOS — só ESTRUTURA (LGPD-safe) — FASE E4  [opt-in: UPTEND_DB_AUDIT=1]
# Lê APENAS information_schema (tabelas/colunas/tipos/PK). NUNCA consulta dados.
# PostgreSQL via peer auth (sudo -u postgres). O próprio Postgres monta o JSON.
# =============================================================================
DB_SCHEMAS=""
PG_OK=0
if [ "${UPTEND_DB_AUDIT:-0}" = "1" ] && have psql; then
    if [ -n "${UPTEND_PG_USER:-}" ]; then
        # Autenticação por SENHA (usuário informado no cadastro — senha via env, nunca em disco/log)
        export PGPASSWORD="${UPTEND_PG_PASSWORD:-}"
        PGH="${UPTEND_PG_HOST:-localhost}"; PGP="${UPTEND_PG_PORT:-5432}"; PGU="$UPTEND_PG_USER"
        pgq()     { psql -h "$PGH" -p "$PGP" -U "$PGU" -d "$1" -tAqc "$2" 2>/dev/null; }
        pgadmin() { psql -h "$PGH" -p "$PGP" -U "$PGU" -d "${UPTEND_PG_DB:-postgres}" -tAqc "$1" 2>/dev/null; }
        pgadmin "SELECT 1" >/dev/null 2>&1 && PG_OK=1
    elif id postgres >/dev/null 2>&1 && $SUDO -u postgres psql -tAqc "SELECT 1" >/dev/null 2>&1; then
        # Peer auth (admin local, sem senha)
        pgq()     { $SUDO -u postgres psql -d "$1" -tAqc "$2" 2>/dev/null; }
        pgadmin() { $SUDO -u postgres psql -tAqc "$1" 2>/dev/null; }
        PG_OK=1
    fi
fi
if [ "$PG_OK" = 1 ]; then
    PG_SQL="$(cat <<'PGSQL'
SELECT json_build_object('engine','PostgreSQL','name',current_database(),'tables',
  COALESCE((SELECT json_agg(json_build_object(
    'name', t.table_name,
    'columns', COALESCE((SELECT json_agg(json_build_object(
        'name', c.column_name, 'type', c.data_type,
        'notNull', (c.is_nullable='NO'),
        'primaryKey', COALESCE((SELECT true FROM information_schema.table_constraints tc
           JOIN information_schema.key_column_usage k ON k.constraint_name=tc.constraint_name AND k.table_schema=tc.table_schema
           WHERE tc.constraint_type='PRIMARY KEY' AND tc.table_schema=t.table_schema
             AND tc.table_name=t.table_name AND k.column_name=c.column_name LIMIT 1), false)
      ) ORDER BY c.ordinal_position)
      FROM information_schema.columns c
      WHERE c.table_schema=t.table_schema AND c.table_name=t.table_name), '[]'::json),
    'foreignKeyColumns', '[]'::json, 'indexedColumns', '[]'::json
   ) ORDER BY t.table_name)
   FROM information_schema.tables t
   WHERE t.table_type='BASE TABLE' AND t.table_schema NOT IN ('pg_catalog','information_schema')), '[]'::json));
PGSQL
)"
    # Se um banco específico foi informado, audita só ele; senão, todos os não-template.
    if [ -n "${UPTEND_PG_DB:-}" ]; then DBLIST="$UPTEND_PG_DB"
    else DBLIST="$(pgadmin "SELECT datname FROM pg_database WHERE datistemplate=false")"; fi
    while IFS= read -r DBN; do
        [ -n "$DBN" ] || continue
        OBJ="$(pgq "$DBN" "$PG_SQL" | tr -d '\n')"   # nome só como -d (nunca no SQL)
        case "$OBJ" in
            \{*\}) if [ -z "$DB_SCHEMAS" ]; then DB_SCHEMAS="$OBJ"; else DB_SCHEMAS="$DB_SCHEMAS,$OBJ"; fi ;;
        esac
    done <<EOF
$DBLIST
EOF
fi

# ---- MySQL / MariaDB (só ESTRUTURA) — peer auth (sudo mysql) ou senha (UPTEND_MY_*)
MY_OK=0
if [ "${UPTEND_DB_AUDIT:-0}" = "1" ] && have mysql; then
    if [ -n "${UPTEND_MY_USER:-}" ]; then
        export MYSQL_PWD="${UPTEND_MY_PASSWORD:-}"
        MYH="${UPTEND_MY_HOST:-localhost}"; MYP="${UPTEND_MY_PORT:-3306}"; MYU="$UPTEND_MY_USER"
        myq()  { mysql -h "$MYH" -P "$MYP" -u "$MYU" -N -B --raw -e "$1" 2>/dev/null; }
        # Consulta com um banco default ($1) — o nome vai como -D, NUNCA dentro do SQL.
        myqd() { mysql -h "$MYH" -P "$MYP" -u "$MYU" -D "$1" -N -B --raw -e "$2" 2>/dev/null; }
        myq "SELECT 1" >/dev/null 2>&1 && MY_OK=1
    elif $SUDO mysql -N -B -e "SELECT 1" >/dev/null 2>&1; then
        myq()  { $SUDO mysql -N -B --raw -e "$1" 2>/dev/null; }
        myqd() { $SUDO mysql -D "$1" -N -B --raw -e "$2" 2>/dev/null; }
        MY_OK=1
    fi
fi
if [ "$MY_OK" = 1 ]; then
    # SQL ESTÁTICO: o schema é sempre DATABASE() (o banco selecionado com -D), então
    # nenhum nome de banco é interpolado no SQL — sem injeção, sem furar o Modo Estrutura.
    MY_SQL="$(cat <<'MYSQL'
SELECT JSON_OBJECT('engine','MySQL','name',DATABASE(),'tables', IFNULL((SELECT JSON_ARRAYAGG(JSON_OBJECT('name',t.TABLE_NAME,'columns', IFNULL((SELECT JSON_ARRAYAGG(JSON_OBJECT('name',c.COLUMN_NAME,'type',c.DATA_TYPE,'notNull',(c.IS_NULLABLE='NO'),'primaryKey',(c.COLUMN_KEY='PRI'))) FROM information_schema.COLUMNS c WHERE c.TABLE_SCHEMA=DATABASE() AND c.TABLE_NAME=t.TABLE_NAME), JSON_ARRAY()),'foreignKeyColumns',JSON_ARRAY(),'indexedColumns',JSON_ARRAY())) FROM information_schema.TABLES t WHERE t.TABLE_SCHEMA=DATABASE() AND t.TABLE_TYPE='BASE TABLE'), JSON_ARRAY()))
MYSQL
)"
    if [ -n "${UPTEND_MY_DB:-}" ]; then MYLIST="$UPTEND_MY_DB"
    else MYLIST="$(myq "SELECT schema_name FROM information_schema.SCHEMATA WHERE schema_name NOT IN ('information_schema','mysql','performance_schema','sys')")"; fi
    while IFS= read -r MDB; do
        [ -n "$MDB" ] || continue
        OBJ="$(myqd "$MDB" "$MY_SQL" | tr -d '\n')"
        case "$OBJ" in
            \{*\}) if [ -z "$DB_SCHEMAS" ]; then DB_SCHEMAS="$OBJ"; else DB_SCHEMAS="$DB_SCHEMAS,$OBJ"; fi ;;
        esac
    done <<EOF
$MYLIST
EOF
fi

# =============================================================================
# MONTAGEM DO JSON
# =============================================================================
OUTFILE="$OUTDIR/uptend-audit-${HOSTNAME_VAL}-${STAMP}.json"

{
printf '{\n'
printf '  "schema_version": %s,\n' "$SCHEMA_VERSION"
printf '  "collector": {"name": %s, "version": %s, "mode": %s},\n' "$(jstr "$COLLECTOR_NAME")" "$(jstr "$COLLECTOR_VERSION")" "$(jstr "$MODE")"
printf '  "collected_at": %s,\n' "$(jstr "$COLLECTED_AT")"
printf '  "host": {"hostname": %s, "machine_id": %s},\n' "$(jstr "$HOSTNAME_VAL")" "$(jstrn "$MACHINE_ID")"
printf '  "machine": {"virtual": %s, "vendor": %s, "model": %s, "cpu_model": %s, "cpu_cores": %s, "ram_bytes": %s, "bios_vendor": %s, "bios_version": %s, "bios_date": %s},\n' \
    "$IS_VIRTUAL" "$(jstrn "$SYS_VENDOR")" "$(jstrn "$SYS_MODEL")" "$(jstrn "$CPU_MODEL")" "$(jnum "$CPU_CORES")" "$(jnum "$RAM_BYTES")" \
    "$(jstrn "$BIOS_VENDOR")" "$(jstrn "$BIOS_VERSION")" "$(jstrn "$BIOS_DATE")"
printf '  "os": {"distro": %s, "version": %s, "pretty": %s, "kernel": %s, "uptime_seconds": %s, "eol_date": %s, "updates_total": %s, "updates_security": %s},\n' \
    "$(jstrn "$OS_ID")" "$(jstrn "$OS_VERSION")" "$(jstrn "$OS_PRETTY")" "$(jstrn "$KERNEL")" "$(jnum "${UPTIME_SEC%%.*}")" \
    "$(jstrn "$OS_EOL")" "$(jnum "$UPD_TOTAL")" "$(jnum "$UPD_SECURITY")"
printf '  "disks": [%s],\n' "$DISKS"
printf '  "resources": {"disk_root_percent": %s, "disk_root_free_bytes": %s, "disk_root_total_bytes": %s, "swap_total_bytes": %s, "reboot_required": %s, "time_synced": %s},\n' \
    "$(jnum "$DROOT_PCT")" "$(jnum "$DROOT_FREE")" "$(jnum "$DROOT_TOTAL")" "$(jnum "$SWAP_TOTAL")" "$REBOOT_REQ" "$TIME_SYNCED"
printf '  "users": {"login_users": %s, "sudo_users": %s, "empty_password_users": %s},\n' \
    "$(jnum "$LOGIN_USERS")" "$SUDO_USERS_JSON" "$EMPTY_PW_JSON"
printf '  "docker": {"installed": %s, "running": %s, "total": %s, "containers": [%s]},\n' \
    "$DOCKER_INSTALLED" "$(jnum "$DOCKER_RUNNING")" "$(jnum "$DOCKER_TOTAL")" "$DOCKER_CONTAINERS"
printf '  "software": [%s],\n' "$SW_PACKAGES"
printf '  "databases": [%s],\n' "$DB_SCHEMAS"
printf '  "profile": {"primary": %s, "purposes": [%s]},\n' "$(jstrn "$PROFILE_PRIMARY")" "$PROFILE_PURPOSES"
printf '  "findings": [%s],\n' "$FINDINGS"
printf '  "lynis": {"available": %s, "hardening_index": %s, "warnings": %s, "suggestions": %s}\n' \
    "$LYNIS_AVAILABLE" "$(jnum "$LYNIS_INDEX")" "$LYNIS_WARN" "$LYNIS_SUG"
printf '}\n'
} > "$OUTFILE"

# ---- Hash (cadeia de custódia) ----------------------------------------------
HASH=""
if have sha256sum; then HASH="$(sha256sum "$OUTFILE" | awk '{print $1}')"; elif have shasum; then HASH="$(shasum -a 256 "$OUTFILE" | awk '{print $1}')"; fi
[ -n "$HASH" ] && printf '%s  %s\n' "$HASH" "$(basename "$OUTFILE")" > "$OUTFILE.sha256"

# ---- Resumo para o operador --------------------------------------------------
echo "Auditoria concluída (modo: $MODE)."
echo "Arquivo: $OUTFILE"
[ -n "$HASH" ] && echo "SHA-256: $HASH"
echo "UPTEND_AUDIT_FILE=$OUTFILE"
