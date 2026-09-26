# Postgres client plus curl, for docker/restore-db.sh.
FROM postgres:17

RUN apt-get update \
  && apt-get install -y --no-install-recommends curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*
