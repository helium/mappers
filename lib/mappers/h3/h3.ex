defmodule Mappers.H3 do
  alias Mappers.Repo
  alias Mappers.H3.Res9

  def create(message) do
    # grab lat/lng if available
    lat = message["decoded"]["payload"]["latitude"]
    lng = message["decoded"]["payload"]["longitude"]

    # find h3 index
    h3_res9_id = :h3.from_geo({lat, lng}, 9)
    h3_res9_id_s = to_string(:h3.to_string(h3_res9_id))

    res9_temp = Repo.get(Res9, h3_res9_id_s)

    rssi_r = Enum.at(message["hotspots"], 0)["rssi"]

    rssi =
      cond do
        is_float(rssi_r) -> rssi_r
        is_integer(rssi_r) -> rssi_r * 1.0
        is_binary(rssi_r) -> Float.parse(rssi_r) |> elem(0)
      end

    # check if h3 index exist in the db
    if res9_temp != nil do
      # record existing h3 res9 metric
      :telemetry.execute([:ingest, :h3, :res9, :existing], %{h3_res9_id: h3_res9_id_s}, message)

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
      |> Ecto.Changeset.change(%{average_rssi: rssi})
      |> Repo.update()
      |> case do
        {:ok, changeset} -> {:ok, changeset}
        {:error, _} -> {:error, "H3 Update Error"}
      end
    else
      if :h3.is_valid(h3_res9_id) do
        # record new h3 res9 metric
        :telemetry.execute([:ingest, :h3, :res9, :new], %{h3_res9_id: h3_res9_id_s}, message)

        poly = :h3.to_geo_boundary(h3_res9_id)
        poly_length = length(poly)

        cond do
          poly_length == 5 ->
            res9 =
              %{}
              |> Map.put(:id, h3_res9_id_s)
              |> Map.put(:state, "mapped")
              |> Map.put(:average_rssi, rssi)
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
              {:ok, changeset} -> {:ok, changeset}
              {:error, _} -> {:error, "H3 Insert Error"}
            end

          poly_length == 6 ->
            res9 =
              %{}
              |> Map.put(:id, h3_res9_id_s)
              |> Map.put(:state, "mapped")
              |> Map.put(:average_rssi, rssi)
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
              {:ok, changeset} -> {:ok, changeset}
              {:error, _} -> {:error, "H3 Insert Error"}
            end

          poly_length == 7 ->
            res9 =
              %{}
              |> Map.put(:id, h3_res9_id_s)
              |> Map.put(:state, "mapped")
              |> Map.put(:average_rssi, rssi)
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
              {:ok, changeset} -> {:ok, changeset}
              {:error, _} -> {:error, "H3 Insert Error"}
            end

          poly_length == 8 ->
            res9 =
              %{}
              |> Map.put(:id, h3_res9_id_s)
              |> Map.put(:state, "mapped")
              |> Map.put(:average_rssi, rssi)
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
              {:ok, changeset} -> {:ok, changeset}
              {:error, _} -> {:error, "H3 Insert Error"}
            end

          poly_length == 9 ->
            res9 =
              %{}
              |> Map.put(:id, h3_res9_id_s)
              |> Map.put(:state, "mapped")
              |> Map.put(:average_rssi, rssi)
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
              {:ok, changeset} -> {:ok, changeset}
              {:error, _} -> {:error, "H3 Insert Error"}
            end

          poly_length == 10 ->
            res9 =
              %{}
              |> Map.put(:id, h3_res9_id_s)
              |> Map.put(:state, "mapped")
              |> Map.put(:average_rssi, rssi)
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
              {:ok, changeset} -> {:ok, changeset}
              {:error, _} -> {:error, "H3 Insert Error"}
            end
        end
      end
    end
  end
end
