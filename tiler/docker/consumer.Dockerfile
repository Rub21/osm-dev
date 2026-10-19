# gpxsync (https://github.com/Rub21/gpxsync), the consumer, with the PostgreSQL client
# (pg_isready, psql) for the loop script. GPXSYNC_REF picks the branch or commit.
FROM python:3.12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends git postgresql-client curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

ARG GPXSYNC_REPO_URL=https://github.com/Rub21/gpxsync.git
ARG GPXSYNC_REF=main
RUN pip install --no-cache-dir "git+${GPXSYNC_REPO_URL}@${GPXSYNC_REF}"
