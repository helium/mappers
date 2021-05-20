defmodule Mix.Tasks.H3PopulateFixPoly do
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

    IO.puts("Hex: #{hex}")

    if :h3.is_valid(hex) do
      IO.puts(length(poly))

      cond do
        length(poly) == 5 ->

          IO.puts"Polygon Sides: #{length(poly)}"
          lng_0 = elem(Enum.at(poly, 0), 1)
          lng_l =
            Enum.reduce(poly, [], fn coords, acc ->
              lng_c = elem(coords, 1)
              val = abs(lng_0 - lng_c)
              IO.puts("\nArc Length: #{val}")
              IO.puts("lng_c: #{lng_c}")

              if val > 180 do
                IO.puts("***********Is Transmeridian**********")
                if lng_c < 0 do
                  IO.puts("lng_c + 360: #{lng_c + 360}\n")
                  [lng_c + 360 | acc]
                else
                  [lng_c * -1 | acc]
                end

              else
                [lng_c | acc]
              end
            end)

          lng_l = Enum.reverse(lng_l)

          geom_v =
            %{}
            |> Map.put(:id, Kernel.inspect(hex))
            |> Map.put(:state, "unmapped")
            |> Map.put(:avg_rssi, Enum.random(-70..-110))
            |> Map.put(:geom, %Geo.Polygon{
              coordinates: [
                [
                  {Enum.at(lng_l, 0), elem(Enum.at(poly, 0), 0)},
                  {Enum.at(lng_l, 1), elem(Enum.at(poly, 1), 0)},
                  {Enum.at(lng_l, 2), elem(Enum.at(poly, 2), 0)},
                  {Enum.at(lng_l, 3), elem(Enum.at(poly, 3), 0)},
                  {Enum.at(lng_l, 4), elem(Enum.at(poly, 4), 0)},
                  {Enum.at(lng_l, 0), elem(Enum.at(poly, 0), 0)}
                ]
              ],
              srid: 4326
            })

          %Mappers.H3.Res9{}
          |> Mappers.H3.Res9.changeset(geom_v)
          |> Mappers.Repo.insert()
          |> case do
            {:ok, _} -> IO.puts("Insert Successful")
            {:error, changeset} -> IO.puts("Insert Error #{changeset}")
          end

        length(poly) == 6 ->

        IO.puts"Polygon Sides: #{length(poly)}"
          lng_0 = elem(Enum.at(poly, 0), 1)
          lng_l =
            Enum.reduce(poly, [], fn coords, acc ->
              lng_c = elem(coords, 1)
              val = abs(lng_0 - lng_c)
              IO.puts("\nArc Length: #{val}")
              IO.puts("lng_c: #{lng_c}")

              if val > 180 do
                IO.puts("***********Is Transmeridian**********")
                if lng_c < 0 do
                  IO.puts("lng_c + 360: #{lng_c + 360}\n")
                  [lng_c + 360 | acc]
                else
                  [lng_c * -1 | acc]
                end

              else
                [lng_c | acc]
              end
            end)

          lng_l = Enum.reverse(lng_l)

          geom_v =
            %{}
            |> Map.put(:id, Kernel.inspect(hex))
            |> Map.put(:state, "unmapped")
            |> Map.put(:avg_rssi, Enum.random(-70..-110))
            |> Map.put(:geom, %Geo.Polygon{
              coordinates: [
                [
                  {Enum.at(lng_l, 0), elem(Enum.at(poly, 0), 0)},
                  {Enum.at(lng_l, 1), elem(Enum.at(poly, 1), 0)},
                  {Enum.at(lng_l, 2), elem(Enum.at(poly, 2), 0)},
                  {Enum.at(lng_l, 3), elem(Enum.at(poly, 3), 0)},
                  {Enum.at(lng_l, 4), elem(Enum.at(poly, 4), 0)},
                  {Enum.at(lng_l, 5), elem(Enum.at(poly, 5), 0)},
                  {Enum.at(lng_l, 0), elem(Enum.at(poly, 0), 0)}
                ]
              ],
              srid: 4326
            })

          %Mappers.H3.Res9{}
          |> Mappers.H3.Res9.changeset(geom_v)
          |> Mappers.Repo.insert()
          |> case do
            {:ok, _} -> IO.puts("Insert Successful")
            {:error, changeset} -> IO.puts("Insert Error #{changeset}")
          end

        length(poly) == 7 ->

          IO.puts"Polygon Sides: #{length(poly)}"
          lng_0 = elem(Enum.at(poly, 0), 1)
          lng_l =
            Enum.reduce(poly, [], fn coords, acc ->
              lng_c = elem(coords, 1)
              val = abs(lng_0 - lng_c)
              IO.puts("\nArc Length: #{val}")
              IO.puts("lng_c: #{lng_c}")

              if val > 180 do
                IO.puts("***********Is Transmeridian**********")
                if lng_c < 0 do
                  IO.puts("lng_c + 360: #{lng_c + 360}\n")
                  [lng_c + 360 | acc]
                else
                  [lng_c * -1 | acc]
                end

              else
                [lng_c | acc]
              end
            end)

          lng_l = Enum.reverse(lng_l)

          geom_v =
            %{}
            |> Map.put(:id, Kernel.inspect(hex))
            |> Map.put(:state, "unmapped")
            |> Map.put(:avg_rssi, Enum.random(-70..-110))
            |> Map.put(:geom, %Geo.Polygon{
              coordinates: [
                [
                 {Enum.at(lng_l, 0), elem(Enum.at(poly, 0), 0)},
                  {Enum.at(lng_l, 1), elem(Enum.at(poly, 1), 0)},
                  {Enum.at(lng_l, 2), elem(Enum.at(poly, 2), 0)},
                  {Enum.at(lng_l, 3), elem(Enum.at(poly, 3), 0)},
                  {Enum.at(lng_l, 4), elem(Enum.at(poly, 4), 0)},
                  {Enum.at(lng_l, 5), elem(Enum.at(poly, 5), 0)},
                  {Enum.at(lng_l, 6), elem(Enum.at(poly, 6), 0)},
                  {Enum.at(lng_l, 0), elem(Enum.at(poly, 0), 0)}
                ]
              ],
              srid: 4326
            })

          %Mappers.H3.Res9{}
          |> Mappers.H3.Res9.changeset(geom_v)
          |> Mappers.Repo.insert()
          |> case do
            {:ok, _} -> IO.puts("Insert Successful")
            {:error, changeset} -> IO.puts("Insert Error #{changeset}")
          end

        length(poly) == 8 ->

        IO.puts"Polygon Sides: #{length(poly)}"
          lng_0 = elem(Enum.at(poly, 0), 1)
          lng_l =
            Enum.reduce(poly, [], fn coords, acc ->
              lng_c = elem(coords, 1)
              val = abs(lng_0 - lng_c)
              IO.puts("\nArc Length: #{val}")
              IO.puts("lng_c: #{lng_c}")

              if val > 180 do
                IO.puts("***********Is Transmeridian**********")
                if lng_c < 0 do
                  IO.puts("lng_c + 360: #{lng_c + 360}\n")
                  [lng_c + 360 | acc]
                else
                  [lng_c * -1 | acc]
                end

              else
                [lng_c | acc]
              end
            end)

          lng_l = Enum.reverse(lng_l)

          geom_v =
            %{}
            |> Map.put(:id, Kernel.inspect(hex))
            |> Map.put(:state, "unmapped")
            |> Map.put(:avg_rssi, Enum.random(-70..-110))
            |> Map.put(:geom, %Geo.Polygon{
              coordinates: [
                [
                  {Enum.at(lng_l, 0), elem(Enum.at(poly, 0), 0)},
                  {Enum.at(lng_l, 1), elem(Enum.at(poly, 1), 0)},
                  {Enum.at(lng_l, 2), elem(Enum.at(poly, 2), 0)},
                  {Enum.at(lng_l, 3), elem(Enum.at(poly, 3), 0)},
                  {Enum.at(lng_l, 4), elem(Enum.at(poly, 4), 0)},
                  {Enum.at(lng_l, 5), elem(Enum.at(poly, 5), 0)},
                  {Enum.at(lng_l, 6), elem(Enum.at(poly, 6), 0)},
                  {Enum.at(lng_l, 7), elem(Enum.at(poly, 7), 0)},
                  {Enum.at(lng_l, 0), elem(Enum.at(poly, 0), 0)}
                ]
              ],
              srid: 4326
            })

          %Mappers.H3.Res9{}
          |> Mappers.H3.Res9.changeset(geom_v)
          |> Mappers.Repo.insert()
          |> case do
            {:ok, _} -> IO.puts("Insert Successful")
            {:error, changeset} -> IO.puts("Insert Error #{changeset}")
          end

        length(poly) == 9 ->

          IO.puts"Polygon Sides: #{length(poly)}"
          lng_0 = elem(Enum.at(poly, 0), 1)
          lng_l =
            Enum.reduce(poly, [], fn coords, acc ->
              lng_c = elem(coords, 1)
              val = abs(lng_0 - lng_c)
              IO.puts("\nArc Length: #{val}")
              IO.puts("lng_c: #{lng_c}")

              if val > 180 do
                IO.puts("***********Is Transmeridian**********")
                if lng_c < 0 do
                  IO.puts("lng_c + 360: #{lng_c + 360}\n")
                  [lng_c + 360 | acc]
                else
                  [lng_c * -1 | acc]
                end

              else
                [lng_c | acc]
              end
            end)

          lng_l = Enum.reverse(lng_l)

          geom_v =
            %{}
            |> Map.put(:id, Kernel.inspect(hex))
            |> Map.put(:state, "unmapped")
            |> Map.put(:avg_rssi, Enum.random(-70..-110))
            |> Map.put(:geom, %Geo.Polygon{
              coordinates: [
                [
                  {Enum.at(lng_l, 0), elem(Enum.at(poly, 0), 0)},
                  {Enum.at(lng_l, 1), elem(Enum.at(poly, 1), 0)},
                  {Enum.at(lng_l, 2), elem(Enum.at(poly, 2), 0)},
                  {Enum.at(lng_l, 3), elem(Enum.at(poly, 3), 0)},
                  {Enum.at(lng_l, 4), elem(Enum.at(poly, 4), 0)},
                  {Enum.at(lng_l, 5), elem(Enum.at(poly, 5), 0)},
                  {Enum.at(lng_l, 6), elem(Enum.at(poly, 6), 0)},
                  {Enum.at(lng_l, 7), elem(Enum.at(poly, 7), 0)},
                  {Enum.at(lng_l, 8), elem(Enum.at(poly, 8), 0)},
                  {Enum.at(lng_l, 0), elem(Enum.at(poly, 0), 0)}
                ]
              ],
              srid: 4326
            })

          %Mappers.H3.Res9{}
          |> Mappers.H3.Res9.changeset(geom_v)
          |> Mappers.Repo.insert()
          |> case do
            {:ok, _} -> IO.puts("Insert Successful")
            {:error, changeset} -> IO.puts("Insert Error #{changeset}")
          end

        length(poly) == 10 ->

          IO.puts"Polygon Sides: #{length(poly)}"
          lng_0 = elem(Enum.at(poly, 0), 1)
          lng_l =
            Enum.reduce(poly, [], fn coords, acc ->
              lng_c = elem(coords, 1)
              val = abs(lng_0 - lng_c)
              IO.puts("\nArc Length: #{val}")
              IO.puts("lng_c: #{lng_c}")

              if val > 180 do
                IO.puts("***********Is Transmeridian**********")
                if lng_c < 0 do
                  IO.puts("lng_c + 360: #{lng_c + 360}\n")
                  [lng_c + 360 | acc]
                else
                  [lng_c * -1 | acc]
                end

              else
                [lng_c | acc]
              end
            end)

          lng_l = Enum.reverse(lng_l)

          geom_v =
            %{}
            |> Map.put(:id, Kernel.inspect(hex))
            |> Map.put(:state, "unmapped")
            |> Map.put(:avg_rssi, Enum.random(-70..-110))
            |> Map.put(:geom, %Geo.Polygon{
              coordinates: [
                [
                 {Enum.at(lng_l, 0), elem(Enum.at(poly, 0), 0)},
                  {Enum.at(lng_l, 1), elem(Enum.at(poly, 1), 0)},
                  {Enum.at(lng_l, 2), elem(Enum.at(poly, 2), 0)},
                  {Enum.at(lng_l, 3), elem(Enum.at(poly, 3), 0)},
                  {Enum.at(lng_l, 4), elem(Enum.at(poly, 4), 0)},
                  {Enum.at(lng_l, 5), elem(Enum.at(poly, 5), 0)},
                  {Enum.at(lng_l, 6), elem(Enum.at(poly, 6), 0)},
                  {Enum.at(lng_l, 7), elem(Enum.at(poly, 7), 0)},
                  {Enum.at(lng_l, 8), elem(Enum.at(poly, 8), 0)},
                  {Enum.at(lng_l, 9), elem(Enum.at(poly, 9), 0)},
                  {Enum.at(lng_l, 0), elem(Enum.at(poly, 0), 0)}
                ]
              ],
              srid: 4326
            })

          %Mappers.H3.Res9{}
          |> Mappers.H3.Res9.changeset(geom_v)
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

    h3res = 1

    IO.puts("Start")

    basecells = :h3.get_res0_indexes()

    indexes =
      Enum.reduce(basecells, [], fn index, acc -> [getChildrenAtRes(index, h3res, []) | acc] end)

    insertChildren(indexes)

    IO.puts("Complete")
  end
end
