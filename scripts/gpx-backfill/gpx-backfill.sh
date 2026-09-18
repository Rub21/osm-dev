#!/bin/bash
#
# Backfill gpx_tracks from gps_points. Run it from the app directory.
#
#   ./backfill.sh run 8 300000      8 processes, blocks of 300000 trace ids
#   ./backfill.sh status            progress, read from the logs
#   pkill -f 'rake db:gpx_tracks'   stop it
#
# run reads the highest trace id, cuts the table into blocks of the size you
# gave, and works on that many at the same time. It shows the plan and waits
# for a yes before it starts.
#
# It takes hours, so start it inside screen or tmux.
#
# To measure one block first, without touching the rest:
#
#   ./backfill.sh block 1 300000
#
# The traces that already have rows in gpx_tracks are skipped, so a range can
# be started again with the same command. The logs are only there to follow
# the progress, one per range: keep the ranges apart, because status adds the
# logs up and counts an overlap twice. If you change the ranges, delete the
# old logs first.
#
# Before starting, count the traces that will never write rows, because no
# point of theirs has a timestamp. Run it on a replica, it reads gps_points:
#
#   SELECT count(*) FROM gpx_files f
#    WHERE f.visible AND f.inserted
#      AND NOT EXISTS (SELECT 1 FROM gps_points p
#                      WHERE p.gpx_id = f.id AND p.timestamp IS NOT NULL);
#
# That number cannot grow: a point without a timestamp is not imported any
# more. So when this second query returns the same number, the backfill is
# done:
#
#   SELECT count(*) FROM gpx_files f
#    WHERE f.visible AND f.inserted
#      AND NOT EXISTS (SELECT 1 FROM gpx_tracks t WHERE t.gpx_id = f.id);
#
set -euo pipefail

RAILS_ENV=${RAILS_ENV:-production}
LOGDIR=${LOGDIR:-/tmp/gpx-tracks}
export RAILS_ENV

mkdir -p "$LOGDIR"

# Highest trace id a range reported, taken from its progress lines.
last_done() {
  [ -f "$1" ] || return 0
  sed -n 's/^range [0-9]*-\([0-9]*\) .*/\1/p' "$1" | sort -n | tail -1
}

# Cuts the whole table into blocks and runs that many at a time.
cmd_run() {
  local processes=$1 block=$2 max blocks from to answer

  max=$(bundle exec rails runner 'puts Trace.maximum(:id)')
  blocks=$(((max + block - 1) / block))

  echo "Backfill gpx_tracks from gps_points"
  echo
  echo "  trace ids     1 to $max (highest id in gpx_files)"
  echo "  block size    $block ids per block, so up to $block traces each"
  echo "  blocks        $blocks in total"
  echo "  in parallel   $processes block(s) at the same time"
  echo "  rails env     $RAILS_ENV"
  echo "  logs          $LOGDIR/backfill-FIRST-LAST.log, one file per block"
  echo
  echo "Traces that already have rows in gpx_tracks are skipped, so you can run"
  echo "the same command again after a stop."
  echo
  echo "  follow it:  $0 status"
  echo "  stop it:    pkill -f 'rake db:gpx_tracks'"
  echo

  read -r -p "start? [y/N] " answer
  case "$answer" in
    y | Y | yes) ;;
    *) echo "nothing done"; exit 1 ;;
  esac

  export BLOCKS=$blocks
  rm -f "$LOGDIR/.done"

  for ((from = 1; from <= max; from += block)); do
    to=$((from + block - 1))
    [ "$to" -gt "$max" ] && to=$max
    echo "$from $to"
  done | xargs -P "$processes" -n 2 "$0" block
}

# One block. This is what run calls for each piece, and you can call it on its
# own to redo a single block.
cmd_block() {
  local from=$1 to=$2 count
  local log="$LOGDIR/backfill-$from-$to.log"

  echo "$from-$to: running"

  if nice -n 10 bundle exec rake db:gpx_tracks \
    MIN_TRACE="$from" MAX_TRACE="$to" >> "$log" 2>&1; then
    if [ -n "${BLOCKS:-}" ]; then
      echo "$from-$to" >> "$LOGDIR/.done"
      count=$(wc -l < "$LOGDIR/.done" | tr -d ' ')
      echo "$from-$to: done  ($count of $BLOCKS blocks)"
    else
      echo "$from-$to: done"
    fi
  else
    echo "$from-$to: failed, see $log"
  fi
}

cmd_status() {
  local log range from to done_to size progress percent state traces segments empty
  local all=0 all_done=0 all_traces=0 all_segments=0 all_empty=0

  for log in "$LOGDIR"/backfill-*.log; do
    [ -f "$log" ] || continue

    range=$(basename "$log" .log)
    range=${range#backfill-}
    from=${range%-*}
    to=${range#*-}

    done_to=$(last_done "$log")
    [ -n "$done_to" ] || done_to=$((from - 1))

    size=$((to - from + 1))
    progress=$((done_to - from + 1))
    [ "$progress" -lt 0 ] && progress=0
    percent=$((progress * 100 / size))

    state=stopped
    pgrep -f "MAX_TRACE=$to" > /dev/null && state=running
    [ "$progress" -ge "$size" ] && state=done

    traces=$(awk -F'traces=' '/^range /{split($2,a," "); s+=a[1]} END{print s+0}' "$log")
    segments=$(awk -F'segments=' '/^range /{split($2,a," "); s+=a[1]} END{print s+0}' "$log")
    empty=$(awk -F'empty=' '/^range /{split($2,a," "); s+=a[1]} END{print s+0}' "$log")

    printf "%-22s %3d%%  ids %8s / %-8s traces=%-8s segments=%-10s %s\n" \
      "$range" "$percent" "$progress" "$size" "$traces" "$segments" "$state"

    all=$((all + size))
    all_done=$((all_done + progress))
    all_traces=$((all_traces + traces))
    all_segments=$((all_segments + segments))
    all_empty=$((all_empty + empty))
  done

  [ "$all" -gt 0 ] || { echo "no logs in $LOGDIR"; return; }

  printf "\n%-22s %3d%%  ids %8s / %-8s traces=%-8s segments=%s\n" \
    total $((all_done * 100 / all)) "$all_done" "$all" "$all_traces" "$all_segments"
  echo "ids are trace id ranges, they have gaps; traces is the number of traces converted"

  echo "traces that wrote nothing: $all_empty"
  echo "errors: $(cat "$LOGDIR"/backfill-*.log | grep -c ' error=' || true)"
}

case "${1:-}" in
  run) cmd_run "$2" "$3" ;;
  block) cmd_block "$2" "$3" ;;
  status) cmd_status ;;
  *)
    echo "usage: $0 run PROCESSES TRACES_PER_BLOCK | block FIRST LAST | status" >&2
    exit 1
    ;;
esac
