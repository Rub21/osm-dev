# OSM Dev

Local development setup for openstreetmap-website. Supports a single instance for local work, or many parallel instances (one per PR/branch) routed via a shared HTTPS reverse proxy.

## Single instance (default)

```bash
cd osm-dev
docker compose build
docker compose up
```

Without `.env.instance`, the Traefik labels fall back to `localhost`. If no shared proxy is running, ignore the labels and add `ports: [3000:3000]` to the `web` service for direct access, then visit http://localhost:3000.

## Multiple instances (one per PR/branch)

### One-time: start the shared proxy

The shared proxy lives at `./proxy/`. It runs Traefik on ports 80/443 and obtains HTTPS certs from Let's Encrypt.

```bash
cd proxy
docker compose up -d
```

This creates a docker network named `osm-proxy` that all instances join.

### Per instance

Use the helper script:

```bash
./spawn-instance.sh db-repair pr/db-repair-branch
./spawn-instance.sh simplify pr/visibility-simplify-branch
```

This creates `../instances/<slug>/` with its own clone of `openstreetmap-website` (checked out to the given branch) and a copy of `osm-dev/` with `.env.instance` pre-filled.

Then bring it up:

```bash
cd ../instances/db-repair/osm-dev
docker compose --env-file .env --env-file .env.instance up -d --build
```

Resulting URLs (HTTPS, auto cert):

- https://db-repair.204-168-242-139.nip.io
- https://simplify.204-168-242-139.nip.io

Each instance has isolated database, memcached, and storage volumes.

### Manual instance setup (without the helper)

1. Clone openstreetmap-website checked out at the branch you want.
2. Copy this `osm-dev/` folder next to it.
3. In the copy, create `.env.instance` (see `.env.instance.example`):

```bash
COMPOSE_PROJECT_NAME=osm-<slug>
INSTANCE_NAME=<slug>
INSTANCE_HOST=<slug>.<host-ip-with-dashes>.nip.io
```

4. `docker compose --env-file .env --env-file .env.instance up -d --build`

## Configuration files

- `config/database.yml` — Database connection
- `config/settings.local.yml` — App settings (overrides `settings.yml`)
- `config/storage.yml` — Storage config
- `.env` — Shared environment variables (rails creds, oauth, etc)
- `.env.instance` — Per-instance overrides (project name, host). Not in single-instance mode.
- `start.sh` — Startup script (restores DB, migrations, server)

## GPS overlay (gps-db + pgadmin)

```bash
docker compose -f docker-compose.yaml -f docker-compose.gps.yaml --env-file .env --env-file .env.instance up -d --build
```

pgadmin is routed at `https://pgadmin-<INSTANCE_HOST>` via Traefik.

## Stop / clean up

```bash
docker compose --env-file .env --env-file .env.instance down          # stop, keep volumes
docker compose --env-file .env --env-file .env.instance down -v       # stop, delete DB
```

## Notes

- Host IP `204-168-242-139` is encoded into nip.io subdomains. If your public IP changes, update `INSTANCE_HOST` in each `.env.instance`.
- Ports 80 and 443 must be reachable from the public internet for Let's Encrypt HTTP-01 challenges to succeed.
- Each instance ≈ 1-2 GB RAM. Plan host capacity accordingly.
- `config/settings.local.yml` currently hardcodes `server_url: localhost:3000`. For HTTPS instances, override per copy if you need correct absolute URLs in emails / OAuth callbacks.
