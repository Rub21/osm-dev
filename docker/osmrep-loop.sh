#!/bin/sh
# Runs one replication every OSMREP_INTERVAL seconds.
set -eu
cd /osmrep
echo "osmrep: replicating every ${OSMREP_INTERVAL:-60}s into ${OSMREP_DATA_DIR:-/data}"
while true; do
  bundle exec bin/osmrep gpx replicate || echo "osmrep: run failed, next try in ${OSMREP_INTERVAL:-60}s"
  sleep "${OSMREP_INTERVAL:-60}"
done
