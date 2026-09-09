#!/usr/bin/env bash
# Entrypoint of the web container.
set -euo pipefail
cd /app

echo "==> waiting for postgres at $POSTGRES_HOST"
until pg_isready -h "$POSTGRES_HOST" -q; do sleep 2; done

if [[ -n "${RAILS_CREDENTIALS_YML_ENC:-}" && -n "${RAILS_MASTER_KEY:-}" ]]; then
  printf '%s\n' "$RAILS_CREDENTIALS_YML_ENC" > config/credentials.yml.enc
  printf '%s\n' "$RAILS_MASTER_KEY" > config/master.key
  chmod 600 config/credentials.yml.enc config/master.key
fi

echo "==> bundle install"
bundle install

echo "==> seed database"
/docker/restore-db.sh --if-empty

echo "==> migrations, dev users and tokens"
bundle exec rails db:migrate --trace
bundle exec rails runner /scripts/setup_users.rb
bundle exec rails runner /scripts/generate_token.rb

if [[ -n "${POST_START_SCRIPT:-}" ]]; then
  echo "==> running $POST_START_SCRIPT"
  bash "$POST_START_SCRIPT" || echo "post-start script failed, continuing"
fi

echo "==> background jobs"
bundle exec rails jobs:work &

echo "==> rails server"
exec bundle exec rails server -b 0.0.0.0 -p 3000
