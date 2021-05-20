defmodule Mix.Tasks.H3GeojsonToDb do
  use Mix.Task

  @shortdoc "Sync Mappers Opt In State on Console with Database"
  def run(_) do
    # start our application
    Mix.Task.run("app.start")

    features = getFeatures()
    # Enum.each(features.geometries, &IO.inspect/1)

    # Kernel.inspect(:h3.from_geo(Enum.at(Enum.at(feature.coordinates, 0), 0), 9))

    Enum.each(features.geometries, fn feature ->
      geom_v =
        %{}
        |> Map.put(:id, UUID.uuid4())
        |> Map.put(:state, "unmapped")
        |> Map.put(:avg_rssi, Kernel.round(feature.properties["rssi"]))
        |> Map.put(:geom, %Geo.Polygon{coordinates: feature.coordinates, srid: 4326})

      %Mappers.H3.Res9{}
      |> Mappers.H3.Res9.changeset(geom_v)
      |> Mappers.Repo.insert()
      |> case do
        {:ok, _} -> IO.puts("Insert Successful")
        {:error, changeset} -> IO.puts("Insert Error #{changeset}")
      end
    end)
  end

  def getFeatures() do
    "../../../coverage_uplinks_h3_9.geojson"
    |> Path.expand(__DIR__)
    |> File.read!()
    |> Jason.decode!()
    |> Geo.JSON.decode!()
  end
end
