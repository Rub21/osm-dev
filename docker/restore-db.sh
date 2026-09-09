#!/usr/bin/env bash
# Restore a dump into $POSTGRES_DB from BACKUP_FILE (path) or BACKUP_FILE_URL.
# Optional: POST_RESTORE_SQL. With --if-empty it does nothing when the users table exists.
set -euo pipefail

export PGPASSWORD="$POSTGRES_PASSWORD"
db() { psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"; }
has_users_table() { [[ -n "$(db -tAc "SELECT to_regclass('public.users')")" ]]; }

until pg_isready -h "$POSTGRES_HOST" -q; do sleep 2; done

if [[ "${1:-}" == "--if-empty" ]]; then
  if has_users_table; then
    echo "database already has data, skipping restore"
    exit 0
  fi
  if [[ -z "${BACKUP_FILE:-}" && -z "${BACKUP_FILE_URL:-}" ]]; then
    echo "BACKUP_FILE_URL not set, starting with an empty database"
    exit 0
  fi
fi

dump="${BACKUP_FILE:-}"
if [[ -z "$dump" ]]; then
  [[ -n "${BACKUP_FILE_URL:-}" ]] || { echo "error: set BACKUP_FILE or BACKUP_FILE_URL" >&2; exit 1; }
  dump=/tmp/backup.dump
  echo "==> downloading $BACKUP_FILE_URL"
  curl -fsSL -o "$dump" "$BACKUP_FILE_URL"
fi
[[ -f "$dump" ]] || { echo "error: dump not found: $dump" >&2; exit 1; }

echo "==> restoring $dump into $POSTGRES_DB"
# pg_restore returns 1 on ignored errors, so the result is checked with the users table.
pg_restore -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  --clean --if-exists --no-owner --no-acl "$dump" || true
has_users_table || { echo "error: restore failed, the users table is missing" >&2; exit 1; }

if [[ -n "${POST_RESTORE_SQL:-}" ]]; then
  echo "==> running $POST_RESTORE_SQL"
  db -v ON_ERROR_STOP=1 -f "$POST_RESTORE_SQL"
fi

[[ "$dump" == /tmp/* ]] && rm -f "$dump"
echo "==> restore done"
