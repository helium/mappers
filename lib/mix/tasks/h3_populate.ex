defmodule Mix.Tasks.H3Populate do
  use Mix.Task
  import Ecto.Repo
  alias Mappers.Repo

  @shortdoc "Populates H3 databases with hex"
  def run(_) do
    Mix.Task.run("app.start")

    IO.puts(:h3.from_geo({48.8566, 2.3522}, 9))

    res0_indexes = :h3.get_res0_indexes()
    IO.puts(length(res0_indexes))

    poly = :h3.to_geo_boundary(List.first(res0_indexes))

    IO.puts(is_tuple(Enum.at(poly, 0)))

    for point <- poly do
      IO.puts(elem(point,0))
    end

    geom_v = %{}
    |> Map.put(:id, "1232422")
    |> Map.put(:state, "unmapped")
    |> Map.put(:average_rssi, -100)
    |> Map.put(:geom, %Geo.Polygon{coordinates: [[{-71.1776585052917, 42.3902909739571}, {-71.1776820268866, 42.3903701743239}, {-71.1776063012595, 42.3903825660754}, {-71.1775826583081, 42.3903033653531}, {-71.1776585052917, 42.3902909739571}]], srid: 4269})

    %Mappers.H3.Res9{}
    |> Mappers.H3.Res9.changeset(geom_v)
    |> Mappers.Repo.insert()
    |> case do
      {:ok, struct}       -> IO.puts("Insert Successful")
      {:error, changeset} -> IO.puts("Insert Error")
    end
  end
end
