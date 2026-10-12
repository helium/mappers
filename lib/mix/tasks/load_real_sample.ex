defmodule Mix.Tasks.LoadRealSample do
  use Mix.Task

  require Logger
  alias Mappers.Ingest

  @shortdoc "Load coverage pulled by priv/repo/fetch_real_sample.js"

  @moduledoc """
  Replays the real coverage sample written by
  `priv/repo/fetch_real_sample.js` through the ingest pipeline.

      mix load_real_sample
      mix load_real_sample --reset path/to/sample.json

  Each hotspot reading becomes one uplink placed at its hex's center.
  Hotspot locations in the sample are already rounded to res8, and the
  hotspot address is a placeholder derived from the name.

  Options:
    --reset  truncate coverage tables first
  """

  @default_path "priv/repo/real/sf.json"

  def run(args) do
    if Mix.env() == :prod, do: Mix.raise("load_real_sample refuses to run in prod")

    {opts, paths, invalid} = OptionParser.parse(args, strict: [reset: :boolean])
    if invalid != [], do: Mix.raise("Unknown options: #{inspect(invalid)}")

    path = List.first(paths) || @default_path

    sample =
      case File.read(path) do
        {:ok, body} -> Jason.decode!(body)
        {:error, reason} -> Mix.raise("Could not read #{path}: #{:file.format_error(reason)}. Run priv/repo/fetch_real_sample.js first.")
      end

    Mix.Task.run("app.start")
    Logger.configure(level: :info)

    if Keyword.get(opts, :reset, false) do
      IO.puts("Truncating coverage tables...")
      Mappers.Repo.query!("TRUNCATE h3_links, uplinks_heard, uplinks, h3_res9")
    end

    hexes = Map.fetch!(sample, "hexes")
    IO.puts("Loading #{map_size(hexes)} hexes from #{path}...")

    {ok, errors} =
      Enum.reduce(hexes, {0, 0}, fn {hex_id, readings}, acc ->
        {lat, lng} = hex_id |> String.to_charlist() |> :h3.from_string() |> :h3.to_geo()

        Enum.reduce(readings, acc, fn reading, {ok, errors} ->
          case reading |> to_payload(lat, lng) |> Ingest.ingest_uplink() do
            {:ok, _} ->
              {ok + 1, errors}

            rejected ->
              IO.puts("  #{hex_id}: #{inspect(rejected)}")
              {ok, errors + 1}
          end
        end)
      end)

    IO.puts("Done: #{ok} readings ingested, #{errors} errors")
  end

  defp to_payload(reading, lat, lng) do
    {:ok, heard_at, _} = DateTime.from_iso8601(reading["timestamp"])
    reported_at = DateTime.to_unix(heard_at, :millisecond)

    %{
      "app_eui" => "0000000000000000",
      "dev_eui" => "0000000000000000",
      "id" => "real-sample",
      "fcnt" => 0,
      "reported_at" => reported_at,
      "decoded" => %{
        "payload" => %{"latitude" => lat, "longitude" => lng, "altitude" => 0, "accuracy" => 0.0},
        "status" => "success"
      },
      "hotspots" => [
        %{
          "id" => "real-sample-" <> reading["hotspot_name"],
          "name" => reading["hotspot_name"],
          "lat" => reading["lat"],
          "long" => reading["lng"],
          "rssi" => reading["rssi"],
          "snr" => reading["snr"],
          "frequency" => 904.3,
          "spreading" => "SF10BW125",
          "reported_at" => reported_at
        }
      ]
    }
  end
end
