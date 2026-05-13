#!/usr/bin/env bash
set -euo pipefail

BRANCH="${1:-}"
CMD="${2:-up}"

if [[ -z "$BRANCH" ]]; then
  echo "usage: $0 <branch> [up|start|stop]" >&2
  echo "  examples:" >&2
  echo "    $0 gps_db" >&2
  echo "    $0 gps_visibility up" >&2
  echo "    $0 gps_db stop" >&2
  exit 1
fi

export BRANCH
export SLUG="${BRANCH//_/-}"                          # gps_db -> gps-db
export REPO_URL="git@github.com:Rub21/openstreetmap-website.git"
export APPS_DIR="/apps/instances/$BRANCH"
export BASE_REPO="$APPS_DIR/openstreetmap-website"
export DOCKER_NAME_PREFIX="$SLUG"
export COMPOSE_PROJECT_NAME="$SLUG"
export NIP_DOMAIN="204-168-153-175.nip.io"
export DOMAIN_NAME="${SLUG}.${NIP_DOMAIN}"

# Per-branch additional compose overlays. Add new branches here as needed.
COMPOSE_FILES="-f docker-compose.yaml"
case "$BRANCH" in
  gps_db)
    COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.gps.yaml"
    ;;
esac
DC="docker compose $COMPOSE_FILES"

case "$CMD" in
  up)
    echo "==> $BRANCH ($SLUG) -> $DOMAIN_NAME"
    echo "    base repo: $BASE_REPO"
    echo "    compose:   $DC"

    if [[ ! -d "$BASE_REPO/.git" ]]; then
      echo "==> cloning $REPO_URL -> $BASE_REPO"
      git clone "$REPO_URL" "$BASE_REPO"
      git -C "$BASE_REPO" checkout "$BRANCH"
    else
      echo "==> fetching + checkout $BRANCH + pull --ff-only"
      git -C "$BASE_REPO" fetch origin
      git -C "$BASE_REPO" checkout "$BRANCH"
      git -C "$BASE_REPO" pull --ff-only origin "$BRANCH"
    fi

    echo "==> docker compose up -d --build"
    $DC up -d --build

    echo ""
    echo "==> deployed:"
    echo "    web:     https://$DOMAIN_NAME"
    if [[ "$COMPOSE_FILES" == *docker-compose.gps.yaml* ]]; then
      echo "    pgadmin: https://pgadmin-$DOMAIN_NAME"
    fi
    ;;
  start)
    echo "==> docker compose start ($SLUG)"
    $DC start
    echo ""
    echo "==> running at:"
    echo "    web:     https://$DOMAIN_NAME"
    if [[ "$COMPOSE_FILES" == *docker-compose.gps.yaml* ]]; then
      echo "    pgadmin: https://pgadmin-$DOMAIN_NAME"
    fi
    ;;
  stop)
    echo "==> docker compose stop ($SLUG)"
    $DC stop
    ;;
  *)
    echo "unknown command: $CMD" >&2
    echo "usage: $0 <branch> [up|start|stop]" >&2
    exit 1
    ;;
esac
