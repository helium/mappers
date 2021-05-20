defmodule Mix.Tasks.H3PopulateFromPolyfill do
  use Mix.Task
  import Ecto.Repo

  def getChildrenAtRes(h3_index, target_res, acc) do
    if :h3.is_valid(h3_index) do
      next_res = :h3.get_resolution(h3_index) + 1

      Enum.reduce(:h3.children(h3_index, next_res), acc, fn child, acc ->
        if next_res >= target_res do
          [child | acc]
        else
          if child != 0 do
            getChildrenAtRes(child, target_res, acc)
          else
            acc
          end
        end
      end)
    end
  end

  def printChildren(indexes) when is_list(indexes) do
    Enum.each(indexes, fn index ->
      cond do
        is_integer(index) -> IO.puts(index)
        is_list(index) -> printChildren(index)
        true -> IO.puts("no integer or list")
      end
    end)
  end

  def insertChildren(indexes) do
    Enum.each(indexes, fn index ->
      cond do
        is_integer(index) && index > 0 -> insertIndex(index)
        is_list(index) -> insertChildren(index)
        true -> IO.puts("no integer or list")
      end
    end)
  end

  def insertIndex(hex) do
    poly = :h3.to_geo_boundary(hex)

    IO.puts(hex)

    if :h3.is_valid(hex) do
      IO.puts(length(poly))

      cond do
        length(poly) == 5 ->
          geom_v =
            %{}
            |> Map.put(:id, Kernel.inspect(hex))
            |> Map.put(:state, "unmapped")
            |> Map.put(:avg_rssi, Enum.random(-70..-110))
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

          %Mappers.H3.Res9Blank{}
          |> Mappers.H3.Res9Blank.changeset(geom_v)
          |> Mappers.Repo.insert()
          |> case do
            {:ok, _} -> IO.puts("Insert Successful")
            {:error, changeset} -> IO.puts("Insert Error #{changeset}")
          end

        length(poly) == 6 ->
          geom_v =
            %{}
            |> Map.put(:id, Kernel.inspect(hex))
            |> Map.put(:state, "unmapped")
            |> Map.put(:avg_rssi, Enum.random(-70..-110))
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

          %Mappers.H3.Res9Blank{}
          |> Mappers.H3.Res9Blank.changeset(geom_v)
          |> Mappers.Repo.insert()
          |> case do
            {:ok, _} -> IO.puts("Insert Successful")
            {:error, changeset} -> IO.puts("Insert Error #{changeset}")
          end

        length(poly) == 7 ->
          geom_v =
            %{}
            |> Map.put(:id, Kernel.inspect(hex))
            |> Map.put(:state, "unmapped")
            |> Map.put(:avg_rssi, Enum.random(-70..-110))
            |> Map.put(:geom, %Geo.Polygon{
              coordinates: [
                [
                  {elem(Enum.at(poly, 0), 1), elem(Enum.at(poly, 0), 0)},
                  {elem(Enum.at(poly, 1), 1), elem(Enum.at(poly, 1), 0)},
                  {elem(Enum.at(poly, 2), 1), elem(Enum.at(poly, 2), 0)},
                  {elem(Enum.at(poly, 3), 1), elem(Enum.at(poly, 3), 0)},
                  {elem(Enum.at(poly, 4), 1), elem(Enum.at(poly, 4), 0)},
                  {elem(Enum.at(poly, 5), 1), elem(Enum.at(poly, 5), 0)},
                  {elem(Enum.at(poly, 6), 1), elem(Enum.at(poly, 6), 0)},
                  {elem(Enum.at(poly, 0), 1), elem(Enum.at(poly, 0), 0)}
                ]
              ],
              srid: 4326
            })

          %Mappers.H3.Res9Blank{}
          |> Mappers.H3.Res9Blank.changeset(geom_v)
          |> Mappers.Repo.insert()
          |> case do
            {:ok, _} -> IO.puts("Insert Successful")
            {:error, changeset} -> IO.puts("Insert Error #{changeset}")
          end

        length(poly) == 8 ->
          geom_v =
            %{}
            |> Map.put(:id, Kernel.inspect(hex))
            |> Map.put(:state, "unmapped")
            |> Map.put(:avg_rssi, Enum.random(-70..-110))
            |> Map.put(:geom, %Geo.Polygon{
              coordinates: [
                [
                  {elem(Enum.at(poly, 0), 1), elem(Enum.at(poly, 0), 0)},
                  {elem(Enum.at(poly, 1), 1), elem(Enum.at(poly, 1), 0)},
                  {elem(Enum.at(poly, 2), 1), elem(Enum.at(poly, 2), 0)},
                  {elem(Enum.at(poly, 3), 1), elem(Enum.at(poly, 3), 0)},
                  {elem(Enum.at(poly, 4), 1), elem(Enum.at(poly, 4), 0)},
                  {elem(Enum.at(poly, 5), 1), elem(Enum.at(poly, 5), 0)},
                  {elem(Enum.at(poly, 6), 1), elem(Enum.at(poly, 6), 0)},
                  {elem(Enum.at(poly, 7), 1), elem(Enum.at(poly, 7), 0)},
                  {elem(Enum.at(poly, 0), 1), elem(Enum.at(poly, 0), 0)}
                ]
              ],
              srid: 4326
            })

          %Mappers.H3.Res9Blank{}
          |> Mappers.H3.Res9Blank.changeset(geom_v)
          |> Mappers.Repo.insert()
          |> case do
            {:ok, _} -> IO.puts("Insert Successful")
            {:error, changeset} -> IO.puts("Insert Error #{changeset}")
          end

        length(poly) == 9 ->
          geom_v =
            %{}
            |> Map.put(:id, Kernel.inspect(hex))
            |> Map.put(:state, "unmapped")
            |> Map.put(:avg_rssi, Enum.random(-70..-110))
            |> Map.put(:geom, %Geo.Polygon{
              coordinates: [
                [
                  {elem(Enum.at(poly, 0), 1), elem(Enum.at(poly, 0), 0)},
                  {elem(Enum.at(poly, 1), 1), elem(Enum.at(poly, 1), 0)},
                  {elem(Enum.at(poly, 2), 1), elem(Enum.at(poly, 2), 0)},
                  {elem(Enum.at(poly, 3), 1), elem(Enum.at(poly, 3), 0)},
                  {elem(Enum.at(poly, 4), 1), elem(Enum.at(poly, 4), 0)},
                  {elem(Enum.at(poly, 5), 1), elem(Enum.at(poly, 5), 0)},
                  {elem(Enum.at(poly, 6), 1), elem(Enum.at(poly, 6), 0)},
                  {elem(Enum.at(poly, 7), 1), elem(Enum.at(poly, 7), 0)},
                  {elem(Enum.at(poly, 8), 1), elem(Enum.at(poly, 8), 0)},
                  {elem(Enum.at(poly, 0), 1), elem(Enum.at(poly, 0), 0)}
                ]
              ],
              srid: 4326
            })

          %Mappers.H3.Res9Blank{}
          |> Mappers.H3.Res9Blank.changeset(geom_v)
          |> Mappers.Repo.insert()
          |> case do
            {:ok, _} -> IO.puts("Insert Successful")
            {:error, changeset} -> IO.puts("Insert Error #{changeset}")
          end

        length(poly) == 10 ->
          geom_v =
            %{}
            |> Map.put(:id, Kernel.inspect(hex))
            |> Map.put(:state, "unmapped")
            |> Map.put(:avg_rssi, Enum.random(-70..-110))
            |> Map.put(:geom, %Geo.Polygon{
              coordinates: [
                [
                  {elem(Enum.at(poly, 0), 1), elem(Enum.at(poly, 0), 0)},
                  {elem(Enum.at(poly, 1), 1), elem(Enum.at(poly, 1), 0)},
                  {elem(Enum.at(poly, 2), 1), elem(Enum.at(poly, 2), 0)},
                  {elem(Enum.at(poly, 3), 1), elem(Enum.at(poly, 3), 0)},
                  {elem(Enum.at(poly, 4), 1), elem(Enum.at(poly, 4), 0)},
                  {elem(Enum.at(poly, 5), 1), elem(Enum.at(poly, 5), 0)},
                  {elem(Enum.at(poly, 6), 1), elem(Enum.at(poly, 6), 0)},
                  {elem(Enum.at(poly, 7), 1), elem(Enum.at(poly, 7), 0)},
                  {elem(Enum.at(poly, 8), 1), elem(Enum.at(poly, 8), 0)},
                  {elem(Enum.at(poly, 9), 1), elem(Enum.at(poly, 9), 0)},
                  {elem(Enum.at(poly, 0), 1), elem(Enum.at(poly, 0), 0)}
                ]
              ],
              srid: 4326
            })

          %Mappers.H3.Res9Blank{}
          |> Mappers.H3.Res9Blank.changeset(geom_v)
          |> Mappers.Repo.insert()
          |> case do
            {:ok, _} -> IO.puts("Insert Successful")
            {:error, changeset} -> IO.puts("Insert Error #{changeset}")
          end
      end
    end
  end

  @shortdoc "Populates H3 databases with hex"
  def run(_) do
    Mix.Task.run("app.start")

    h3res = 9

    IO.puts"Start"

    indexes = :h3.polyfill([[{37.96,-122.85}, {37.98, -121.60}, {37.22, -121.57}, {37.22, -122.81}]], h3res)
    insertChildren(indexes)

    IO.puts"Complete"
  end
end
