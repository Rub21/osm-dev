# osm-dev scripts

Mounted into the `web` container at `/scripts`.

| script | what |
|---|---|
| `setup_users.rb`, `generate_token.rb` | dev users and OAuth tokens, run by `docker/entrypoint.sh` on every start |
| `gpx-backfill/` | fill `gpx_tracks` from `gps_points`, see its README |
| `sample.gpx` | a small trace for manual uploads |

Tokens end up in `../.tokens/<slug>.json`, gitignored.
