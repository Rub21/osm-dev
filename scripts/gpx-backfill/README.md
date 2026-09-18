# Backfill gpx_tracks

Branch `gpx-tracks`, PR [#7348](https://github.com/openstreetmap/openstreetmap-website/pull/7348).

The script lives in `scripts/gpx-backfill/gpx-backfill.sh` and is mounted in the web container at `/scripts`.
It runs `rake`, so it needs the app directory: always `cd /app` first. Logs go to `/tmp/gpx-tracks`
inside the container; pass `-e LOGDIR=/app/tmp/gpx-tracks` to keep them in the `web-tmp` volume.

Run, 4 processes, blocks of 1000 ids:

```bash
docker exec -it -e RAILS_ENV=development -e LOGDIR=/app/tmp/gpx-tracks gpx-tracks-web bash -c "cd /app && /scripts/gpx-backfill/gpx-backfill.sh run 2 200"
```

Status and stop:

```bash
docker exec -e RAILS_ENV=development -e LOGDIR=/app/tmp/gpx-tracks gpx-tracks-web bash -c "cd /app && /scripts/gpx-backfill/gpx-backfill.sh status"
docker exec gpx-tracks-web pkill -f 'rake db:gpx_tracks'
```
