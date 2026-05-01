#!/usr/bin/env sh
set -e

BASE="/home/assetto/server-manager"
REPO="/opt/acsm-repo"

# User aanmaken indien nodig (geen home dir = geen warnings)
if ! id -u assetto >/dev/null 2>&1; then
  useradd --no-create-home --shell /bin/sh --home-dir /nonexistent assetto
fi

# Mappenstructuur — incl. shared_store subdirs zodat ACSM watchers
# niet falen op fresh volume met "no such file or directory"
mkdir -p \
  "$BASE/assetto" \
  "$BASE/servers" \
  "$BASE/shared_store.json/accounts/groups" \
  "$BASE/shared_store.json/groups"

# Binaries
install -Dm755 "$REPO/assetto-multiserver-manager" "$BASE/assetto-multiserver-manager"
if [ -f "$REPO/server-manager" ]; then
  install -Dm755 "$REPO/server-manager" "$BASE/server-manager"
else
  ln -sf assetto-multiserver-manager "$BASE/server-manager"
fi

# Licentie
[ -f /ACSM.License ] && cp -f /ACSM.License "$BASE/ACSM.License" || true

# Eén chown -R over alles, dekt alle (mogelijk root-owned) volume mounts
chown -R assetto:assetto "$BASE"

# Start
exec su -s /bin/sh -c "$BASE/assetto-multiserver-manager" assetto
