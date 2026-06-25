#!/usr/bin/env bash
set -euo pipefail

# Dump the Postgres database of a deployed branch.
# The db container is named "<slug>-db", where slug = branch with "_" -> "-"
# (same convention as deploy.sh).

BRANCH="${1:-}"

if [[ -z "$BRANCH" ]]; then
  echo "usage: $0 <branch>" >&2
  echo "  example: $0 simplify-gps-visibility" >&2
  exit 1
fi

SLUG="${BRANCH//_/-}"            # gps_db -> gps-db
DB_CONTAINER="${SLUG}-db"

# Make sure the db container is actually running
if ! docker ps --format '{{.Names}}' | grep -qx "$DB_CONTAINER"; then
  echo "error: db container '$DB_CONTAINER' is not running" >&2
  echo "       deploy the branch first: ./deploy.sh $BRANCH up" >&2
  exit 1
fi

BACKUP_DIR="./backups"
mkdir -p "$BACKUP_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$BACKUP_DIR/${SLUG}-${STAMP}.dump"

echo "==> dumping $DB_CONTAINER -> $OUT"
# Use the container's own POSTGRES_* env vars so credentials stay in one place.
# -Fc = custom format (compressed); restore with restore_db.sh / pg_restore.
docker exec "$DB_CONTAINER" sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc --no-owner --no-acl' \
  > "$OUT"

echo "==> done: $OUT ($(du -h "$OUT" | cut -f1))"
echo "    restore with: ./restore_db.sh $BRANCH $OUT"
