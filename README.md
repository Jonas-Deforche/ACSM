# ACSM

Laatst gesynct: 2026-07-09 (56e9b64)

Docker stack voor [Assetto Corsa Server Manager](https://github.com/JustaPenguin/assetto-server-manager) op [race.intersimcompetition.com](https://race.intersimcompetition.com). Beheert meerdere AC dedicated servers vanuit één web UI, met ondersteuning voor kampioenschappen, race weekends, custom races en accounts.

Deployt via Ansible vanuit [viraco-infra](../viraco-infra) op `vm-intersim-gameserver-01`.

> **Architectuur**: deze repo bevat enkel de **stack-config** (docker-compose + entrypoint + Traefik labels). De ACSM binaries worden los geüpload als release-assets en op de host gemount via `/opt/acsm-bins`. De licentie komt uit Ansible vault. Zie [Releases](#releases) voor het split-asset model.
>
> **Let op**: de `docker-compose.yml` in deze repo is de **basis-referentie**. Op de host wordt de compose **overschreven** door de Ansible-render van [`docker-compose.yml.j2`](../viraco-infra/roles/acsm/templates/docker-compose.yml.j2) uit de viraco-infra `acsm` role. Die gerenderde variant voegt toe: drie extra named volumes (`content_data`, `setups_data`, `manager_data`), een `apt-get install ca-certificates` vóór de entrypoint, en de **incident-plugin** container (zie onder). Uit de stack-zip wordt in de praktijk dus vooral `infra/entrypoint.sh` gebruikt.

---

## Repo layout

```
ACSM/
├── docker-compose.yml        # ubuntu:22.04 base, Traefik labels, named volumes
├── infra/
│   └── entrypoint.sh          # bootstrap: user/groep, dirs, chown, exec server
├── .github/workflows/
│   └── release.yml            # push naar main → upload acsm-stack.zip naar `latest`
├── README.md
└── LICENSE
```

`my-config/` (config.yml + servers.yml) wordt door Ansible gerenderd op de host vanuit Jinja-templates in de [viraco-infra `acsm` role](../viraco-infra/roles/acsm).

---

## Releases

De `latest` GitHub release bevat **twee soorten assets**:

| Asset | Bron | Wanneer ge-update |
|---|---|---|
| `acsm-stack.zip` | Auto-build door GitHub Actions | Elke push naar `main` |
| `acsm_vX_X_XX_linux-amd64.zip` | Manueel geüpload door maintainer | Per ACSM upstream-release |

Het splitsen voorkomt dat een stack-fix de binaries hoeft te re-uploaden. De Ansible role downloadt beide assets apart en kan zo onafhankelijk versies pinnen.

Werkflow voor een nieuwe ACSM versie:

1. Download `acsm_v2_X_XX_linux-amd64.zip` van [JustaPenguin/assetto-server-manager](https://github.com/JustaPenguin/assetto-server-manager/releases)
2. Upload naar de `latest` release (`gh release upload latest acsm_v2_X_XX_linux-amd64.zip`)
3. Op de gameserver: `cd /opt/viraco-infra && make acsm-update VERSION=2.X.XX`

---

## Stack architectuur

```
┌─────────────────────────────────────────────────────┐
│ vm-intersim-gameserver-01 (Debian 12)               │
│                                                     │
│  Traefik ─── HTTPS race.intersimcompetition.com ──┐ │
│                                                   │ │
│                                                   ▼ │
│  ┌────────────────────────────────────────────────┐│ │
│  │ acsm container (ubuntu:22.04)                  ││ │
│  │   /opt/acsm-repo:ro     ← /opt/acsm-bins      ││ │
│  │   /ACSM.License:ro      ← /opt/acsm-secrets   ││ │
│  │   config.yml, servers.yml ← my-config/ :ro    ││ │
│  │   shared_store.json     ← named volume        ││ │
│  │   assetto/              ← named volume        ││ │
│  │   servers/              ← named volume        ││ │
│  │   content/ setups/ manager/ ← named volumes   ││ │
│  │                                                ││ │
│  │   AC servers: 9601-9610 (TCP/UDP)              ││ │
│  │   ACSM web:   :8772 (intern, via Traefik)      ││ │
│  │   AC HTTP:    8801-8810 (per server)           ││ │
│  └────────────────────────────────────────────────┘│ │
│  ┌────────────────────────────────────────────────┐│ │
│  │ incident-plugin container (racecontrol edge)   ││ │
│  │   UDP :12001 ← AC server plugin-stream         ││ │
│  │   POST → racecontrol-API op web-01 (:9100)     ││ │
│  └────────────────────────────────────────────────┘│ │
└─────────────────────────────────────────────────────┘
```

### Volumes (persistent)

Named volumes overleven container recreates. **Enkel `docker compose down -v` wist data** — en dat is altijd een bewuste actie.

| Volume | Mountpoint | Inhoud |
|---|---|---|
| `assetto_data` | `/home/assetto/server-manager/assetto` | Cars, tracks, server configs (per AC server) |
| `servers_data` | `/home/assetto/server-manager/servers` | Per-server state, results, logs |
| `store_data` | `/home/assetto/server-manager/shared_store.json` | Accounts, championships, custom races, race weekends, groups |
| `content_data`* | `/home/assetto/server-manager/content` | Geüploade cars/tracks (persistent sinds 2026-05-02) |
| `setups_data`* | `/home/assetto/server-manager/setups` | Car setups |
| `manager_data`* | `/home/assetto/server-manager/manager` | Session/admin runtime data |

\* Enkel in de door Ansible gerenderde compose (prod), niet in de repo-compose.

> `shared_store.json` is een **directory**, geen file. ACSM gebruikt het als Bleve key-value store met subdirs per type. Daarom werkt het als named volume.

### Read-only bind mounts

| Host pad | Container pad | Bron |
|---|---|---|
| `/opt/acsm-bins` | `/opt/acsm-repo:ro` | Binaries (geünzipte release asset) |
| `/opt/acsm-secrets/ACSM.License` | `/ACSM.License:ro` | Licentie uit Ansible vault |
| `./my-config/config.yml` | `/home/assetto/server-manager/config.yml:ro` | Door Ansible gerenderd |
| `./my-config/servers.yml` | `/home/assetto/server-manager/servers.yml:ro` | Door Ansible gerenderd |
| `./infra/entrypoint.sh` | `/opt/infra/entrypoint.sh:ro` | Bootstrap script |

---

## Entrypoint

`infra/entrypoint.sh` doet bij elke container start:

1. **User/groep** — maakt `assetto` aan met vaste UID:GID `1000:1000` (NSS-lookup race-safe)
2. **Subdir pre-create** — `assetto/`, `servers/`, `content/`, `setups/`, `manager/` + alle `shared_store.json/<type>/` subdirs **behalve `accounts/`**. De afwezigheid van `accounts/` triggert bootstrap van de default admin (`admin` / `servermanager`).
3. **Binary install** — kopieert `assetto-multiserver-manager` van `/opt/acsm-repo` naar `$BASE`; `server-manager` wordt mee gekopieerd of anders gesymlinkt naar de multiserver-binary
4. **License** — kopieert `/ACSM.License` als die bestaat
5. **Chown** — recursief op de schrijfbare paden, **niet** op `:ro` bind mounts (anders foutje)
6. **Exec** — `su -s /bin/sh -c "$BASE/assetto-multiserver-manager" assetto`

> Belangrijk: pre-create van `accounts/` is bewust uitgezet — ACSM detecteert "fresh install" door de **afwezigheid** van die directory en bootstrapt anders niet de default admin.

---

## Poorten

| Poort | Doel |
|---|---|
| `8772/tcp` | ACSM web UI (intern, via Traefik geëxposeerd op HTTPS) |
| `9601-9610/tcp+udp` | AC server slots (10 parallel servers) |
| `8801-8810/tcp` | AC HTTP API per server |

De Traefik labels in `docker-compose.yml` routeren `${ACSM_RULE}` (bv. `Host(\`race.intersimcompetition.com\`)`) naar `acsm:8772` met automatische Let's Encrypt cert via `leresolver`.

---

## Incident-plugin (racecontrol)

De gerenderde compose draait naast ACSM ook de **incident-plugin** uit de [intersimcompetition-racecontrol](https://github.com/Jonas-Deforche/intersimcompetition-racecontrol) mono-repo (image `ghcr.io/jonas-deforche/intersimcompetition-racecontrol/server`, versie gepind in de role defaults):

- Vast IP `172.18.0.250` op het `proxy`-net — de AC `server_cfg.ini`'s forwarden hun UDP-plugin-stream hard naar dat IP op `:12001`, dus het mag nooit wijzigen
- Detecteert botsingen en post events naar de racecontrol-API op web-01 (`:9100` intern)
- Traefik routeert `racecontrol.intersimcompetition.com` / `incidents.intersimcompetition.com` naar `:8090` van deze container
- Secrets via `incident-plugin.env` (door Ansible gerenderd uit vault)

---

## Eerste login

Na fresh deploy:
- **URL**: `https://race.intersimcompetition.com/`
- **User**: `admin`
- **Wachtwoord**: `servermanager`

Direct na login: wachtwoord wijzigen via Account → Change password. Pre-creating van `accounts/` zou deze bootstrap blokkeren.

---

## Deploy commando's

Vanuit [viraco-infra](../viraco-infra):

```bash
make acsm-deploy                        # Deploy met de gepinde versie (role default, bv. 2.4.14)
make acsm-update VERSION=2.4.14         # Upgrade naar specifieke versie
make acsm-downgrade VERSION=2.4.10      # Downgrade (vereist -e acsm_allow_downgrade=true, zit in het make-target)
make acsm-configure                     # Patch per-server data (names, ports, passwords, branding) — opt-in
```

De role:
1. Downloadt `acsm-stack.zip` (de stack-config) en `acsm_vX_X_XX_linux-amd64.zip` (de binaries) van de `latest` GitHub release; een `VERSION.txt`-marker in `/opt/acsm-bins` voorkomt onbedoelde downgrades en overbodige re-downloads
2. Unzipt binaries naar `/opt/acsm-bins`, schrijft licentie naar `/opt/acsm-secrets/ACSM.License` (uit vault `acsm_license_content`)
3. Rendert `docker-compose.yml` (overschrijft de compose uit de stack-zip), `config.yml` en `servers.yml` vanuit Jinja templates naar `/opt/acsm` resp. `my-config/`
4. Compose recreate (named volumes blijven, dus geen data loss)

---

## Backup

`store_data`, `servers_data`, `content_data`, `setups_data` en `manager_data` worden dagelijks om 03:00 gebackupt door de `ops_backup` role op vm-intersim-gameserver-01 (`assetto_data` wordt **niet** gebackupt):
- 3 dagen lokaal in `/opt/backups/`
- 90 dagen op Google Drive via rclone

Restore: `sudo viraco-restore acsm_store_data <backup-bestand>`. Zie [viraco-infra README](../viraco-infra#backups-en-monitoring).

---

## Licentie

[MIT](LICENSE) voor de stack-config in deze repo. ACSM zelf heeft een eigen licentie (zie upstream).
