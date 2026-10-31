#!/bin/bash
# GPS traces dump with planet-dump-ng, the same steps as the GPS part of
# chef planetdump.erb. Runs inside the planetdump container: make planet-dump PLANETDUMP=1
#
# 1. pg_dump of users, gpx_files and gpx_tracks into gps.dmp
# 2. planet-dump-ng -g writes the GPX file
# 3. md5 and "latest" link in PLANET_DIR
set -euo pipefail

: "${PGHOST:?set PGHOST, PGUSER and PGPASSWORD}"
SOURCE_DB="${SOURCE_DB:-openstreetmap}"
WORK_DIR="${WORK_DIR:-/tmp/planetdump}"
PLANET_DIR="${PLANET_DIR:-/data/gps}"
VISIBILITY="${VISIBILITY:-identifiable}"   # identifiable, trackable or "identifiable trackable"

year=$(date +%Y)
date=$(date +%y%m%d)
name="gpx-${date}.gpx.bz2"

tracks=$(psql -d "$SOURCE_DB" -tAc "SELECT count(*) FROM gpx_tracks")
echo "==> gpx_tracks has ${tracks} rows"
if (( tracks == 0 )); then
  echo "Error: gpx_tracks is empty, run the backfill first" >&2
  exit 1
fi

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "${PLANET_DIR}/${year}"
cd "$WORK_DIR"

echo "==> 1/3 pg_dump of the gps tables from ${SOURCE_DB}"
pg_dump --format=custom --data-only \
  --table=users --table=gpx_files --table=gpx_tracks \
  --file=gps.dmp "$SOURCE_DB"

echo "==> 2/3 planet-dump-ng -g (${VISIBILITY})"
read -ra visibility <<< "$VISIBILITY"
time planet-dump-ng -f gps.dmp -g "$name" --gpx-visibility "${visibility[@]}"
bzcat "$name" | xmllint --stream --noout -

echo "==> 3/3 publish"
mv "$name" "${PLANET_DIR}/${year}/${name}"
cd "$PLANET_DIR"
(cd "$year" && md5sum "$name" > "${name}.md5")
ln -fs "${year}/${name}" gpx-latest.gpx.bz2
sed -e "s/${name}/gpx-latest.gpx.bz2/" "${year}/${name}.md5" > gpx-latest.gpx.bz2.md5

rm -rf "$WORK_DIR"
echo "==> done: ${PLANET_DIR}/${year}/${name} ($(du -h "${year}/${name}" | cut -f1))"
