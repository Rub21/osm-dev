#!/bin/bash
# Full dump of the GPS traces for osm-dev, the way planetdump does it for the map data.
# Runs inside the osmrep container: make gpx-dump OSMREP=1
#
# 1. pg_dump of the gpx tables into one .dmp file (custom format, data only)
# 2. osmrep gpx dump reads that file and writes the XML, no database needed
# 3. md5, "latest" link and optional copy to S3, like planet-notes-dump
#
# The dump is .osm.bz2 like the planet and notes dumps.
#
# The production database is only touched in step 1. Settings come from the
# environment, the defaults are the paths used on the planet server.
set -euo pipefail

OSMREP_CONFIG="${OSMREP_CONFIG:-config.yaml}"  # database and content_visibilities

# Source database: PGHOST, PGPORT, PGUSER, PGPASSWORD and SOURCE_DB from the
# environment, or when PGHOST is not set, the database URL of the config file.
if [[ -z "${PGHOST:-}" ]]; then
  eval "$(ruby -ryaml -ruri -e '
    url = URI(YAML.safe_load_file(ARGV[0]).fetch("database"))
    puts "PGHOST=#{url.host.inspect} PGPORT=#{(url.port || 5432)} PGUSER=#{URI.decode_www_form_component(url.user.to_s).inspect} PGPASSWORD=#{URI.decode_www_form_component(url.password.to_s).inspect} SOURCE_DB=#{url.path.delete_prefix("/").inspect}"
  ' "$OSMREP_CONFIG")"
  export PGHOST PGPORT PGUSER PGPASSWORD
fi
: "${PGHOST:?set PGHOST, PGUSER and PGPASSWORD, or database in ${OSMREP_CONFIG}}"
SOURCE_DB="${SOURCE_DB:-openstreetmap}"
WORK_DIR="${WORK_DIR:-/store/planetdump}"
PLANET_DIR="${PLANET_DIR:-/store/planet/gps}"
S3_DIR="${S3_DIR:-}"                       # for example s3://osm-planet-eu-central-1/gps/osm
AWS="${AWS:-/opt/awscli/v2/current/bin/aws}"
AWS_PROFILE_NAME="${AWS_PROFILE_NAME:-osm-pds-upload}"
MIN_SIZE="${MIN_SIZE:-1000}"               # bytes, the dump is refused when smaller
JOBS="${JOBS:-$(nproc)}"                   # osmrep worker processes
OSMREP="${OSMREP:-osmrep}"             # command, may have arguments: "bundle exec bin/osmrep"
OSMREP_DATA_DIR="${OSMREP_DATA_DIR:-/store/planet/replication}"  # to record the feed sequence

year=$(date +%Y)
date=$(date +%y%m%d)
name="gpx-planet-${date}.osm.bz2"
dump_file="${WORK_DIR}/gpx.dmp"
lock=/tmp/gpx-dump.lock

if [[ -f "$lock" ]] && kill -0 "$(cat "$lock")" 2>/dev/null; then
  echo "Error: another gpx-dump is running" >&2
  exit 1
fi
echo $$ > "$lock"
trap 'rm -f "$lock"' EXIT

mkdir -p "$WORK_DIR" "${PLANET_DIR}/${year}"

# The sequence of the feed before the pg_dump, so a consumer that loads the
# dump and then follows the feed from this sequence misses nothing.
state="${OSMREP_DATA_DIR}/gpx/state.txt"
sequence=$(grep -oE '^sequenceNumber=[0-9]+' "$state" 2>/dev/null | cut -d= -f2 || true)
sequence="${sequence:-0}"

echo "==> 1/3 pg_dump of the gpx tables from ${SOURCE_DB} -> ${dump_file} (feed sequence ${sequence})"
rm -f "$dump_file"
pg_dump --format=custom --data-only \
  --table=users --table=gpx_files --table=gpx_file_tags --table=gpx_tracks \
  --file="$dump_file" "$SOURCE_DB"

echo "==> 2/3 osmrep gpx dump with ${JOBS} workers"
read -ra osmrep_cmd <<< "$OSMREP"
out="${PLANET_DIR}/${year}/.${name}"
"${osmrep_cmd[@]}" gpx dump -c "$OSMREP_CONFIG" --from "$dump_file" -o "$out" \
  --sequence "$sequence" --jobs "$JOBS" --work-dir "$WORK_DIR"

size=$(wc -c < "$out" | tr -d " ")
if (( size < MIN_SIZE )); then
  echo "Error: ${out} is too small (${size} bytes)" >&2
  exit 1
fi
cd "${PLANET_DIR}/${year}"
mv ".${name}" "$name"
md5sum "$name" > "${name}.md5"

echo "==> 3/3 publish"
cd "$PLANET_DIR"
ln -fs "${year}/${name}" gpx-planet-latest.osm.bz2
sed -e "s/${name}/gpx-planet-latest.osm.bz2/" "${year}/${name}.md5" > gpx-planet-latest.osm.bz2.md5
if [[ -n "$S3_DIR" ]]; then
  "$AWS" --profile "$AWS_PROFILE_NAME" s3 cp --storage-class INTELLIGENT_TIERING --no-progress "${year}/${name}.md5" "${S3_DIR}/${year}/${name}.md5"
  "$AWS" --profile "$AWS_PROFILE_NAME" s3 cp --storage-class INTELLIGENT_TIERING --no-progress "${year}/${name}" "${S3_DIR}/${year}/${name}"
fi

rm -f "$dump_file"
echo "==> done: ${PLANET_DIR}/${year}/${name} (${size} bytes)"
