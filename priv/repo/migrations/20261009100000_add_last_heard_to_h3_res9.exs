defmodule Mappers.Repo.Migrations.AddLastHeardToH3Res9 do
  use Ecto.Migration

  # The backfill runs as many short transactions so production ingest, which
  # updates h3_res9 rows by id, only ever waits on one batch's row locks.
  @disable_ddl_transaction true
  @disable_migration_lock true

  @batch_size 5_000

  def up do
    # Epoch seconds, since MVT properties can't carry timestamps. Nullable with
    # no default, so this is a catalog-only change with no table rewrite.
    alter table(:h3_res9) do
      add_if_not_exists :last_heard, :bigint
    end

    flush()

    backfill("")

    execute filtered_tiles_function(true)
  end

  def down do
    execute filtered_tiles_function(false)

    alter table(:h3_res9) do
      remove_if_exists :last_heard, :bigint
    end
  end

  # Walks h3_res9 in primary key order. Each batch finds the latest heard time
  # per hex through the h3_links and uplinks_heard indexes and keeps whichever
  # is later, its own or one ingest already wrote, so it is safe to run while
  # uplinks arrive and safe to re-run.
  defp backfill(after_id) do
    %{rows: [[last_id]]} =
      repo().query!(
        """
        WITH batch AS (
          SELECT id FROM h3_res9 WHERE id > $1 ORDER BY id LIMIT $2
        ), heard AS (
          SELECT b.id, (
            SELECT extract(epoch FROM max(uh.timestamp))::bigint
            FROM h3_links l
            JOIN uplinks_heard uh ON uh.uplink_id = l.uplink_id
            WHERE l.h3_res9_id = b.id
          ) AS last_heard
          FROM batch b
        ), updated AS (
          UPDATE h3_res9 h
          SET last_heard = GREATEST(h.last_heard, heard.last_heard)
          FROM heard
          WHERE h.id = heard.id
            AND heard.last_heard IS NOT NULL
            AND (h.last_heard IS NULL OR h.last_heard < heard.last_heard)
        )
        SELECT max(id) FROM batch
        """,
        [after_id, @batch_size],
        timeout: :infinity
      )

    if last_id, do: backfill(last_id)
  end

  # The AddCoverageFilters function, plus last_heard: the latest heard time
  # among the uplinks that match the filter. One aggregate pass replaces the
  # ORDER BY rssi LIMIT 1, and HAVING still drops hexes with no match.
  defp filtered_tiles_function(last_heard?) do
    last_heard_column = if last_heard?, do: "best.last_heard,", else: ""

    last_heard_select =
      if last_heard?, do: "extract(epoch FROM max(uh.timestamp))::bigint AS last_heard,", else: ""

    """
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
          #{last_heard_column}
          ST_AsMVTGeom(ST_Transform(h.geom, 3857), bounds, 4096, 64, true) AS geom
        FROM h3_res9 h
        CROSS JOIN LATERAL (
          SELECT
            #{last_heard_select}
            max(uh.rssi) AS rssi,
            (array_agg(uh.snr ORDER BY uh.rssi DESC))[1] AS snr
          FROM h3_links l
          JOIN uplinks_heard uh ON uh.uplink_id = l.uplink_id
          WHERE l.h3_res9_id = h.id
            AND (start_at IS NULL OR uh.timestamp >= start_at)
            AND (end_at IS NULL OR uh.timestamp < end_at)
            AND (hotspot IS NULL OR uh.hotspot_name = hotspot)
          HAVING count(*) > 0
        ) best
        WHERE h.geom && ST_Transform(bounds, 4326)
      ) AS tile
      WHERE tile.geom IS NOT NULL;

      RETURN mvt;
    END
    $$ LANGUAGE plpgsql STABLE PARALLEL SAFE;
    """
  end
end
