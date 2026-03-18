#!/usr/bin/env sh
set -e

BASE="/home/assetto/server-manager"
REPO="/opt/acsm-repo"

# User aanmaken indien nodig
if ! id assetto >/dev/null 2>&1; then
  useradd -m -s /bin/sh assetto
fi

# Mappen aanmaken
mkdir -p "$BASE/assetto" "$BASE/servers"

# Binaries
install -Dm755 "$REPO/assetto-multiserver-manager" "$BASE/assetto-multiserver-manager"
if [ -f "$REPO/server-manager" ]; then
  install -Dm755 "$REPO/server-manager" "$BASE/server-manager"
else
  ln -sf assetto-multiserver-manager "$BASE/server-manager"
fi

# Licentie
[ -f /ACSM.License ] && cp -f /ACSM.License "$BASE/ACSM.License" || true

# Permissies — base directory + schrijfbare bestanden, skip read-only mounts
chown assetto:assetto "$BASE"
chown assetto:assetto "$BASE/assetto-multiserver-manager" "$BASE/server-manager" 2>/dev/null || true
[ -f "$BASE/ACSM.License" ] && chown assetto:assetto "$BASE/ACSM.License" 2>/dev/null || true
chown -R assetto:assetto "$BASE/assetto" "$BASE/servers" 2>/dev/null || true

# Start
exec su -s /bin/sh -c "$BASE/assetto-multiserver-manager" assetto
