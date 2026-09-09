#!/usr/bin/env bash
# Runs before the Rails server when .env has POST_START_SCRIPT=/docker/post-start.sh.
# Branch specific jobs go here. End long tasks with &.
set -euo pipefail
cd /app

bundle exec rails runner \
  "begin; TraceLinestringJob.perform_now; rescue NameError; puts 'TraceLinestringJob not defined, skipping'; end" &
