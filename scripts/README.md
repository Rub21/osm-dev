# osm-dev scripts

Helper scripts used by the dev environment. They are mounted into the `web`
container at `/docker/scripts` and triggered from `start.sh`.

## Python test script (run from the host)

`test_visibility.py` exercises the GPS trace upload endpoint with the different
visibility values to confirm the new validation and the legacy `public=0/1`
behavior.

```bash
pip install requests
python3 test_visibility.py                # uses mapper1 by default
OSM_USER=admin python3 test_visibility.py # use a different user
```

It reads the token from `.tokens.json` and uploads `sample.gpx`.

## Files generated at runtime (gitignored)

- `.tokens.json` — written by `generate_token.rb`
