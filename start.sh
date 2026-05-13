#!/usr/bin/env bash
workdir=/app
set -x

echo "Waiting for PostgreSQL to be ready..."
until pg_isready -h "$POSTGRES_HOST" -p 5432; do
  sleep 2
done


restore_db() {
  export PGPASSWORD="$POSTGRES_PASSWORD"
  export PAGER=cat
  curl -s -o backup.sql "$BACKUP_FILE_URL"
  psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f backup.sql
  rm backup.sql
}

#### Setting up required credentials
echo $RAILS_CREDENTIALS_YML_ENC > config/credentials.yml.enc
echo $RAILS_MASTER_KEY > config/master.key
chmod 600 config/credentials.yml.enc config/master.key


restore_db
bundle exec rails db:migrate --trace
bundle exec rails runner /docker/scripts/setup_users.rb
bundle exec rails runner /docker/scripts/generate_token.rb
bundle exec rails jobs:work &

while true; do
  bundle exec rails runner /docker/scripts/activate_pending.rb 2>/dev/null
  sleep 10
done &

bundle exec rails server -b 0.0.0.0 -p 3000
