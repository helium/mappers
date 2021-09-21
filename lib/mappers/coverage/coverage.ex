defmodule Mappers.Coverage do
  import Ecto.Query
  alias Mappers.Repo
  alias Mappers.H3.Res9
  alias Mappers.Uplinks
  alias Mappers.H3.Links.Link
  alias Mappers.UplinksHeards.UplinkHeard

  @max_search_range 128

  def validateCoords(coords) do
    match = String.match?(coords, ~r/([-]?([0-9]*[.])?[0-9]+),([-]?([0-9]*[.])?[0-9]+)/)

    if(match) do
      origin =
        coords
        |> String.split(",")
        |> Enum.map(fn s -> String.to_float(s) end)
        |> List.to_tuple()

      {:ok, origin}
    else
      {:error, "Coordinates are not valid!"}
    end
  end

  def get_coverage_from_geo(coords_s) do
    check = validateCoords(coords_s)

    case check do
      {:ok, origin} ->
        h3_index = :h3.from_geo(origin, 9)

        h3 = Repo.get_by(Res9, h3_index_int: h3_index)

        case h3 do
          nil ->
            IO.puts("no data, searching nearby area")

            # will expand search rings out to @max_search_range unless something found
            nearby_uplinks = expand_search_area(h3_index, 4, 0)

            case length(nearby_uplinks) do
              0 ->
                %{covered: false, reason: "No nearby signal data found"}

              _ ->
                nearest = distance_from_nearest_uplink(origin, nearby_uplinks)

                estimated = estimateCoverage(nearby_uplinks, nearest)

                %{}
                |> Map.put(:h3_id, nil)
                |> Map.put(:state, "not_mapped")
                |> Map.put(:estimated_rssi, estimated.rssi)
                |> Map.put(:estimated_snr, estimated.snr)
                |> Map.put(
                  :distance_from_nearest_uplink,
                  nearest
                )
                |> Map.put(:uplinks_in_area, nearby_uplinks)
                |> Map.put(:covered, estimated.coverage)
            end

          _ ->
            uplinks = Uplinks.get_uplinks(h3.id)

            %{}
            |> Map.put(:h3_id, h3.id)
            |> Map.put(:state, h3.state)
            |> Map.put(:measured_rssi, h3.best_rssi)
            |> Map.put(:measured_snr, h3.snr)
            |> Map.put(
              :distance_from_nearest_uplink,
              distance_from_nearest_uplink(origin, uplinks)
            )
            |> Map.put(:uplinks_in_area, uplinks)
            |> Map.put(:covered, usable_signal?(h3.best_rssi, h3.snr))
        end

      {:error, reason} ->
        %{error: reason}
    end
  end

  def expand_search_area(h3_origin_int, range, prev) do
    IO.puts("expanding search: range #{range} from range #{prev}...")

    indexes =
      :h3.k_ring_distances(h3_origin_int, range)
      |> Enum.filter(fn {_, dist} -> dist > prev end)
      |> Enum.map(fn {index, _} ->
        index
        |> Integer.to_string(16)
        |> String.downcase()
      end)

    query_uplinks =
      from u in Uplinks.Uplink,
        join: uh in UplinkHeard,
        on: u.id == uh.uplink_id,
        join: h3 in Link,
        on: h3.uplink_id == u.id,
        where: h3.h3_res9_id in ^indexes,
        select: %{
          h3_id: h3.h3_res9_id,
          uplink_heard_id: uh.id,
          hotspot_name: uh.hotspot_name,
          rssi: uh.rssi,
          snr: uh.snr,
          lat: uh.latitude,
          lng: uh.longitude,
          timestamp: uh.timestamp
        }

    query_task = Task.async(fn -> Repo.all(query_uplinks) end)

    expansion =
      cond do
        range < 16 ->
          range

        true ->
          16
      end

    nearby_uplinks =
      Task.await(query_task, 10000)
      |> Enum.map(fn %{lat: uLat, lng: uLng} = x ->
        {h3_index_int, _} = Integer.parse(x.h3_id, 16)
        measurement_coords = :h3.to_geo(h3_index_int)

        Map.put(x, :distance_at_measure, point_distance(measurement_coords, [uLat, uLng]))
      end)

    IO.puts("returned #{length(nearby_uplinks)}")

    if(length(nearby_uplinks) == 0 && range < @max_search_range) do
      expand_search_area(h3_origin_int, range + expansion, range)
    else
      nearby_uplinks
    end
  end

  def distance_from_nearest_uplink(origin, uplinks) do
    uplinks
    |> Enum.map(fn x ->
      %{lat: uLat, lng: uLng} = x

      # meters to miles
      point_distance(origin, [uLat, uLng])
    end)
    |> Enum.min()
  end

  def estimateCoverage(uplinks, origin_uplink_dist) do
    # estimate whether you should have coverage
    ufarthest =
      uplinks
      |> Enum.max_by(fn x -> x.distance_at_measure end)

    avg_rssi =
      uplinks
      |> Enum.map(fn x -> x.rssi end)
      |> Enum.sum()
      |> Kernel./(length(uplinks))

    avg_snr =
      uplinks
      |> Enum.map(fn x -> x.snr end)
      |> Enum.sum()
      |> Kernel./(length(uplinks))

    cond do
      origin_uplink_dist < ufarthest.distance_at_measure ->
        %{rssi: avg_rssi, snr: avg_snr, coverage: usable_signal?(avg_rssi, avg_snr)}

      origin_uplink_dist >= ufarthest.distance_at_measure ->
        diff_dist = origin_uplink_dist / ufarthest.distance_at_measure

        extrapolated_rssi = ufarthest.rssi - 20 * :math.log10(diff_dist)

        %{
          rssi: extrapolated_rssi,
          snr: avg_snr,
          coverage: usable_signal?(extrapolated_rssi, avg_snr)
        }
    end
  end

  def usable_signal?(rssi, snr) do
    rssi > -120 && snr > -20
  end

  def point_distance(origin, dest) do
    Geocalc.distance_between(origin, dest) / 1609.34
  end

  def path_loss(d, f \\ 915, gTx \\ 3, gRx \\ 3) do
    # units in miles and megahertz
    20 * (:math.log10(d) + :math.log10(f)) - gTx - gRx + 36.5939
  end
end
