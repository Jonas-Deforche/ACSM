#!/usr/bin/env sh
set -e

BASE="/home/assetto/server-manager"
REPO="/opt/acsm-repo"

# CA certificates (nodig voor GeoIP, CSP Weather en andere TLS calls vanuit de container)
apt-get update -qq
apt-get install -y --no-install-recommends ca-certificates
rm -rf /var/lib/apt/lists/*

# User aanmaken indien nodig
if ! id assetto >/dev/null 2>&1; then
  useradd -m -s /bin/sh assetto
fi

# Mappen aanmaken
mkdir -p "$BASE/assetto" "$BASE/servers"

# shared_store.json — moet een map zijn
mkdir -p "$BASE/shared_store.json"

# Binaries
install -Dm755 "$REPO/assetto-multiserver-manager" "$BASE/assetto-multiserver-manager"
if [ -f "$REPO/server-manager" ]; then
  install -Dm755 "$REPO/server-manager" "$BASE/server-manager"
else
  ln -sf assetto-multiserver-manager "$BASE/server-manager"
fi

# Licentie
[ -f /ACSM.License ] && cp -f /ACSM.License "$BASE/ACSM.License" || true

# Permissies
chown assetto:assetto "$BASE"
chown assetto:assetto \
  "$BASE/assetto-multiserver-manager" \
  "$BASE/server-manager" \
  "$BASE/shared_store.json"
[ -f "$BASE/ACSM.License" ] && chown assetto:assetto "$BASE/ACSM.License" || true
chown -R assetto:assetto "$BASE/assetto" "$BASE/servers"

# Start
exec su -s /bin/sh -c "$BASE/assetto-multiserver-manager" assetto