#!/usr/bin/env bash
# Server helper used by make with BRANCH=: git sync of one branch, then docker compose with its env.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

BRANCH="${1:-}"
CMD="${2:-}"

usage() {
  cat >&2 <<'USAGE'
usage: bin/deploy.sh <branch> up [<git-sha>|--no-sync]      REPO=owner/repo or REPO_URL in .env
       bin/deploy.sh <branch> compose <docker compose args>
Normally called through make: make up BRANCH=gps_db REPO=owner/repo
USAGE
  exit 1
}

[[ -n "$BRANCH" && -n "$CMD" ]] || usage
[[ -f .env ]] || { echo "error: .env not found, copy .env.example to .env" >&2; exit 1; }

set -a
# shellcheck disable=SC1091
source .env
set +a
: "${NIP_DOMAIN:?set NIP_DOMAIN in .env, for example 203-0-113-10.nip.io}"

SLUG="${BRANCH//_/-}"
INSTANCES_DIR="${INSTANCES_DIR:-/apps/instances}"
export BASE_REPO="$INSTANCES_DIR/$BRANCH/openstreetmap-website"
export DOCKER_NAME_PREFIX="$SLUG"
export COMPOSE_PROJECT_NAME="$SLUG"
export DOMAIN_NAME="${SLUG}.${NIP_DOMAIN}"

# REPO on the command line, or REPO_URL in .env. "owner/repo" means GitHub.
REPO_URL="${REPO:-${REPO_URL:-}}"
[[ -z "$REPO_URL" || "$REPO_URL" == *:* ]] || REPO_URL="https://github.com/$REPO_URL.git"

# Extra compose files per branch: case "$BRANCH" in my_branch) FILES="$FILES -f compose.pgadmin.yaml" ;; esac
FILES="-f compose.yaml -f compose.proxy.yaml"

dc() {
  # shellcheck disable=SC2086
  docker compose $FILES "$@"
}

sync_repo() {
  local sha="$1"
  if [[ ! -d "$BASE_REPO/.git" ]]; then
    [[ -n "$REPO_URL" ]] || { echo "error: set REPO=owner/repo (or REPO_URL in .env) to clone $BRANCH" >&2; exit 1; }
    echo "==> cloning $REPO_URL -> $BASE_REPO"
    mkdir -p "$(dirname "$BASE_REPO")"
    git clone "$REPO_URL" "$BASE_REPO"
  else
    if [[ -n "$REPO_URL" && "$(git -C "$BASE_REPO" remote get-url origin)" != "$REPO_URL" ]]; then
      echo "==> origin changed to $REPO_URL"
      git -C "$BASE_REPO" remote set-url origin "$REPO_URL"
    fi
    echo "==> fetching origin"
    git -C "$BASE_REPO" fetch origin
  fi
  if [[ -n "$sha" ]]; then
    echo "==> checkout $sha"
    git -C "$BASE_REPO" checkout "$sha"
  else
    echo "==> checkout $BRANCH and pull"
    git -C "$BASE_REPO" checkout "$BRANCH"
    git -C "$BASE_REPO" pull --ff-only origin "$BRANCH"
  fi
}

case "$CMD" in
  up)
    ARG="${3:-}"
    echo "==> $BRANCH ($SLUG) -> https://$DOMAIN_NAME"
    if [[ "$ARG" == "--no-sync" ]]; then
      [[ -d "$BASE_REPO/.git" ]] || { echo "error: $BASE_REPO does not exist, run without NO_SYNC first" >&2; exit 1; }
    else
      sync_repo "$ARG"
    fi
    dc up -d --build
    echo ""
    echo "==> web: https://$DOMAIN_NAME"
    [[ "$FILES" == *compose.pgadmin.yaml* ]] && echo "    pgadmin: ssh -L ${PGADMIN_PORT:-5050}:localhost:${PGADMIN_PORT:-5050} <server>"
    ;;
  compose)
    shift 2
    dc "$@"
    ;;
  *)
    usage
    ;;
esac
