# planet-dump-ng built from a branch, with the PostgreSQL 17 client tools, for
# docker/planet-dump-ng.sh. PLANET_DUMP_NG_REF picks the branch or commit.

FROM debian:bookworm-slim AS builder
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates build-essential automake autoconf pkg-config git \
      libxml2-dev libboost-dev libboost-program-options-dev libboost-date-time-dev \
      libboost-filesystem-dev libboost-thread-dev libboost-iostreams-dev \
      libosmpbf-dev libprotobuf-dev \
 && rm -rf /var/lib/apt/lists/*

ARG PLANET_DUMP_NG_REPO_URL=https://github.com/Rub21/planet-dump-ng.git
ARG PLANET_DUMP_NG_REF=gpx-dump
WORKDIR /src
RUN git clone --depth 1 --branch "$PLANET_DUMP_NG_REF" "$PLANET_DUMP_NG_REPO_URL" . \
 && ./autogen.sh \
 && ./configure \
 && make -j"$(nproc)" \
 && strip planet-dump-ng

FROM debian:bookworm-slim
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg postgresql-common \
 && /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      postgresql-client-17 bzip2 libxml2-utils libxml2 \
      libboost-filesystem1.74.0 libboost-program-options1.74.0 libboost-thread1.74.0 \
      libboost-iostreams1.74.0 libboost-date-time1.74.0 libprotobuf32 libprotobuf-lite32 libosmpbf1 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/planet-dump-ng /usr/local/bin/planet-dump-ng
