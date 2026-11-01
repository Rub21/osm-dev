# osm-dev scripts

Mounted into the `web` container at `/scripts`.

| script | what |
|---|---|
| `setup_users.rb`, `generate_token.rb` | dev users and OAuth tokens, run by `docker/entrypoint.sh` on every start |
| `gpx-backfill/` | fill `gpx_tracks` from `gps_points`, see its README |
| `import-area/` | `make import-area BBOX=s,w,n,e [SOURCE=ohm]` copies an OpenStreetMap or OpenHistoricalMap area into the instance through the API, see its README |
| `oauth-apps/` | `make app NAME=josm` creates an OAuth app and prints client id and secret, see its README |
| `sample.gpx` | a small trace for manual uploads |

Tokens end up in `../.tokens/<slug>.json`, gitignored.
