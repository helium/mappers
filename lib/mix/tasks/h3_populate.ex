defmodule Mix.Tasks.H3Populate do
  use Mix.Task
  import Ecto.Repo
  alias Mappers.Repo

  @shortdoc "Populates H3 databases with hex"
  def run(_) do
    Mix.Task.run("app.start")

    IO.puts("Start")
    res0_indexes = :h3.get_res0_indexes()
    IO.puts(length(res0_indexes))

    for hex <- res0_indexes do
      poly = :h3.to_geo_boundary(hex)

      IO.puts(hex)

      if :h3.is_valid(hex) do
        IO.puts(length(poly))

        if length(poly) == 5 do
          geom_v =
            %{}
            |> Map.put(:id, Kernel.inspect(hex))
            |> Map.put(:state, "unmapped")
            |> Map.put(:average_rssi, -100)
            |> Map.put(:geom, %Geo.Polygon{
              coordinates: [
                [
                  {elem(Enum.at(poly, 0), 1), elem(Enum.at(poly, 0), 0)},
                  {elem(Enum.at(poly, 1), 1), elem(Enum.at(poly, 1), 0)},
                  {elem(Enum.at(poly, 2), 1), elem(Enum.at(poly, 2), 0)},
                  {elem(Enum.at(poly, 3), 1), elem(Enum.at(poly, 3), 0)},
                  {elem(Enum.at(poly, 4), 1), elem(Enum.at(poly, 4), 0)},
                  {elem(Enum.at(poly, 0), 1), elem(Enum.at(poly, 0), 0)}
                ]
              ],
              srid: 4326
            })

          %Mappers.H3.Res9{}
          |> Mappers.H3.Res9.changeset(geom_v)
          |> Mappers.Repo.insert()
          |> case do
            {:ok, struct} -> IO.puts("Insert Successful")
            {:error, changeset} -> IO.puts("Insert Error #{changeset}")
          end
        else
          geom_v =
            %{}
            |> Map.put(:id, Kernel.inspect(hex))
            |> Map.put(:state, "unmapped")
            |> Map.put(:average_rssi, -100)
            |> Map.put(:geom, %Geo.Polygon{
              coordinates: [
                [
                  {elem(Enum.at(poly, 0), 1), elem(Enum.at(poly, 0), 0)},
                  {elem(Enum.at(poly, 1), 1), elem(Enum.at(poly, 1), 0)},
                  {elem(Enum.at(poly, 2), 1), elem(Enum.at(poly, 2), 0)},
                  {elem(Enum.at(poly, 3), 1), elem(Enum.at(poly, 3), 0)},
                  {elem(Enum.at(poly, 4), 1), elem(Enum.at(poly, 4), 0)},
                  {elem(Enum.at(poly, 5), 1), elem(Enum.at(poly, 5), 0)},
                  {elem(Enum.at(poly, 0), 1), elem(Enum.at(poly, 0), 0)}
                ]
              ],
              srid: 4326
            })

          %Mappers.H3.Res9{}
          |> Mappers.H3.Res9.changeset(geom_v)
          |> Mappers.Repo.insert()
          |> case do
            {:ok, struct} -> IO.puts("Insert Successful")
            {:error, changeset} -> IO.puts("Insert Error #{changeset}")
          end
        end
      end
    end
  end
end
