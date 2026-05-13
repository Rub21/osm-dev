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
./deploy.sh gps_visibility      # another branch
./deploy.sh gps_db stop         # stop (keeps data)
./deploy.sh gps_db start        # restart stopped
```

URL: `https://<slug>.<your-ip>.nip.io` (slug = branch with `_` → `-`).

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