# osm-dev scripts

Helper scripts used by the dev environment. The Ruby ones are mounted into the `web` container at `/scripts` and run from `docker/entrypoint.sh` on every start; `test_visibility.py` runs on the host.

## Bulk upload GPX (host)

`test_visibility.py` reads every `*.gpx` from a folder and uploads each one with a rotating `(user, visibility)` combo. Result: dev DB ends up with mixed traces across all users and visibility values — useful to seed varied data.

```bash
pip install requests

INSTANCE_SLUG=osmdev \
  OSM_URL=http://localhost:3000 \
  GPX_DIR=./gpx \
  python3 scripts/test_visibility.py
```

### Env vars

| var             | default                                       | meaning                            |
|-----------------|-----------------------------------------------|------------------------------------|
| `INSTANCE_SLUG` | `osmdev`                                      | instance name, or the branch slug of `bin/deploy.sh` |
| `OSM_URL`       | `http://localhost:3000`                       | API base URL                       |
| `GPX_DIR`       | `./gpx`                                       | folder with `*.gpx` files          |
| `LIMIT`         | `0`                                           | max files to upload (`0` = all)    |
| `USERS`         | `admin,mapper1,mapper2,mapper3`               | users to rotate through            |
| `VISIBILITIES`  | `public,identifiable,trackable,private`       | visibility values to rotate        |

### Examples

Upload first 20 files only:

```bash
LIMIT=20 GPX_DIR=./gpx \
  python3 scripts/test_visibility.py
```

Only test the two new (post-simplification) visibilities:

```bash
VISIBILITIES=public,identifiable \
  GPX_DIR=./gpx python3 scripts/test_visibility.py
```

Only one user:

```bash
USERS=admin \
  GPX_DIR=./gpx python3 scripts/test_visibility.py
```

## Files generated at runtime (gitignored)

- `../.tokens/<slug>.json` — written by `generate_token.rb` on every start. The slug is `INSTANCE_SLUG`, set in `compose.yaml` to `${DOCKER_NAME_PREFIX}`: `osmdev` locally, the branch slug on the server (e.g. `gps-db`).
