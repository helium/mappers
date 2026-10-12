defmodule Mix.Tasks.SeedSynthetic do
  use Mix.Task

  require Logger
  alias Mappers.Ingest

  @shortdoc "Seed the local database with synthetic mapper drives"

  @moduledoc """
  Generates fake hotspots and mapper drives around San Francisco and replays
  them through the real ingest pipeline, so h3_res9, uplinks, uplinks_heard,
  and h3_links all fill the same way production data does.

      mix seed_synthetic
      mix seed_synthetic --reset --hotspots 40 --drives 500 --seed 7

  Hotspots come online and go offline at different times, and drives are
  spread from mid-2021 to late 2026, so date filters have something to show.
  The same --seed always produces the same data.

  Options:
    --hotspots  number of hotspots (default 30)
    --drives    number of drives (default 300)
    --points    uplinks per drive (default 20)
    --seed      random seed (default 1)
    --reset     truncate coverage tables first
  """

  # San Francisco
  @bbox %{min_lat: 37.70, max_lat: 37.81, min_lng: -122.51, max_lng: -122.38}
  @start_unix ~U[2021-06-01 00:00:00Z] |> DateTime.to_unix()
  @end_unix ~U[2026-09-30 00:00:00Z] |> DateTime.to_unix()
  @step_m 120
  @point_interval_s 30
  @max_range_m 6_000
  @min_rssi -126

  @adjectives ~w(basic bitter blunt bright cool dizzy fancy gentle happy jolly lucky mellow quiet rapid shiny tame)
  @materials ~w(nylon flint strawberry lemonade caramel white cedar velvet copper paper plastic mint marble pewter amber)
  @animals ~w(deer flamingo baboon eagle mouse peacock otter badger falcon lizard walrus heron moose gecko pelican)

  @switches [hotspots: :integer, drives: :integer, points: :integer, seed: :integer, reset: :boolean]

  def run(args) do
    if Mix.env() == :prod, do: Mix.raise("seed_synthetic refuses to run in prod")

    {opts, _, invalid} = OptionParser.parse(args, strict: @switches)
    if invalid != [], do: Mix.raise("Unknown options: #{inspect(invalid)}")

    Mix.Task.run("app.start")
    Logger.configure(level: :info)

    seed = Keyword.get(opts, :seed, 1)
    :rand.seed(:exsss, {seed, seed * 7, seed * 13})

    if Keyword.get(opts, :reset, false), do: reset!()

    hotspots = build_hotspots(Keyword.get(opts, :hotspots, 30))
    drives = Keyword.get(opts, :drives, 300)
    points = Keyword.get(opts, :points, 20)

    IO.puts("Seeding #{drives} drives x #{points} points heard by #{length(hotspots)} hotspots...")

    {ok, errors, unheard} =
      Enum.reduce(1..drives//1, {0, 0, 0}, fn drive_n, acc ->
        if rem(drive_n, 50) == 0, do: IO.puts("  drive #{drive_n}/#{drives}")

        drive_n
        |> build_drive(points)
        |> Enum.reduce(acc, fn point, {ok, errors, unheard} ->
          case heard_by(point, hotspots) do
            [] ->
              {ok, errors, unheard + 1}

            heard ->
              case point |> to_payload(heard) |> Ingest.ingest_uplink() do
                {:ok, _} ->
                  {ok + 1, errors, unheard}

                rejected ->
                  IO.puts("  ingest error: #{inspect(rejected)}")
                  {ok, errors + 1, unheard}
              end
          end
        end)
      end)

    IO.puts("Done: #{ok} uplinks ingested, #{unheard} unheard points skipped, #{errors} errors")
  end

  defp reset! do
    IO.puts("Truncating coverage tables...")
    Mappers.Repo.query!("TRUNCATE h3_links, uplinks_heard, uplinks, h3_res9")
  end

  defp build_hotspots(count) do
    Enum.map(1..count//1, fn n ->
      online_at = rand_between(@start_unix, @start_unix + div(@end_unix - @start_unix, 2))

      # about a third of hotspots go offline partway through
      offline_at =
        if :rand.uniform() < 0.33 do
          rand_between(online_at + 365 * 86_400, @end_unix)
        else
          @end_unix
        end

      %{
        address: "synthetic#{Integer.to_string(n) |> String.pad_leading(4, "0")}",
        name: Enum.join([Enum.random(@adjectives), Enum.random(@materials), Enum.random(@animals)], "-"),
        lat: rand_float(@bbox.min_lat, @bbox.max_lat),
        lng: rand_float(@bbox.min_lng, @bbox.max_lng),
        online_at: online_at,
        offline_at: offline_at
      }
    end)
  end

  defp build_drive(drive_n, points) do
    started_at = rand_between(@start_unix, @end_unix)
    lat = rand_float(@bbox.min_lat, @bbox.max_lat)
    lng = rand_float(@bbox.min_lng, @bbox.max_lng)
    bearing = :rand.uniform() * 2 * :math.pi()

    {walk, _} =
      Enum.map_reduce(0..(points - 1)//1, {lat, lng, bearing}, fn i, {lat, lng, bearing} ->
        point = %{
          device_id: "synthetic-device-#{rem(drive_n, 12)}",
          fcnt: drive_n * points + i,
          lat: lat,
          lng: lng,
          reported_at: started_at + i * @point_interval_s
        }

        bearing = bearing + :rand.normal() * 0.4
        next_lat = lat + @step_m * :math.cos(bearing) / 111_320
        next_lng = lng + @step_m * :math.sin(bearing) / (111_320 * :math.cos(lat * :math.pi() / 180))

        {point, {next_lat, next_lng, bearing}}
      end)

    walk
  end

  defp heard_by(point, hotspots) do
    hotspots
    |> Enum.filter(fn h -> point.reported_at >= h.online_at and point.reported_at <= h.offline_at end)
    |> Enum.flat_map(fn h ->
      distance = Geocalc.distance_between([point.lat, point.lng], [h.lat, h.lng])
      rssi = Float.round(-10 - 32 * :math.log10(max(distance, 20)) + :rand.normal() * 5, 0)

      if distance <= @max_range_m and rssi > @min_rssi do
        snr = ((rssi + 118) / 2.5 + :rand.normal() * 2) |> max(-20.0) |> min(10.0) |> Float.round(1)
        [Map.merge(h, %{rssi: rssi, snr: snr})]
      else
        []
      end
    end)
  end

  defp to_payload(point, heard) do
    reported_at_ms = point.reported_at * 1000

    %{
      "app_eui" => "0000000000000000",
      "dev_eui" => point.device_id |> :erlang.phash2() |> Integer.to_string(16) |> String.pad_leading(16, "0"),
      "id" => point.device_id,
      "fcnt" => point.fcnt,
      "reported_at" => reported_at_ms,
      "decoded" => %{
        "payload" => %{
          "latitude" => point.lat,
          "longitude" => point.lng,
          "altitude" => 10,
          "accuracy" => 2.5
        },
        "status" => "success"
      },
      "hotspots" =>
        Enum.map(heard, fn h ->
          %{
            "id" => h.address,
            "name" => h.name,
            "lat" => h.lat,
            "long" => h.lng,
            "rssi" => h.rssi,
            "snr" => h.snr,
            "frequency" => 904.3,
            "spreading" => "SF10BW125",
            "reported_at" => reported_at_ms
          }
        end)
    }
  end

  defp rand_float(min, max), do: min + :rand.uniform() * (max - min)

  defp rand_between(min, max) when max <= min, do: min
  defp rand_between(min, max), do: min + :rand.uniform(max - min)
end
