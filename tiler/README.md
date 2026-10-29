# tiler

Prototype of the GPS tiles service. A PostGIS database follows the GPS
traces dump and replication feed of an osm-dev instance, and Martin serves
it as vector tiles. It is its own compose project: it only talks to the
instance through the public URLs of the feed and the dump, so it runs the
same on this server or on another one.


## Deploy

```
apt-get install -y docker.io docker-compose-v2 make
git clone https://github.com/Rub21/osm-dev.git /root/osm-dev
cd /root/osm-dev/tiler
cp .env.example .env   # set NAME, TILES_DOMAIN_NAME
make proxy
make up CF=1
make apache
```

Update:

```
cd /root/osm-dev && git pull
cd tiler && make up CF=1
```

## Consumer

The consumer is [gpxsync](https://github.com/Rub21/gpxsync), built into the
image from GitHub; `GPXSYNC_REF` in `.env` picks the branch. The loop in
`docker/consumer-loop.sh` imports the dump when the database is empty, then
runs `gpxsync update` every `INTERVAL` seconds.

Tables, created when missing:

```
traces(id, visibility, uid, "user", "timestamp", name, description, points, lat, lon)
trace_tags(gpx_id, tag)
trace_segments(gpx_id, trackid, geom geometry(GeometryZM, 4326), geom2d)   -- one per <trkseg>
replication_state(sequence, "timestamp")
```

Each trace in a file replaces its rows, a `visible="false"` trace removes
them, so applying a file twice gives the same result.

The files come from [osmrep](https://github.com/Rub21/osmrep): the feed is
`<osm>` with one `<trace>` per changed trace and the points as GPX, the dump
is the same format with every trace.
