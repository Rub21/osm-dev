# Backfill gpx_tracks

Branch `gpx-tracks`, PR [#7348](https://github.com/openstreetmap/openstreetmap-website/pull/7348).
Script: https://gist.github.com/Rub21/5376e14fc7597af471945d7d6b8ddd6f

Check the schema. Expected `geometry(GeometryZM,4326)`:

```bash
docker exec gpx-tracks-db psql -U openstreetmap -d openstreetmap -c "\d gpx_tracks"
```

Get the script:

```bash
docker exec gpx-tracks-web bash -c "curl -fsSL https://gist.githubusercontent.com/Rub21/5376e14fc7597af471945d7d6b8ddd6f/raw/gpx-backfill.sh -o /tmp/gpx-backfill.sh && chmod +x /tmp/gpx-backfill.sh"
```

Run, 4 processes, blocks of 1000 ids:

```bash
docker exec -it -e RAILS_ENV=development gpx-tracks-web bash -c "cd /app && /tmp/gpx-backfill.sh run 4 1000"
```

Status and stop:

```bash
docker exec -e RAILS_ENV=development gpx-tracks-web bash -c "cd /app && /tmp/gpx-backfill.sh status"
docker exec gpx-tracks-web pkill -f 'rake db:gpx_tracks'
```
