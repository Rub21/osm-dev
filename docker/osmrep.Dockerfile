# Ruby with libpq and the PostgreSQL 17 client tools for osmrep and script/gpx-dump.
# The repo is mounted at /osmrep, gems live in a volume.
ARG RUBY_VERSION=3.3
FROM ruby:${RUBY_VERSION}-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential libpq-dev git ca-certificates curl gnupg postgresql-common \
 && /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y \
 && apt-get install -y --no-install-recommends postgresql-client-17 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /osmrep
