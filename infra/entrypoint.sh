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

# Permissies — selectief, niet recursief over $BASE want config.yml/servers.yml
# zijn :ro bind mounts (chown faalt met "Read-only file system")
chown assetto:assetto "$BASE" \
  "$BASE/assetto-multiserver-manager" \
  "$BASE/server-manager"
[ -f "$BASE/ACSM.License" ] && chown assetto:assetto "$BASE/ACSM.License" || true
chown -R assetto:assetto \
  "$BASE/assetto" \
  "$BASE/servers" \
  "$BASE/shared_store.json"

# Start
exec su -s /bin/sh -c "$BASE/assetto-multiserver-manager" assetto
