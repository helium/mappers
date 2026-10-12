defmodule Mappers.Repo.Migrations.AddCoverageFilters do
  use Ecto.Migration

  # Build indexes concurrently so production ingest keeps writing while they build.
  # No IF NOT EXISTS: a failed concurrent build leaves an invalid index behind,
  # and a rerun should fail on it rather than skip it.
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    create index(:uplinks_heard, [:timestamp], concurrently: true)

    # text_pattern_ops serves both exact matches and the prefix search
    execute """
    CREATE INDEX CONCURRENTLY uplinks_heard_hotspot_name_index
    ON uplinks_heard (hotspot_name text_pattern_ops)
    """

    # Martin function source: h3_res9 tiles where best_rssi and snr are
    # recomputed from the uplinks that match the filters. Query params:
    # start (inclusive), end (exclusive), hotspot (exact name). Dates with an
    # offset are shifted to UTC, the same as the hex API.
    execute """
    CREATE OR REPLACE FUNCTION public.h3_res9_filtered(z integer, x integer, y integer, query_params json)
    RETURNS bytea AS $$
    DECLARE
      start_at timestamp := NULLIF(query_params->>'start', '')::timestamptz AT TIME ZONE 'UTC';
      end_at timestamp := NULLIF(query_params->>'end', '')::timestamptz AT TIME ZONE 'UTC';
      hotspot text := NULLIF(query_params->>'hotspot', '');
      bounds geometry := ST_TileEnvelope(z, x, y);
      mvt bytea;
    BEGIN
      SELECT ST_AsMVT(tile, 'public.h3_res9', 4096, 'geom', 'h3_index_int') INTO mvt
      FROM (
        SELECT
          h.id,
          h.h3_index_int,
          h.state,
          best.rssi AS best_rssi,
          best.snr,
          ST_AsMVTGeom(ST_Transform(h.geom, 3857), bounds, 4096, 64, true) AS geom
        FROM h3_res9 h
        CROSS JOIN LATERAL (
          SELECT uh.rssi, uh.snr
          FROM h3_links l
          JOIN uplinks_heard uh ON uh.uplink_id = l.uplink_id
          WHERE l.h3_res9_id = h.id
            AND (start_at IS NULL OR uh.timestamp >= start_at)
            AND (end_at IS NULL OR uh.timestamp < end_at)
            AND (hotspot IS NULL OR uh.hotspot_name = hotspot)
          ORDER BY uh.rssi DESC
          LIMIT 1
        ) best
        WHERE h.geom && ST_Transform(bounds, 4326)
      ) AS tile
      WHERE tile.geom IS NOT NULL;

      RETURN mvt;
    END
    $$ LANGUAGE plpgsql STABLE PARALLEL SAFE;
    """
  end

  def down do
    execute "DROP FUNCTION IF EXISTS public.h3_res9_filtered(integer, integer, integer, json)"
    execute "DROP INDEX CONCURRENTLY IF EXISTS uplinks_heard_hotspot_name_index"
    drop_if_exists index(:uplinks_heard, [:timestamp], concurrently: true)
  end
end
