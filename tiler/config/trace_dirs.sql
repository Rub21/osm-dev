-- Martin function source trace_dirs: the trace lines cut into segments in the
-- tile, each with its direction of travel, so the vector style can color them
-- like the PNG tiles of gps-tile (datamaps lines-directional).
--
-- dir is the direction in 32 steps of 11.25 degrees: 0 = east, 8 = north,
-- 16 = west, 24 = south, the same angle the gps-tile import computes.
-- fade (1-10) copies the -g option of datamaps: a segment longer than about
-- 15 m at z16 (x1.5 per zoom out) gets dimmer in proportion, so GPS jumps
-- almost disappear. Segments under fade 1 are dropped.
-- Segments of the same trace, dir and fade are merged into one feature.
--
-- plpgsql so it can be created before gpxsync creates trace_segments.
CREATE OR REPLACE FUNCTION trace_dirs(z integer, x integer, y integer)
RETURNS bytea
LANGUAGE plpgsql STABLE PARALLEL SAFE
AS $$
DECLARE
  mvt bytea;
BEGIN
  WITH bounds AS (
    SELECT ST_TileEnvelope(z, x, y) AS env,
           ST_Transform(ST_TileEnvelope(z, x, y, margin => 64.0 / 4096), 4326) AS env4326
  ),
  clipped AS (
    SELECT s.gpx_id, ST_AsMVTGeom(ST_Transform(s.geom2d, 3857), b.env, 4096, 64, true) AS g
    FROM trace_segments s, bounds b
    WHERE s.geom2d && b.env4326
      AND GeometryType(s.geom2d) = 'LINESTRING'
  ),
  segs AS (
    -- Simplify in tile units (4096 per tile, 16 per pixel) before cutting,
    -- so low zooms do not carry many tiny segments.
    SELECT gpx_id, (ST_DumpSegments(ST_Simplify(g, 8))).geom AS g
    FROM clipped
    WHERE g IS NOT NULL
  ),
  dirs AS (
    -- Tile y grows down, so north is start y - end y.
    -- datamaps limit: 1600 world units (2^32 per world) * 1.5^(16 - z),
    -- in tile units (4096 per tile) that is * 2^(z - 20). At least 48 units
    -- (3 px): simplified segments at low zooms are longer than raw ones.
    SELECT gpx_id, g,
           least(10, round(10 * greatest(48, 1600 * power(1.5, 16 - z) * power(2, z - 20)) / ST_Length(g)))::int AS fade,
           floor((degrees(atan2(ST_Y(ST_StartPoint(g)) - ST_Y(ST_EndPoint(g)),
                                ST_X(ST_EndPoint(g)) - ST_X(ST_StartPoint(g)))) + 360) / 11.25)::int % 32 AS dir
    FROM segs
    WHERE NOT ST_Equals(ST_StartPoint(g), ST_EndPoint(g))
  )
  SELECT ST_AsMVT(t, 'trace_dirs', 4096, 'geom') INTO mvt
  FROM (
    SELECT gpx_id, dir, fade, ST_LineMerge(ST_Collect(g)) AS geom
    FROM dirs
    WHERE fade >= 1
    GROUP BY gpx_id, dir, fade
  ) t;
  RETURN mvt;
END
$$;
