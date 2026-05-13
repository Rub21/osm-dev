# osm-dev scripts

Helper scripts used by the dev environment. Mounted into the `web` container at `/docker/scripts` and triggered from `start.sh`.

## Bulk upload GPX (host)

`test_visibility.py` reads every `*.gpx` from a folder and uploads each one with a rotating `(user, visibility)` combo. Result: dev DB ends up with mixed traces across all users and visibility values — useful to seed varied data.

```bash
pip install requests

INSTANCE_SLUG=gps-db \
  OSM_URL=https://gps-db.<your-ip>.nip.io \
  GPX_DIR=/apps/gps-fetcher/gpx_files \
  python3 test_visibility.py
```

### Env vars

| var             | default                                       | meaning                            |
|-----------------|-----------------------------------------------|------------------------------------|
| `INSTANCE_SLUG` | `default`                                     | branch slug (matches `deploy.sh`)  |
| `OSM_URL`       | `http://localhost:3000`                       | API base URL                       |
| `GPX_DIR`       | `./gpx`                                       | folder with `*.gpx` files          |
| `LIMIT`         | `0`                                           | max files to upload (`0` = all)    |
| `USERS`         | `admin,mapper1,mapper2,mapper3`               | users to rotate through            |
| `VISIBILITIES`  | `public,identifiable,trackable,private`       | visibility values to rotate        |

### Examples

Upload first 20 files only:

```bash
LIMIT=20 INSTANCE_SLUG=gps-db GPX_DIR=/apps/gps-fetcher/gpx_files \
  python3 test_visibility.py
```

Only test the two new (post-simplification) visibilities:

```bash
VISIBILITIES=public,identifiable INSTANCE_SLUG=gps-db \
  GPX_DIR=/apps/gps-fetcher/gpx_files python3 test_visibility.py
```

Only one user:

```bash
USERS=admin INSTANCE_SLUG=gps-db \
  GPX_DIR=/apps/gps-fetcher/gpx_files python3 test_visibility.py
```

## Files generated at runtime (gitignored)

- `.tokens-<slug>.json` — written by `generate_token.rb` per instance. Slug from `INSTANCE_SLUG` env, set in `docker-compose.yaml` to `${DOCKER_NAME_PREFIX}` (deploy.sh slug, e.g. `gps-db`).
