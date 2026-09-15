#!/usr/bin/env bash
# Provisiona uma VM Fedora/Rocky (dnf) como laboratório de teste do auditor Uptend.
# Uso: provision-dnf.sh <seguro|vuln>
set -u
MODE="${1:-seguro}"
log() { echo "[$MODE] $*"; }
IS_FEDORA=0; grep -qi '^ID=fedora' /etc/os-release && IS_FEDORA=1

log "instalando base…"
[ "$IS_FEDORA" -eq 0 ] && sudo dnf install -y -q epel-release >/dev/null 2>&1
sudo dnf install -y -q openssh-server nginx firewalld curl nmap-ncat >/dev/null 2>&1
sudo systemctl enable --now sshd  >/dev/null 2>&1
sudo systemctl enable --now nginx >/dev/null 2>&1

sudo rm -f /etc/ssh/sshd_config.d/00-lab.conf 2>/dev/null

if [ "$MODE" = "vuln" ]; then
  # ============================ MÁQUINA VULNERÁVEL ============================
  log "aplicando brechas de segurança…"
  sudo tee /etc/ssh/sshd_config.d/00-lab.conf >/dev/null <<'EOF'
PermitRootLogin yes
PasswordAuthentication yes
PermitEmptyPasswords yes
X11Forwarding yes
AllowTcpForwarding yes
MaxAuthTries 10
LoginGraceTime 120
EOF
  sudo systemctl restart sshd 2>/dev/null

  sudo systemctl disable --now firewalld >/dev/null 2>&1 || true
  sudo setenforce 0 2>/dev/null || true
  sudo sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true

  sudo tee /etc/sysctl.d/99-lab-weak.conf >/dev/null <<'EOF'
kernel.randomize_va_space = 0
fs.suid_dumpable = 1
kernel.kptr_restrict = 0
kernel.dmesg_restrict = 0
net.ipv4.tcp_syncookies = 0
net.ipv4.conf.all.rp_filter = 0
EOF
  sudo sysctl --system >/dev/null 2>&1

  echo 'labuser ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/90-lab-nopass >/dev/null
  sudo useradd -o -u 0 -g 0 -M -s /bin/bash backdoor 2>/dev/null || true
  sudo sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS\t99999/' /etc/login.defs 2>/dev/null
  sudo sed -i 's/^UMASK.*/UMASK\t022/' /etc/login.defs 2>/dev/null
  sudo chmod 0644 /etc/shadow 2>/dev/null || true

  sudo tee /etc/systemd/system/lab-openport.service >/dev/null <<'EOF'
[Unit]
Description=Lab open port (teste)
[Service]
ExecStart=/bin/sh -c 'while true; do printf "HTTP/1.0 200 OK\r\n\r\nlab\r\n" | ncat -l 8081 2>/dev/null || sleep 2; done'
Restart=always
[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload >/dev/null 2>&1
  sudo systemctl enable --now lab-openport >/dev/null 2>&1 || true

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
  sudo dnf install -y -q fail2ban rkhunter audit dnf-automatic libpwquality >/dev/null 2>&1

  sudo tee /etc/ssh/sshd_config.d/00-lab.conf >/dev/null <<'EOF'
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
  sudo systemctl restart sshd 2>/dev/null

  sudo systemctl enable --now firewalld >/dev/null 2>&1
  sudo firewall-cmd --set-default-zone=drop >/dev/null 2>&1
  sudo firewall-cmd --permanent --zone=drop --add-service=ssh >/dev/null 2>&1
  sudo firewall-cmd --reload >/dev/null 2>&1

  sudo systemctl enable --now auditd >/dev/null 2>&1
  sudo systemctl enable --now fail2ban >/dev/null 2>&1
  sudo systemctl enable --now dnf-automatic.timer >/dev/null 2>&1

  # Bloqueio de conta (pam_faillock): Fedora via authselect; senão manual no system-auth
  if command -v authselect >/dev/null 2>&1; then
    sudo authselect enable-feature with-faillock >/dev/null 2>&1
    sudo authselect apply-changes >/dev/null 2>&1
  elif ! grep -q pam_faillock /etc/pam.d/system-auth; then
    sudo sed -i '0,/^auth.*pam_unix\.so/s//auth        required      pam_faillock.so preauth silent deny=5 unlock_time=900\n&/' /etc/pam.d/system-auth
    echo 'account     required      pam_faillock.so' | sudo tee -a /etc/pam.d/system-auth >/dev/null
  fi
  sudo setenforce 1 2>/dev/null || true
  sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config 2>/dev/null || true

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

  sudo tee /etc/security/pwquality.conf >/dev/null <<'EOF'
minlen = 14
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
EOF
  sudo sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS\t90/' /etc/login.defs 2>/dev/null
  sudo sed -i 's/^UMASK.*/UMASK\t027/' /etc/login.defs 2>/dev/null
  sudo chmod 0000 /etc/shadow 2>/dev/null || true
  sudo rm -f /etc/sudoers.d/90-lab-nopass 2>/dev/null
  sudo sed -i 's/^\(\s*\)ssl_protocols.*/\1ssl_protocols TLSv1.2 TLSv1.3;/' /etc/nginx/nginx.conf 2>/dev/null

  log "pronto (seguro)."
fi

echo "=== versões colhíveis ==="
{ /usr/sbin/sshd -V 2>&1 | head -1; openssl version 2>/dev/null; /usr/sbin/nginx -v 2>&1; } | sed 's/^/  /'
