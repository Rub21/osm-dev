#!/bin/sh
# First run: when the database has no replication state, downloads the dump
# from DUMP_URL and imports it. Then applies the new files of the feed every
# INTERVAL seconds.
set -eu

until pg_isready -q -d "$GPXSYNC_DATABASE"; do echo "gpxsync: waiting for the database"; sleep 3; done

if ! psql "$GPXSYNC_DATABASE" -Atc "SELECT 1 FROM replication_state" 2>/dev/null | grep -q .; then
  if [ -n "${DUMP_URL:-}" ] && curl -fsSL "$DUMP_URL" -o /tmp/dump.osm.bz2; then
    echo "gpxsync: no replication state, importing ${DUMP_URL}"
    gpxsync import /tmp/dump.osm.bz2
    rm -f /tmp/dump.osm.bz2
  else
    echo "gpxsync: no dump at ${DUMP_URL:-DUMP_URL}, starting from the current feed sequence"
  fi
fi

echo "gpxsync: following ${GPXSYNC_FEED_URL} every ${INTERVAL:-60}s"
while true; do
  gpxsync update --start 0 || echo "gpxsync: update failed, next try in ${INTERVAL:-60}s"
  sleep "${INTERVAL:-60}"
done
