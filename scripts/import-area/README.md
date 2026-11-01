# import-area

Copies a small area of OpenStreetMap or OpenHistoricalMap into a test instance, so you can test with real data.
It downloads the area from Overpass and uploads it through the API of the instance,
as new objects in one changeset. It refuses to write to openstreetmap.org and openhistoricalmap.org.

```bash
# local osm-dev, OSM data, uploads as mapper1
make import-area BBOX=47.6005,-122.3345,47.6015,-122.3330

# OHM data
make import-area BBOX=47.6005,-122.3345,47.6015,-122.3330 SOURCE=ohm

# another instance, e.g. a preview, with a token of your user there
make import-area BBOX=47.6005,-122.3345,47.6015,-122.3330 SOURCE=ohm TARGET=https://web-events.ohmstaging.org TOKEN=<token>
```

BBOX is south,west,north,east. Keep it small: one changeset holds at most 10000 changes.
`SOURCE` is `osm` (default) or `ohm`. `OVERPASS=<url>` uses another Overpass API.
If Overpass is busy the script stops with a message; try again after a minute.
