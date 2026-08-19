# Postgres client plus curl, so restore_db.sh can download the dump.
FROM postgres:14

RUN apt-get update \
  && apt-get install -y --no-install-recommends curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*
