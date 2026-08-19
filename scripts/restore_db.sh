#!/usr/bin/env bash
# Download and restore the development database.
#
#   docker compose --profile restore run --rm db_restore
set -uo pipefail

export PGPASSWORD="$POSTGRES_PASSWORD"
until pg_isready -h "$POSTGRES_HOST" -q; do sleep 2; done

echo "Downloading $BACKUP_FILE_URL"
curl -fsSL -o /tmp/db.dump "$BACKUP_FILE_URL" || exit 1

echo "Restoring into $POSTGRES_DB"
pg_restore -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  --clean --if-exists --no-owner --no-acl /tmp/db.dump

# Delete not used 
psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<'SQL'
DROP TABLE IF EXISTS gpx_tracks;
DELETE FROM schema_migrations WHERE version = '20260810150000';
SQL
