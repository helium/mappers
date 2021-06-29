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

    # load single csv file sequentially
    # uplinks = load_csv_file("~/code/mappers/mappers/merged_multi_hotspot_6-24-21_1630gmt.csv")
    # IO.puts("uplink rows: #{Enum.count(uplinks)}")
    # load_uplinks(uplinks)

    # load multiple csv files in parallel
    uplinks_csv_streams = load_split_csv("~/code/mappers/mappers/split-merged")

    pids =
      uplinks_csv_streams
      |> Enum.map(fn uplinks ->
        spawn(fn -> load_uplinks(uplinks) end)
      end)

    refs =
      pids
      |> Enum.map(fn pid ->
        Process.monitor(pid)
      end)

    Enum.each(refs, fn ref ->
      receive do
        {:DOWN, ^ref, _, _, _} -> IO.puts("process down")
      end
    end)
  end

  def load_uplinks(uplinks) do
    Enum.each(uplinks, fn uplink ->
      uplink_id = Enum.at(uplink, 0)

      try do
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
                end,
              "altitude" =>
                if Enum.at(uplink, 11) == "" or Enum.at(uplink, 11) == "0.0" do
                  0
                else
                  Integer.parse(Enum.at(uplink, 11)) |> elem(0)
                end,
              "accuracy" =>
                if Enum.at(uplink, 14) == "0" or Enum.at(uplink, 14) == "" do
                  0.0
                else
                  Float.parse(Enum.at(uplink, 14)) |> elem(0)
                end
            }
          }

          hotspot_count = String.to_integer(Enum.at(uplink, 15))
          starting_index = 16
          hotspot_items_length = 10

          hotspot_list =
            if hotspot_count > 1 do
              Enum.map(1..hotspot_count, fn x ->
                offset = starting_index + hotspot_items_length * (x - 1)

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
                "spreading" => Enum.at(uplink, starting_index + 6),
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
          |> case do
            %{error: message} -> IO.puts("#{Enum.at(uplink, 5)} Error: #{message}")
            _ -> IO.puts("Uplink Ingest Success : #{uplink_id}")
          end
        end
      rescue
        e in Ecto.ConstraintError -> IO.puts("Rescued Error: " <> e.message)
        e in ArgumentError -> IO.puts("Rescued Error: " <> e.message)
      end
    end)
  end

  def load_split_csv(dir) do
    {_, files} = File.ls(Path.expand(dir))

    Enum.map(files, fn file ->
      load_csv_stream("#{Path.expand(dir)}/#{file}")
    end)
  end

  def load_csv_stream(path) do
    path
    |> Path.expand(__DIR__)
    |> File.stream!()
    |> CSV.parse_stream()
  end

  def load_csv_file(path) do
    path
    |> Path.expand(__DIR__)
    |> File.read!()
    |> CSV.parse_string()
  end
end
