# osmrep (https://github.com/Rub21/osmrep) with the PostgreSQL 17 client tools, for the
# replication loop and docker/gpx-dump.sh. The repo is cloned and its gems installed at
# build time; OSMREP_REF picks the branch or commit.
ARG RUBY_VERSION=3.3
FROM ruby:${RUBY_VERSION}-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential libpq-dev git ca-certificates curl gnupg postgresql-common \
 && /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y \
 && apt-get install -y --no-install-recommends postgresql-client-17 bzip2 \
 && rm -rf /var/lib/apt/lists/*

ARG OSMREP_REPO_URL=https://github.com/Rub21/osmrep.git
ARG OSMREP_REF=main
RUN git clone --depth 1 --branch "$OSMREP_REF" "$OSMREP_REPO_URL" /osmrep
WORKDIR /osmrep
ENV BUNDLE_WITHOUT=development:test
RUN bundle install --quiet
