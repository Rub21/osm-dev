# OSM Development Setup

Run multiple openstreetmap-website branches in parallel. Each on its own HTTPS subdomain behind a shared Traefik proxy.

## Start the proxy (once)

this is only to server the website in the website

```bash
cd /apps/osm-dev/proxy && docker compose up -d
```

## Deploy a branch

```bash
cd /apps/osm-dev
./deploy.sh gpx-tracks                    # clone + build + up
./deploy.sh simplify-gps-visibility       # another branch
./deploy.sh gpx-tracks up <git-sha>       # deploy a specific commit instead of branch HEAD
./deploy.sh simplify-gps-visibility up --no-sync # build from the local working tree, keep local changes
./deploy.sh gpx-tracks stop               # stop (keeps data)
./deploy.sh simplify-gps-visibility stop -v      # stop and remove volumes
./deploy.sh gpx-tracks start              # restart stopped
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


## Per-branch overlays

Add inside `deploy.sh` `case "$BRANCH"`:

```bash
gpx-tracks) COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.gps.yaml" ;;
```

## Notes

- Host IP baked into nip.io. Change `NIP_DOMAIN` in `deploy.sh` if it moves.
- Ports 80/443 must be public for Let's Encrypt.

## Local development (your own machine)

```bash
export COMPOSE_FILE=docker-compose.yaml:docker-compose.local.yaml
docker compose up -d
docker compose logs -f web
docker compose exec web bash
```
