# OSM Development Setup

Run multiple openstreetmap-website branches in parallel. Each on its own HTTPS subdomain behind a shared Traefik proxy.

## Start the proxy (once)

```bash
cd /apps/osm-dev/proxy && docker compose up -d
```

## Deploy a branch

```bash
cd /apps/osm-dev
./deploy.sh gps_db              # clone + build + up
./deploy.sh simplify-gps-visibility      # another branch
./deploy.sh gps_db up <git-sha> # deploy a specific commit instead of branch HEAD
./deploy.sh gps_db stop         # stop (keeps data)
./deploy.sh simplify-gps-visibility stop -v      # stop and remove volumes
./deploy.sh gps_db start        # restart stopped
```

By default `up` deploys the branch HEAD. Pass an optional git sha as the 3rd
argument to deploy a specific commit (checked out detached) — useful to roll
back to a previous version:

```bash
./deploy.sh simplify-gps-visibility up caaef96cd569e0599da60c4678eb9af070c50f45
```

URL: `https://<slug>.<your-ip>.nip.io` (slug = branch with `_` → `-`).

## Backup / restore database

Dump a branch's Postgres db (custom format, into `./backups/`):

```bash
./backup_db.sh simplify-gps-visibility
```

Restore a dump into a branch's db:

```bash
./restore_db.sh simplify-gps-visibility backups/simplify-gps-visibility-20260625-205120.dump
```

## Layout

```
/apps/
├── osm-dev/
│   ├── proxy/         shared Traefik
│   ├── deploy.sh      entry point
│   ├── docker-compose.yaml
│   ├── docker-compose.gps.yaml   overlay (gps-db + pgadmin)
│   └── start.sh       container boot
└── instances/<branch>/openstreetmap-website/   per-branch clone
```

## Per-branch overlays

Add inside `deploy.sh` `case "$BRANCH"`:

```bash
gps_db) COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.gps.yaml" ;;
```

## Notes

- Host IP baked into nip.io. Change `NIP_DOMAIN` in `deploy.sh` if it moves.
- Ports 80/443 must be public for Let's Encrypt.
- Each instance ≈ 1–2 GB RAM.