# acsm

Docker stack voor [Assetto Corsa Server Manager](https://github.com/JustaPenguin/assetto-server-manager) op [race.intersimcompetition.com](https://race.intersimcompetition.com).

## Releases

De `latest` release bevat twee soorten assets:

- **`acsm-stack.zip`** — automatisch gebouwd bij elke push naar `main` (docker-compose + entrypoint)
- **`acsm_vX_X_XX_linux-amd64.zip`** — ACSM binaries, manueel geüpload per versie

## Poorten

| Poort | Doel |
|-------|------|
| 8772 | ACSM web UI |
| 9601-9610 | AC server TCP/UDP |
| 8801-8810 | AC HTTP per server |

## Licentie

MIT
