defmodule Mix.Tasks.LoadMergedMappersCsv do
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
      IO.puts(uplink_id)

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

        hotspots_map = %{
          "id" => Enum.at(uplink, 16),
          "name" => Enum.at(uplink, 15),
          "lat" =>
            if Enum.at(uplink, 17) == "0" do
              0.0
            else
              Float.parse(Enum.at(uplink, 17)) |> elem(0)
            end,
          "long" =>
            if Enum.at(uplink, 18) == "0" do
              0.0
            else
              Float.parse(Enum.at(uplink, 18)) |> elem(0)
            end,
          "rssi" => Float.parse(Enum.at(uplink, 19)) |> elem(0),
          "snr" => Float.parse(Enum.at(uplink, 20)) |> elem(0),
          "frequency" => 0,
          "spreading" => Enum.at(uplink, 21),
          "reported_at" =>
            DateTime.to_unix(elem(DateTime.from_iso8601("#{Enum.at(uplink, 22)}Z"), 1)) * 1000
        }

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
          |> Map.put("hotspots", [hotspots_map])
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
