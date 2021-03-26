defmodule Mix.Tasks.LoadMappersCsv do
  use Mix.Task

  alias NimbleCSV.RFC4180, as: CSV
  alias Mappers.Ingest

  @shortdoc "Load Mappers V1 Database into Current from CSV dumps"
  def run(_) do
    # start our application
    Mix.Task.run("app.start")

    IO.puts("Starting......")

    IO.puts("Loading CSVs.....")
    hotspots = load_csv("~/code/mappers/mappers/hotspots_full.csv")
    uplinks = load_csv("~/code/mappers/mappers/uplinks_full.csv")

    IO.puts("hotspot rows: #{Enum.count(hotspots)}")
    IO.puts("uplink rows: #{Enum.count(uplinks)}")

    # procs = Enum.to_list(1..16)
    procs = [1]

    pid =
      procs
      |> Enum.map(fn proc_id ->
        spawn(fn -> load_uplink(proc_id, uplinks, hotspots) end)
      end)

    # Start monitoring `pid`
    ref = Process.monitor(Enum.at(pid, 0))

    # Wait until the process monitored by `ref` is down.
    receive do
      {:DOWN, ^ref, _, _, _} ->
        IO.puts("Process #{inspect(pid)} is down")
    end
  end

  def load_uplink(num, uplinks, hotspots) do
    Enum.each(uplinks, fn uplink ->
      uplink_id = Enum.at(uplink, 0)
      IO.puts(num)
      IO.puts(uplink_id)

      hotspot_index =
        Enum.find_index(hotspots, fn hotspot -> uplink_id == Enum.at(hotspot, 1) end)

      hotspot = Enum.at(hotspots, hotspot_index)
      hotspot_uplink_id = Enum.at(hotspot, 1)

      IO.puts(hotspot_uplink_id)

      if hotspot_uplink_id != nil do

        decoded_map = %{
          "payload" => %{
            "latitude" => if Enum.at(uplink, 9) == "0" do 0.0 else String.to_float(Enum.at(uplink, 9)) end ,
            "longitude" => if Enum.at(uplink, 10) == "0" do 0.0 else String.to_float(Enum.at(uplink, 10)) end
          }
        }

        hotspots_map = %{
          "id" => Enum.at(hotspot, 0),
          "name" => Enum.at(hotspot, 2),
          "lat" => if Enum.at(hotspot, 4) == "0" do 0.0 else String.to_float(Enum.at(hotspot, 4)) end,
          "long" => if Enum.at(hotspot, 5) == "0" do 0.0 else String.to_float(Enum.at(hotspot, 5)) end,
          "rssi" => Kernel.trunc(String.to_float(Enum.at(hotspot, 6))),
          "snr" => String.to_float(Enum.at(hotspot, 7)),
          "frequency" => 0,
          "spreading" => Enum.at(hotspot, 8),
          "reported_at" => (DateTime.to_unix(elem(DateTime.from_iso8601("#{Enum.at(hotspot, 9)}Z"), 1))*1000)
        }

        message =
          %{}
          |> Map.put("id", Enum.at(uplink, 1))
          |> Map.put("app_eui", "0")
          |> Map.put("dev_eui", Enum.at(uplink, 3))
          |> Map.put("reported_at", (DateTime.to_unix(elem(DateTime.from_iso8601("#{Enum.at(uplink, 5)}Z"), 1)))*1000)
          |> Map.put("fcnt", String.to_integer(Enum.at(uplink, 7)))
          |> Map.put("decoded", decoded_map)
          |> Map.put("hotspots", [hotspots_map])
          |> Map.put("gps_accuracy", String.to_integer(Enum.at(uplink, 14)))

        Ingest.ingest_uplink(message)
      end
    end)
  end

  def load_csv(path) do
    path
    |> Path.expand(__DIR__)
    |> File.read!()
    |> CSV.parse_string()

    # |> File.stream!()
    # |> CSV.parse_stream()
  end
end
