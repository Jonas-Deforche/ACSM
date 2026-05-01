#!/usr/bin/env sh
set -e

BASE="/home/assetto/server-manager"
REPO="/opt/acsm-repo"
ASSETTO_UID=1000
ASSETTO_GID=1000

# Group + user aanmaken indien nodig — gebruik vaste UID/GID zodat chown
# altijd op nummer kan, ongeacht NSS lookup state
getent group assetto >/dev/null 2>&1 || groupadd -g "$ASSETTO_GID" assetto
getent passwd assetto >/dev/null 2>&1 || useradd \
  -u "$ASSETTO_UID" -g "$ASSETTO_GID" \
  --no-create-home --shell /bin/sh --home-dir /nonexistent assetto

# Mappenstructuur — pre-create alle subdirs die ACSM watchers anders missen.
# accounts/ + accounts/groups/ mogen leeg bestaan: bootstrap kijkt naar
# afwezigheid van admin.json (niet de dir) om default admin aan te maken.
mkdir -p \
  "$BASE/assetto" \
  "$BASE/servers" \
  "$BASE/shared_store.json/accounts/groups" \
  "$BASE/shared_store.json/groups" \
  "$BASE/shared_store.json/custom_races" \
  "$BASE/shared_store.json/championships" \
  "$BASE/shared_store.json/championships_meta" \
  "$BASE/shared_store.json/race_weekends"

# Binaries
install -Dm755 "$REPO/assetto-multiserver-manager" "$BASE/assetto-multiserver-manager"
if [ -f "$REPO/server-manager" ]; then
  install -Dm755 "$REPO/server-manager" "$BASE/server-manager"
else
  ln -sf assetto-multiserver-manager "$BASE/server-manager"
fi

# Licentie
[ -f /ACSM.License ] && cp -f /ACSM.License "$BASE/ACSM.License" || true

# Permissies — selectief (config.yml/servers.yml zijn :ro bind mounts).
# UID:GID notatie omzeilt elke NSS-lookup race condition.
chown "$ASSETTO_UID:$ASSETTO_GID" "$BASE" \
  "$BASE/assetto-multiserver-manager" \
  "$BASE/server-manager"
[ -f "$BASE/ACSM.License" ] && chown "$ASSETTO_UID:$ASSETTO_GID" "$BASE/ACSM.License" || true
chown -R "$ASSETTO_UID:$ASSETTO_GID" \
  "$BASE/assetto" \
  "$BASE/servers" \
  "$BASE/shared_store.json"

# Start
exec su -s /bin/sh -c "$BASE/assetto-multiserver-manager" assetto
