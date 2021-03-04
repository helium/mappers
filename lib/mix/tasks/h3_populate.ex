defmodule Mix.Tasks.H3Populate do
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
        true -> IO.puts("done")
      end
    end)
  end

  def insertChildren(indexes) do
    Enum.each(indexes, fn index ->
      cond do
        is_integer(index) && index > 0 -> insertIndex(index)
        is_list(index) -> insertChildren(index)
        true -> IO.puts("done")
      end
    end)
  end

  def insertIndex(hex) do
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

  @shortdoc "Populates H3 databases with hex"
  def run(_) do
    Mix.Task.run("app.start")

    IO.puts("Start")
    basecells = :h3.get_res0_indexes()
    IO.puts(length(basecells))

    h3res = 4

    indexes =
      Enum.reduce(basecells, [], fn index, acc -> [getChildrenAtRes(index, h3res, []) | acc] end)

    insertChildren(indexes)
  end
end
