#!/usr/bin/env bash
set -euo pipefail

BRANCH="${1:-}"
CMD="${2:-up}"
FLAG="${3:-}"
# For `up`, the 3rd arg is an optional git sha to deploy instead of branch HEAD.
SHA="${3:-}"

if [[ -z "$BRANCH" ]]; then
  echo "usage: $0 <branch> [up|start|stop] [-v]" >&2
  echo "  examples:" >&2
  echo "    $0 gps_db" >&2
  echo "    $0 gps_visibility up" >&2
  echo "    $0 gps_db up <git-sha>   # deploy a specific commit (e.g. the previous version)" >&2
  echo "    $0 gps_db stop" >&2
  echo "    $0 gps_db stop -v   # stop and remove volumes" >&2
  exit 1
fi

source .env

export BRANCH
export SLUG="${BRANCH//_/-}"                          # gps_db -> gps-db
export REPO_URL="git@github.com:Rub21/openstreetmap-website.git"
export APPS_DIR="/apps/instances/$BRANCH"
export BASE_REPO="$APPS_DIR/openstreetmap-website"
export DOCKER_NAME_PREFIX="$SLUG"
export COMPOSE_PROJECT_NAME="$SLUG"
export NIP_DOMAIN=$NIP_DOMAIN
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
    if [[ -n "$SHA" ]]; then
      echo "    git sha:   $SHA"
    fi

    if [[ ! -d "$BASE_REPO/.git" ]]; then
      echo "==> cloning $REPO_URL -> $BASE_REPO"
      git clone "$REPO_URL" "$BASE_REPO"
      if [[ -n "$SHA" ]]; then
        echo "==> checkout $SHA (detached)"
        git -C "$BASE_REPO" checkout "$SHA"
      else
        git -C "$BASE_REPO" checkout "$BRANCH"
      fi
    else
      echo "==> fetching origin"
      git -C "$BASE_REPO" fetch origin
      if [[ -n "$SHA" ]]; then
        echo "==> checkout $SHA (detached)"
        git -C "$BASE_REPO" checkout "$SHA"
      else
        echo "==> checkout $BRANCH + pull --ff-only"
        git -C "$BASE_REPO" checkout "$BRANCH"
        git -C "$BASE_REPO" pull --ff-only origin "$BRANCH"
      fi
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
    if [[ "$FLAG" == "-v" ]]; then
      echo "==> docker compose down -v ($SLUG)  [removing volumes]"
      $DC down -v
    else
      echo "==> docker compose stop ($SLUG)"
      $DC stop
    fi
    ;;
  *)
    echo "unknown command: $CMD" >&2
    echo "usage: $0 <branch> [up|start|stop] [-v]" >&2
    exit 1
    ;;
esac
