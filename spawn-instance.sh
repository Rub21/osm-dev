#!/usr/bin/env bash
# Spawn a new osm-dev instance for a branch of openstreetmap-website.
# Each instance lives in its own folder, has its own DB volume, and is routed
# by the shared Traefik proxy in osm-dev/proxy/.
#
# Usage:
#   ./spawn-instance.sh <slug> <branch> [repo-url] [host-ip]
#
# Args:
#   <slug>      Short name for the instance. Becomes folder name and subdomain.
#   <branch>    Branch name in the repo to check out.
#   [repo-url]  Git URL. Default: git@github.com:Rub21/openstreetmap-website.git
#   [host-ip]   Public IP with dashes for nip.io. Default: 204-168-242-139
#
# Examples:
#   ./spawn-instance.sh db-repair gps_db
#   ./spawn-instance.sh visibility gps_visibility
#   ./spawn-instance.sh upstream master git@github.com:openstreetmap/openstreetmap-website.git
#
# Result:
#   ../instances/<slug>/
#     openstreetmap-website/   (cloned, checked out to <branch>)
#     osm-dev/                 (copied from this folder, .env.instance set)
#
# Then:
#   cd ../instances/<slug>/osm-dev
#   docker compose --env-file .env --env-file .env.instance up -d --build

set -euo pipefail

SLUG="${1:?usage: spawn-instance.sh <slug> <branch> [repo-url] [host-ip]}"
BRANCH="${2:?usage: spawn-instance.sh <slug> <branch> [repo-url] [host-ip]}"
REPO_URL="${3:-git@github.com:Rub21/openstreetmap-website.git}"
HOST_IP="${4:-204-168-242-139}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTANCES_DIR="$PARENT_DIR/instances"
TARGET="$INSTANCES_DIR/$SLUG"
HOSTNAME="$SLUG.$HOST_IP.nip.io"

if [[ -d "$TARGET" ]]; then
  echo "error: $TARGET already exists" >&2
  exit 1
fi

echo "==> creating $TARGET"
mkdir -p "$TARGET"

echo "==> cloning $REPO_URL (branch: $BRANCH)"
git clone --branch "$BRANCH" "$REPO_URL" "$TARGET/openstreetmap-website"

echo "==> copying osm-dev (excluding proxy/ and instances/)"
mkdir -p "$TARGET/osm-dev"
rsync -a \
  --exclude='proxy/' \
  --exclude='.git/' \
  --exclude='.env.instance' \
  "$SCRIPT_DIR/" "$TARGET/osm-dev/"

echo "==> writing .env.instance"
cat > "$TARGET/osm-dev/.env.instance" <<EOF
COMPOSE_PROJECT_NAME=osm-$SLUG
INSTANCE_NAME=$SLUG
INSTANCE_HOST=$HOSTNAME
EOF

echo "==> ensuring osm-proxy network exists"
docker network inspect osm-proxy >/dev/null 2>&1 || {
  echo "warning: osm-proxy network missing. Start the shared proxy first:"
  echo "  cd $SCRIPT_DIR/proxy && docker compose up -d"
}

cat <<EOF

done.

Next:
  cd $TARGET/osm-dev
  docker compose --env-file .env --env-file .env.instance up -d --build

URL (after Let's Encrypt issues cert, ~30s):
  https://$HOSTNAME

EOF
