#!/usr/bin/env bash
# Run osm-website tests in docker compose.
# Usage: ./test.sh [rails test args]
#   ./test.sh                                       # full suite
#   ./test.sh test/controllers/api/traces_controller_test.rb
#   ./test.sh test/controllers/api/traces_controller_test.rb:109

set -e

DB_URL="postgres://postgres:openstreetmap@db:5432/osm_test"

docker compose exec db psql -U postgres -d postgres -c "DROP DATABASE IF EXISTS osm_test;"
docker compose exec db psql -U postgres -d postgres -c "DROP DATABASE IF EXISTS osm_test_gps;"
docker compose exec db psql -U postgres -d postgres -c "CREATE DATABASE osm_test;"
docker compose exec db psql -U postgres -d postgres -c "CREATE DATABASE osm_test_gps;"

docker compose exec -e DATABASE_URL="$DB_URL" -e RAILS_ENV=test web \
  bundle exec rails db:schema:load

if [ "$#" -eq 0 ]; then
  docker compose exec -e DATABASE_URL="$DB_URL" -e RAILS_ENV=test web \
    bundle exec rails test:all
else
  docker compose exec -e DATABASE_URL="$DB_URL" -e RAILS_ENV=test web \
    bundle exec rails test "$@"
fi
