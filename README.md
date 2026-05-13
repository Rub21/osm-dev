# OSM Dev

Run multiple openstreetmap-website branches in parallel, each on its own subdomain, behind a shared Traefik proxy with auto HTTPS.

## One-time: start the shared proxy

```bash
cd /apps/osm-dev/proxy
docker compose up -d
```

Traefik listens on 80/443, issues Let's Encrypt certs, and creates the `osm-proxy` network all instances join.

## Deploy an instance

```bash
cd /apps/osm-dev
./deploy.sh <branch> [up|start|stop]
```

Examples:

```bash
./deploy.sh gps_db                  # clone/pull + build + up
./deploy.sh gps_visibility          # same, for another branch
./deploy.sh gps_db stop             # stop containers (data preserved)
./deploy.sh gps_db start            # restart stopped containers
```

What `deploy.sh` does on `up`:

1. Clones `openstreetmap-website` into `/apps/instances/<branch>/openstreetmap-website` (or pulls if it already exists).
2. Derives a slug (`gps_db` → `gps-db`) and builds the public hostname `<slug>.204-168-153-175.nip.io`.
3. Exports `COMPOSE_PROJECT_NAME`, `DOCKER_NAME_PREFIX`, `BASE_REPO`, `DOMAIN_NAME` so containers, volumes, networks, and Traefik labels are prefixed per branch.
4. Runs `docker compose up -d --build`.
5. Prints the resulting URLs.

## Per-branch compose overlays

In `deploy.sh` there's a small `case "$BRANCH"` that adds extra compose files for branches that need them. Today:

```bash
gps_db) COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.gps.yaml"
```

So `gps_db` also gets the gps postgres + pgadmin (routed at `https://pgadmin-<DOMAIN_NAME>`). Add new entries here as branches need them.

## Layout

```
/apps/
├── osm-dev/
│   ├── proxy/                              shared Traefik (start once)
│   └── deploy.sh                           entry point
└── instances/
    └── <branch>/openstreetmap-website/     per-branch clone
```

## Files

- `docker-compose.yaml` — base stack (web, db, memcached). Parametrized via `${DOCKER_NAME_PREFIX}`, `${DOMAIN_NAME}`, `${BASE_REPO}`.
- `docker-compose.gps.yaml` — overlay for branches that need pgadmin + gps-db.
- `.env` — shared env (Rails creds, oauth, db password).
- `deploy.sh` — entry point. The only script you need.
- `start.sh` — container-side startup (DB restore, migrate, server boot).

## Notes

- Host IP `204.168.153.175` is encoded into nip.io subdomains. If it changes, update `NIP_DOMAIN` in `deploy.sh`.
- Ports 80 and 443 must be reachable from the public internet for Let's Encrypt to succeed.
- Each instance ≈ 1–2 GB RAM.
