#!/usr/bin/env bash
# Copy a small area of OpenStreetMap (or OpenHistoricalMap) into a test instance
# (osm-dev, preview) through its API. The data is uploaded as new objects in one
# changeset, like an editor would do.
#
# Usage:
#   TOKEN=<oauth2 token with write_api> scripts/import-area/import-area.sh <target-url> <south,west,north,east>
# or, from the osm-dev folder: make import-area BBOX=<south,west,north,east> [SOURCE=ohm TARGET=<url> TOKEN=<token>]
# Example:
#   TOKEN=abc SOURCE=ohm scripts/import-area/import-area.sh https://web-events.ohmstaging.org 47.600,-122.335,47.602,-122.332
#
# SOURCE is osm (default) or ohm. OVERPASS sets another Overpass API URL.
# Keep the area small: one changeset holds at most 10000 changes.
set -euo pipefail

TARGET=${1:?target url, e.g. http://localhost:3000}
BBOX=${2:?bbox as south,west,north,east}
TOKEN=${TOKEN:?set TOKEN to an OAuth2 token of the target instance}
SOURCE=${SOURCE:-osm}
case "$SOURCE" in
  osm) DEFAULT_OVERPASS=https://overpass-api.de/api/interpreter; SOURCE_NAME=OpenStreetMap ;;
  ohm) DEFAULT_OVERPASS=https://overpass-api.openhistoricalmap.org/api/interpreter; SOURCE_NAME=OpenHistoricalMap ;;
  *) echo "SOURCE must be osm or ohm" >&2; exit 1 ;;
esac
OVERPASS=${OVERPASS:-$DEFAULT_OVERPASS}
COMMENT=${COMMENT:-"Import test data from $SOURCE_NAME ($BBOX)"}
TARGET=${TARGET%/}

# Never write to a production instance
case "$TARGET" in
  *://openstreetmap.org*|*://www.openstreetmap.org*|*://api.openstreetmap.org*|\
  *://openhistoricalmap.org*|*://www.openhistoricalmap.org*|*://api.openhistoricalmap.org*)
    echo "Refusing to import into production: $TARGET" >&2; exit 1 ;;
esac

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "==> Downloading $BBOX from $OVERPASS"
curl -sf -m 300 "$OVERPASS" \
  --data-urlencode "data=[out:xml][timeout:240];(node($BBOX);way($BBOX););(._;>;);out meta;relation($BBOX);out meta;" -o "$WORK/area.osm"
if ! grep -q "<osm" "$WORK/area.osm" || grep -q "runtime error" "$WORK/area.osm"; then
  echo "Overpass did not return data (busy or rate limited). Try again in a minute:" >&2
  head -c 500 "$WORK/area.osm" >&2; exit 1
fi

echo "==> Building the osmChange"
python3 - "$WORK/area.osm" "$WORK/change.osc" <<'PY'
import sys
import xml.etree.ElementTree as ET
from xml.sax.saxutils import quoteattr

src, out = sys.argv[1], sys.argv[2]
root = ET.parse(src).getroot()
elements = {(e.tag, e.get("id")): e for e in root if e.tag in ("node", "way", "relation")}

# Every object gets a negative placeholder id
new_id = {}
for i, key in enumerate(elements, start=1):
    new_id[key] = -i

def tags(e):
    return "".join(f"<tag k={quoteattr(t.get('k'))} v={quoteattr(t.get('v'))}/>" for t in e.findall("tag"))

nodes, ways, relations = [], [], []
for (kind, oid), e in elements.items():
    nid = new_id[(kind, oid)]
    if kind == "node":
        nodes.append(f'<node id="{nid}" changeset="CS" lat="{e.get("lat")}" lon="{e.get("lon")}">{tags(e)}</node>')
    elif kind == "way":
        refs = [new_id.get(("node", nd.get("ref"))) for nd in e.findall("nd")]
        if None in refs or len(refs) < 2:
            continue  # incomplete way
        nds = "".join(f'<nd ref="{r}"/>' for r in refs)
        ways.append(f'<way id="{nid}" changeset="CS">{nds}{tags(e)}</way>')
    else:
        members = []
        for m in e.findall("member"):
            ref = new_id.get((m.get("type"), m.get("ref")))
            if ref is not None:  # skip members outside the area
                members.append((m.get("type"), ref, m.get("role", "")))
        relations.append((nid, members, tags(e)))

# A relation can only point to relations that come before it in the file
created = set()
ordered, pending = [], relations[:]
while pending:
    progress = False
    for r in pending[:]:
        if all(t != "relation" or ref in created for t, ref, _ in r[1]):
            ordered.append(r); created.add(r[0]); pending.remove(r); progress = True
    if not progress:  # cycle: drop relation members that point forward
        r = pending.pop(0)
        ordered.append((r[0], [m for m in r[1] if m[0] != "relation" or m[1] in created], r[2])); created.add(r[0])

rels = []
for nid, members, t in ordered:
    if not members:
        continue
    ms = "".join(f'<member type="{ty}" ref="{ref}" role={quoteattr(role)}/>' for ty, ref, role in members)
    rels.append(f'<relation id="{nid}" changeset="CS">{ms}{t}</relation>')

total = len(nodes) + len(ways) + len(rels)
if total == 0:
    sys.exit("Nothing to import in this area")
if total > 10000:
    sys.exit(f"{total} objects, more than one changeset can hold. Use a smaller area.")
with open(out, "w") as f:
    f.write('<osmChange version="0.6" generator="import-area"><create>')
    f.write("".join(nodes + ways + rels))
    f.write("</create></osmChange>")
print(f"   {len(nodes)} nodes, {len(ways)} ways, {len(rels)} relations")
PY

api() { curl -sS --fail-with-body -H "Authorization: Bearer $TOKEN" -H "Content-Type: text/xml" "$@"; }

echo "==> Uploading to $TARGET"
COMMENT_XML=$(python3 -c 'import sys; from xml.sax.saxutils import quoteattr; print(quoteattr(sys.argv[1]))' "$COMMENT")
CS=$(api -X PUT "$TARGET/api/0.6/changeset/create" \
  --data "<osm><changeset><tag k=\"created_by\" v=\"import-area\"/><tag k=\"comment\" v=$COMMENT_XML/></changeset></osm>")
sed -i.bak "s/changeset=\"CS\"/changeset=\"$CS\"/g" "$WORK/change.osc"

# Close the changeset even when the upload fails
close() { api -X PUT "$TARGET/api/0.6/changeset/$CS/close" >/dev/null || true; }
trap 'close; rm -rf "$WORK"' EXIT

api -X POST "$TARGET/api/0.6/changeset/$CS/upload" --data-binary "@$WORK/change.osc" -o "$WORK/diff.xml"
echo "==> Done: $TARGET/changeset/$CS"
