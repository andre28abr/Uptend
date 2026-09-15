#!/usr/bin/env bash
# Instala e inicializa PostgreSQL (apt ou dnf) para o lab de auditoria de BD.
set -u
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get install -y -q postgresql >/dev/null 2>&1
  sudo systemctl enable --now postgresql >/dev/null 2>&1 || sudo service postgresql start >/dev/null 2>&1
else
  sudo dnf install -y -q postgresql-server postgresql >/dev/null 2>&1
  sudo ls /var/lib/pgsql/data/PG_VERSION >/dev/null 2>&1 || sudo postgresql-setup --initdb >/dev/null 2>&1
  sudo systemctl enable --now postgresql >/dev/null 2>&1
fi
for i in $(seq 1 10); do sudo -u postgres psql -tAqc "SELECT 1" >/dev/null 2>&1 && break; sleep 1; done
sudo -u postgres psql -tAqc "SELECT 1" >/dev/null 2>&1 && echo "postgres pronto" || echo "postgres FALHOU"
