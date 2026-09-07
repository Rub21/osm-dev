# osm-dev

Docker setup for [openstreetmap-website](https://github.com/openstreetmap/openstreetmap-website).
Local: one instance with a full database. Server: several branches, each on its own HTTPS subdomain.
Same `make` targets for both; add `BRANCH=<branch>` for the server. `make` lists them.

## Local

Needs Docker, GNU make and the app repo at `../openstreetmap-website` (or `BASE_REPO=<path>`).

```bash
git clone git@github.com:Rub21/osm-dev.git && cd osm-dev
make up        # creates .env, builds, starts. First start restores the dump (a few minutes)
make logs
```

| what | where |
|------|-------|
| website | http://localhost:3000 |
| users | `admin` / `12345678`, `mapper1`, `mapper2`, `mapper3` / `12345678` |
| OAuth tokens | `.tokens/osmdev.json` |
| database | `localhost:54321`, `postgres` / `openstreetmap` |

```bash
make shell / console / psql
make down          # stop, keep the data
make clean         # delete the volumes
make up PGADMIN=1  # pgAdmin on http://localhost:5050 (admin@osm.org / admin)
```

## Server

Needs ports 80 and 443 open and `NIP_DOMAIN` + `ACME_EMAIL` in `.env`
(`203.0.113.10` -> `NIP_DOMAIN=203-0-113-10.nip.io`).

```bash
make proxy-up                                                     # once
make up BRANCH=gps_db REPO=Rub21/openstreetmap-website            # clone, build, start -> https://gps-db.<NIP_DOMAIN>
make up BRANCH=gps_db                                             # update to the branch head and rebuild
make up BRANCH=gps_db SHA=abc123                                  # one specific commit
make up BRANCH=gps_db NO_SYNC=1                                   # build the working tree as it is
make logs BRANCH=gps_db
make down BRANCH=gps_db                                           # stop, keep the data
make clean BRANCH=gps_db                                          # delete the volumes
make shell BRANCH=gps_db        # also console, psql, backup, restore
```

`REPO` is `owner/repo` on GitHub or a full git URL. Needed for the first clone; later it
changes the origin. `REPO_URL` in `.env` works as a default.
Code lives in `/apps/instances/<branch>/openstreetmap-website` (`INSTANCES_DIR` in `.env`).
Branches that need extra compose files get a `case` in `bin/deploy.sh`.
pgAdmin binds to `127.0.0.1` only: `ssh -L 5050:localhost:5050 <server>`.

## Backup and restore

```bash
make backup [BRANCH=gps_db]                                       # -> backups/<slug>-<date>.dump
make restore BACKUP_FILE=/backups/<slug>-<date>.dump [BRANCH=gps_db]
make restore                                                      # downloads BACKUP_FILE_URL again
```

`POST_RESTORE_SQL=/docker/<file>.sql` runs a SQL file after the restore, for branch specific clean-ups. Off by default.

## Files

| file | purpose |
|------|---------|
| `.env` | secrets and per machine values, not in git. `.env.example` works locally as is |
| `compose.yaml` | web, db, memcached, db_restore |
| `compose.local.yaml` / `compose.proxy.yaml` | local ports / Traefik and https |
| `compose.pgadmin.yaml` | optional pgAdmin |
| `proxy/compose.yaml` | shared Traefik proxy |
| `config/` | `database.yml`, `settings.local.yml`, `storage.yml` mounted into the app |
| `bin/deploy.sh` | used by make with `BRANCH=`: git sync, then compose with the branch env |
| `docker/entrypoint.sh` | web container start: restore if empty, migrate, users, tokens, server |
| `docker/restore-db.sh` | restore, used on first start and by `make restore` |
| `docker/post-start.sh` | branch specific jobs, runs only with `POST_START_SCRIPT` in `.env` |
| `scripts/` | users, tokens, GPX upload tool (`scripts/README.md`) |

`RAILS_STORAGE_SERVICE=local` stores files in a volume, `amazon` uses S3 (`AWS_*`).
`make lint` runs shellcheck and validates the compose files.
