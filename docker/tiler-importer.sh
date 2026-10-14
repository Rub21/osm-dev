#!/bin/sh
# Consumer loop. First run: when the target database has no replication state,
# downloads the dump from TILER_DUMP_URL and imports it. Then applies the new
# files of OSMREP_FEED_URL every TILER_INTERVAL seconds.
set -eu
cd /osmrep
bundle install --quiet

until pg_isready -q -d "$OSMREP_TARGET"; do echo "tiler: waiting for the database"; sleep 3; done

if ! psql "$OSMREP_TARGET" -Atc "SELECT sequence FROM replication_state" 2>/dev/null | grep -q .; then
  if [ -n "${TILER_DUMP_URL:-}" ]; then
    echo "tiler: no replication state, importing ${TILER_DUMP_URL}"
    if curl -fsSL "$TILER_DUMP_URL" -o /tmp/dump.osm.bz2; then
      bundle exec bin/osmrep gpx import /tmp/dump.osm.bz2
      rm -f /tmp/dump.osm.bz2
    else
      echo "tiler: no dump at ${TILER_DUMP_URL} yet, starting from the current feed sequence"
    fi
  fi
fi

echo "tiler: following ${OSMREP_FEED_URL} every ${TILER_INTERVAL:-60}s"
while true; do
  bundle exec bin/osmrep gpx update --start 0 || echo "tiler: update failed, next try in ${TILER_INTERVAL:-60}s"
  sleep "${TILER_INTERVAL:-60}"
done
