#!/usr/bin/env bash
# Provisiona uma VM Debian/Ubuntu (apt) como laboratório de teste do auditor Uptend.
# Uso: provision-apt.sh <seguro|vuln>
set -u
MODE="${1:-seguro}"
export DEBIAN_FRONTEND=noninteractive
log() { echo "[$MODE] $*"; }

# ---------------------------------------------------------------- base comum
log "instalando base…"
sudo apt-get update -y -q >/dev/null 2>&1
sudo apt-get install -y -q openssh-server nginx docker.io ca-certificates curl ufw netcat-openbsd >/dev/null 2>&1
sudo systemctl enable --now ssh   >/dev/null 2>&1 || sudo systemctl enable --now sshd >/dev/null 2>&1
sudo systemctl enable --now nginx >/dev/null 2>&1
sudo systemctl enable --now docker >/dev/null 2>&1

rm -f /etc/ssh/sshd_config.d/zz-lab.conf 2>/dev/null

if [ "$MODE" = "vuln" ]; then
  # ============================ MÁQUINA VULNERÁVEL ============================
  log "aplicando brechas de segurança…"
  # SSH inseguro
  sudo tee /etc/ssh/sshd_config.d/zz-lab.conf >/dev/null <<'EOF'
PermitRootLogin yes
PasswordAuthentication yes
PermitEmptyPasswords yes
X11Forwarding yes
AllowTcpForwarding yes
MaxAuthTries 10
LoginGraceTime 120
EOF
  sudo systemctl restart ssh 2>/dev/null || sudo systemctl restart sshd 2>/dev/null

  # Firewall desligado
  sudo ufw --force disable >/dev/null 2>&1 || true
  sudo systemctl disable --now ufw >/dev/null 2>&1 || true

  # Sem atualização automática de segurança
  sudo systemctl disable --now unattended-upgrades >/dev/null 2>&1 || true
  sudo apt-get purge -y -q unattended-upgrades >/dev/null 2>&1 || true

  # AppArmor desativado (MAC off)
  sudo systemctl disable --now apparmor >/dev/null 2>&1 || true

  # Kernel frouxo
  sudo tee /etc/sysctl.d/99-lab-weak.conf >/dev/null <<'EOF'
kernel.randomize_va_space = 0
fs.suid_dumpable = 1
kernel.kptr_restrict = 0
kernel.dmesg_restrict = 0
net.ipv4.tcp_syncookies = 0
net.ipv4.conf.all.rp_filter = 0
EOF
  sudo sysctl --system >/dev/null 2>&1

  # sudo sem senha + segundo usuário UID 0
  echo 'labuser ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/90-lab-nopass >/dev/null
  sudo useradd -o -u 0 -g 0 -M -s /bin/bash backdoor 2>/dev/null || true

  # Senhas fracas / política ausente
  sudo sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS\t99999/' /etc/login.defs 2>/dev/null
  sudo sed -i 's/^UMASK.*/UMASK\t022/' /etc/login.defs 2>/dev/null

  # Permissões sensíveis frouxas
  sudo chmod 0644 /etc/shadow 2>/dev/null || true

  # Porta extra exposta (serviço "interno" ouvindo em 0.0.0.0)
  sudo tee /etc/systemd/system/lab-openport.service >/dev/null <<'EOF'
[Unit]
Description=Lab open port (teste)
[Service]
ExecStart=/bin/sh -c 'while true; do printf "HTTP/1.0 200 OK\r\n\r\nlab\r\n" | nc -l -p 8081 -q 1 2>/dev/null || sleep 2; done'
Restart=always
[Install]
WantedBy=multi-user.target
EOF
  sudo apt-get install -y -q netcat-openbsd >/dev/null 2>&1 || true
  sudo systemctl daemon-reload >/dev/null 2>&1
  sudo systemctl enable --now lab-openport >/dev/null 2>&1 || true

  # Docker com imagem antiga vulnerável (para o cruzamento de CVE)
  sudo docker pull nginx:1.18.0 >/dev/null 2>&1 && \
    sudo docker run -d --name web-legado -p 8080:80 nginx:1.18.0 >/dev/null 2>&1 || true

  # Brechas extras: senha vazia, /etc/passwd gravável, hash MD5, reinício pendente
  sudo useradd -m -s /bin/bash semsenha 2>/dev/null || true
  sudo passwd -d semsenha >/dev/null 2>&1
  sudo chmod o+w /etc/passwd 2>/dev/null || true
  [ -e /etc/crontab ] && sudo chmod o+w /etc/crontab 2>/dev/null || true
  sudo sed -i 's/^\s*ENCRYPT_METHOD.*/ENCRYPT_METHOD MD5/' /etc/login.defs 2>/dev/null
  grep -qE '^\s*ENCRYPT_METHOD' /etc/login.defs || echo 'ENCRYPT_METHOD MD5' | sudo tee -a /etc/login.defs >/dev/null
  sudo touch /var/run/reboot-required 2>/dev/null || true

  log "pronto (vulnerável)."

else
  # ============================ MÁQUINA SEGURA ===============================
  log "aplicando endurecimento (hardening)…"
  sudo apt-get install -y -q fail2ban auditd rkhunter unattended-upgrades apparmor-utils libpam-modules libpam-pwquality >/dev/null 2>&1
  # Complexidade de senha
  sudo tee /etc/security/pwquality.conf >/dev/null <<'CFG'
minlen = 14
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
CFG
  # nginx: só TLS 1.2/1.3
  sudo sed -i 's/^\(\s*\)ssl_protocols.*/\1ssl_protocols TLSv1.2 TLSv1.3;/' /etc/nginx/nginx.conf 2>/dev/null

  # SSH endurecido
  sudo tee /etc/ssh/sshd_config.d/zz-lab.conf >/dev/null <<'EOF'
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
X11Forwarding no
AllowTcpForwarding no
MaxAuthTries 3
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
  sudo systemctl restart ssh 2>/dev/null || sudo systemctl restart sshd 2>/dev/null

  # Firewall ligado, default deny
  sudo ufw --force reset >/dev/null 2>&1
  sudo ufw default deny incoming >/dev/null 2>&1
  sudo ufw default allow outgoing >/dev/null 2>&1
  sudo ufw allow 22/tcp >/dev/null 2>&1
  sudo ufw --force enable >/dev/null 2>&1

  # Serviços de segurança (fail2ban com backend systemd — Debian não tem /var/log/auth.log)
  printf '[DEFAULT]\nbackend = systemd\n[sshd]\nenabled = true\n' | sudo tee /etc/fail2ban/jail.local >/dev/null
  sudo systemctl enable --now fail2ban auditd >/dev/null 2>&1

  # Bloqueio de conta (pam_faillock real no stack do PAM)
  if ! grep -q pam_faillock /etc/pam.d/common-auth; then
    sudo sed -i '0,/^auth.*pam_unix\.so/s//auth\trequired\tpam_faillock.so preauth silent deny=5 unlock_time=900\n&/' /etc/pam.d/common-auth
    echo 'auth	[default=die]	pam_faillock.so authfail deny=5 unlock_time=900' | sudo tee -a /etc/pam.d/common-auth >/dev/null
  fi
  grep -q pam_faillock /etc/pam.d/common-account || echo 'account	required	pam_faillock.so' | sudo tee -a /etc/pam.d/common-account >/dev/null
  sudo systemctl enable --now unattended-upgrades >/dev/null 2>&1
  sudo systemctl enable --now apparmor >/dev/null 2>&1

  # Kernel endurecido
  sudo tee /etc/sysctl.d/99-lab-hard.conf >/dev/null <<'EOF'
kernel.randomize_va_space = 2
fs.suid_dumpable = 0
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
EOF
  sudo sysctl --system >/dev/null 2>&1

  # Política de senha e umask
  sudo sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS\t90/' /etc/login.defs 2>/dev/null
  sudo sed -i 's/^UMASK.*/UMASK\t027/' /etc/login.defs 2>/dev/null

  # Permissões corretas
  sudo chmod 0640 /etc/shadow 2>/dev/null || true
  sudo rm -f /etc/sudoers.d/90-lab-nopass 2>/dev/null

  # Atualiza o sistema
  sudo apt-get upgrade -y -q >/dev/null 2>&1 || true

  # Docker com imagem atual
  sudo docker pull nginx:stable >/dev/null 2>&1 && \
    sudo docker run -d --name web -p 127.0.0.1:8080:80 nginx:stable >/dev/null 2>&1 || true

  log "pronto (seguro)."
fi

# marca de partição /tmp (só informativo — OrbStack não separa /tmp)
mount | grep -q ' /tmp ' && echo "/tmp separado" || echo "/tmp no root (esperado no OrbStack)"
echo "=== versões colhíveis ==="
{ sshd -V 2>&1 | head -1; openssl version 2>/dev/null; nginx -v 2>&1; } | sed 's/^/  /'
