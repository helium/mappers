defmodule Mappers.H3 do
  alias Mappers.Repo
  alias Mappers.H3.Res9

  def create(message) do
    # grab lat/lng if available
    lat = message["decoded"]["payload"]["latitude"]
    lng = message["decoded"]["payload"]["longitude"]

    # find h3 index
    h3_res9_id = :h3.from_geo({lat, lng}, 9)
    h3_res9_id_s = Integer.to_string(h3_res9_id)

    res9_temp = Repo.get(Res9, h3_res9_id_s)

    # check if h3 index exist in the db
    if res9_temp != nil do

      # IO.puts(res9_temp.geom)
      # IO.puts"here"
      # # index does not exist, create new
      # res9 =
      #   %{}
      #   |> Map.put(:id, h3_res9_id_s)
      #   |> Map.put(:state, "mapped")
      #   |> Map.put(:average_rssi, Enum.at(message["hotspots"], 0)["rssi"])
      #   |> Map.put(:geom, res9_temp.geom)

      # IO.puts(res9)

      # %Res9{}
      # |> Res9.changeset(res9)
      res9_temp
      |> Ecto.Changeset.change(%{average_rssi: Enum.at(message["hotspots"], 0)["rssi"]})
      |> Repo.update()
    else
      if :h3.is_valid(h3_res9_id) do
        poly = :h3.to_geo_boundary(h3_res9_id)
        poly_length = length(poly)

        cond do
          poly_length == 5 ->
            res9 =
              %{}
              |> Map.put(:id, h3_res9_id_s)
              |> Map.put(:state, "mapped")
              |> Map.put(:average_rssi, Enum.at(message["hotspots"], 0)["rssi"])
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

            %Res9{}
            |> Res9.changeset(res9)
            |> Repo.insert()
            |> case do
              {:ok, _} -> IO.puts("H3 Insert Successful")
              {:error, changeset} -> IO.puts("H3 Insert Error #{changeset}")
            end
          poly_length == 6 ->
            res9 =
              %{}
              |> Map.put(:id, h3_res9_id_s)
              |> Map.put(:state, "mapped")
              |> Map.put(:average_rssi, Enum.at(message["hotspots"], 0)["rssi"])
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

            %Res9{}
            |> Res9.changeset(res9)
            |> Repo.insert()
            |> case do
              {:ok, _} -> IO.puts("H3 Insert Successful")
              {:error, changeset} -> IO.puts("H3 Insert Error #{changeset}")
            end
          poly_length == 7 ->
            res9 =
              %{}
              |> Map.put(:id, h3_res9_id_s)
              |> Map.put(:state, "mapped")
              |> Map.put(:average_rssi, Enum.at(message["hotspots"], 0)["rssi"])
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

            %Res9{}
            |> Res9.changeset(res9)
            |> Repo.insert()
            |> case do
              {:ok, _} -> IO.puts("H3 Insert Successful")
              {:error, changeset} -> IO.puts("H3 Insert Error #{changeset}")
            end
          poly_length == 8 ->
            res9 =
              %{}
              |> Map.put(:id, h3_res9_id_s)
              |> Map.put(:state, "mapped")
              |> Map.put(:average_rssi, Enum.at(message["hotspots"], 0)["rssi"])
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

            %Res9{}
            |> Res9.changeset(res9)
            |> Repo.insert()
            |> case do
              {:ok, _} -> IO.puts("H3 Insert Successful")
              {:error, changeset} -> IO.puts("H3 Insert Error #{changeset}")
            end
          poly_length == 9 ->
            res9 =
              %{}
              |> Map.put(:id, h3_res9_id_s)
              |> Map.put(:state, "mapped")
              |> Map.put(:average_rssi, Enum.at(message["hotspots"], 0)["rssi"])
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

            %Res9{}
            |> Res9.changeset(res9)
            |> Repo.insert()
            |> case do
              {:ok, _} -> IO.puts("H3 Insert Successful")
              {:error, changeset} -> IO.puts("H3 Insert Error #{changeset}")
            end
          poly_length == 10 ->
            res9 =
              %{}
              |> Map.put(:id, h3_res9_id_s)
              |> Map.put(:state, "mapped")
              |> Map.put(:average_rssi, Enum.at(message["hotspots"], 0)["rssi"])
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

            %Res9{}
            |> Res9.changeset(res9)
            |> Repo.insert()
            |> case do
              {:ok, _} -> IO.puts("H3 Insert Successful")
              {:error, changeset} -> IO.puts("H3 Insert Error #{changeset}")
            end
        end
      end
    end
  end
end
