#!/bin/bash
# Daily list of GPS trace ids, the same steps as chef gpx-ids.erb
# (openstreetmap/chef#881). Runs inside the planetdump container:
# make gpx-ids PLANETDUMP=1
set -euo pipefail

: "${PGHOST:?set PGHOST, PGUSER and PGPASSWORD}"
SOURCE_DB="${SOURCE_DB:-openstreetmap}"
OUT_DIR="${OUT_DIR:-/data/gpx_ids}"

T=$(mktemp -d)
mkdir -p "$OUT_DIR"

echo "# GPS trace IDs with identifiable visibility." > "$T/identifiable"
psql -d "$SOURCE_DB" -t -A -c "select id from gpx_files where visible and inserted and visibility='identifiable' order by id asc" >> "$T/identifiable"

if cmp -s "$T/identifiable" "$OUT_DIR/identifiable.txt"; then
  echo "==> no changes"
else
  cp "$T/identifiable" "$OUT_DIR/identifiable.txt.new"
  mv "$OUT_DIR/identifiable.txt.new" "$OUT_DIR/identifiable.txt"
  echo "==> updated"
fi

rm -rf "$T"
echo "==> $OUT_DIR/identifiable.txt: $(grep -vc '^#' "$OUT_DIR/identifiable.txt") ids"
