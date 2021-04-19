defmodule Mix.Tasks.LoadMergedMappersMultiHotspotCsv do
  use Mix.Task

  alias NimbleCSV.RFC4180, as: CSV
  alias Mappers.Ingest

  @shortdoc "Load Mappers V1 Database into Current from CSV dumps"
  def run(_) do
    # start our application
    Mix.Task.run("app.start")

    IO.puts("Starting......")

    IO.puts("Loading CSVs.....")
    # uplinks = load_csv_stream("~/code/mappers/mappers/merged.csv")
    uplinks_csv_streams = load_split_csv("~/code/mappers/mappers/split-merged")

    # IO.puts("uplink rows: #{Enum.count(uplinks)}")
    # load_uplinks(uplinks)

    pid =
      uplinks_csv_streams
      |> Enum.map(fn uplinks ->
        spawn(fn -> load_uplinks(uplinks) end)
      end)

    # Process.sleep(45000)

    # Start monitoring `pid`
    ref = Process.monitor(Enum.at(pid, 0))

    # Wait until the process monitored by `ref` is down.
    receive do
      {:DOWN, ^ref, _, _, _} ->
        IO.puts("Process #{inspect(pid)} is down")
    end
  end

  def load_uplinks(uplinks) do
    Enum.each(uplinks, fn uplink ->
      uplink_id = Enum.at(uplink, 0)
      # IO.puts(uplink_id)

      IO.puts(uplink)

      if uplink_id != nil do
        decoded_map = %{
          "payload" => %{
            "latitude" =>
              if Enum.at(uplink, 9) == "0" or Enum.at(uplink, 9) == "" do
                0.0
              else
                Float.parse(Enum.at(uplink, 9)) |> elem(0)
              end,
            "longitude" =>
              if Enum.at(uplink, 10) == "0" or Enum.at(uplink, 10) == "" do
                0.0
              else
                Float.parse(Enum.at(uplink, 10)) |> elem(0)
              end
          }
        }

        hotspot_count = String.to_integer(Enum.at(uplink, 15))
        starting_index = 16
        hotspot_items_length = 10

        hotspot_list =
          if hotspot_count > 1 do
            Enum.map(1..hotspot_count, fn x ->
              offset = starting_index + (hotspot_items_length * (x-1))
              %{
                "id" => Enum.at(uplink, offset + 1),
                "name" => Enum.at(uplink, offset),
                "lat" =>
                  if Enum.at(uplink, offset + 2) == "0" do
                    0.0
                  else
                    Float.parse(Enum.at(uplink, offset + 2)) |> elem(0)
                  end,
                "long" =>
                  if Enum.at(uplink, offset + 3) == "0" do
                    0.0
                  else
                    Float.parse(Enum.at(uplink, offset + 3)) |> elem(0)
                  end,
                "rssi" => Float.parse(Enum.at(uplink, offset + 4)) |> elem(0),
                "snr" => Float.parse(Enum.at(uplink, offset + 5)) |> elem(0),
                "frequency" => 0,
                "spreading" => Enum.at(uplink, offset + 6),
                "reported_at" =>
                  DateTime.to_unix(
                    elem(
                      DateTime.from_iso8601("#{Enum.at(uplink, offset + 7)}Z"),
                      1
                    )
                  ) * 1000
              }
            end)
          else
            hotspots_map = %{
              "id" => Enum.at(uplink, starting_index + 1),
              "name" => Enum.at(uplink, starting_index),
              "lat" =>
                if Enum.at(uplink, starting_index + 2) == "0" do
                  0.0
                else
                  Float.parse(Enum.at(uplink, starting_index + 2)) |> elem(0)
                end,
              "long" =>
                if Enum.at(uplink, starting_index + 3) == "0" do
                  0.0
                else
                  Float.parse(Enum.at(uplink, starting_index + 3)) |> elem(0)
                end,
              "rssi" => Float.parse(Enum.at(uplink, starting_index + 4)) |> elem(0),
              "snr" => Float.parse(Enum.at(uplink, starting_index + 5)) |> elem(0),
              "frequency" => 0,
              "spreading" => Enum.at(uplink, (starting_index + 6)),
              "reported_at" =>
                DateTime.to_unix(
                  elem(
                    DateTime.from_iso8601("#{Enum.at(uplink, starting_index + 7)}Z"),
                    1
                  )
                ) * 1000
            }
            [hotspots_map]
          end

        message =
          %{}
          |> Map.put("id", Enum.at(uplink, 1))
          |> Map.put("app_eui", "0")
          |> Map.put("dev_eui", Enum.at(uplink, 3))
          |> Map.put(
            "reported_at",
            DateTime.to_unix(elem(DateTime.from_iso8601("#{Enum.at(uplink, 5)}Z"), 1)) * 1000
          )
          |> Map.put("fcnt", Integer.parse(Enum.at(uplink, 7)) |> elem(0))
          |> Map.put("decoded", decoded_map)
          |> Map.put("hotspots", hotspot_list)
          |> Map.put("gps_accuracy", Integer.parse(Enum.at(uplink, 14)) |> elem(0))

        Ingest.ingest_uplink(message)
      end
    end)
  end

  def load_split_csv(dir) do
    {_, files} = File.ls(Path.expand(dir))

    Enum.map(files, fn file ->
      load_csv_file("#{Path.expand(dir)}/#{file}")
    end)
  end

  def load_csv_stream(path) do
    path
    |> Path.expand(__DIR__)
    |> File.stream!(read_ahead: 100_000)
    |> CSV.parse_stream()
  end

  def load_csv_file(path) do
    path
    |> Path.expand(__DIR__)
    |> File.read!()
    |> CSV.parse_string()
  end
end
