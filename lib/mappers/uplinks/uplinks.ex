defmodule Mappers.Uplinks do
  import Ecto.Query
  alias Mappers.Repo
  alias Mappers.Uplinks.Uplink
  alias Mappers.Uplinks.Filter
  alias Mappers.UplinksHeards.UplinkHeard
  alias Mappers.H3.Links.Link

  def create(message) do
    uplink = %{}
      |> Map.put(:app_eui, message["app_eui"])
      |> Map.put(:dev_eui, message["dev_eui"])
      |> Map.put(:device_id, message["id"])
      |> Map.put(:fcnt, message["fcnt"])
      |> Map.put(:first_timestamp, round(message["reported_at"]/1000) |> DateTime.from_unix!())
      |> Map.put(:frequency, message["frequency"])
      |> Map.put(:altitude, message["decoded"]["payload"]["altitude"] |> round)
      |> Map.put(:gps_accuracy, message["decoded"]["payload"]["accuracy"])
      |> Map.put(:spreading_factor, message["spreading"])

    %Uplink{}
    |> Uplink.changeset(uplink)
    |> Repo.insert()
    |> case do
      {:ok, changeset} -> {:ok, changeset}
      {:error, _} -> {:error, "Uplink Insert Error"}
    end
  end

  def get_uplinks(h3_index, filter \\ %Filter{}) do
    query =
      from u in Uplink,
      join: uh in UplinkHeard,
      on: u.id == uh.uplink_id,
      join: h3 in Link,
      on: h3.uplink_id == u.id,
      where: h3.h3_res9_id == ^h3_index,
      distinct: [uh.hotspot_name],
      order_by: [desc: uh.rssi],
      limit: 1500,
      select: %{
        uplink_heard_id: uh.id,
        hotspot_name: uh.hotspot_name,
        rssi: uh.rssi,
        snr: uh.snr,
        lat: uh.latitude,
        lng: uh.longitude,
        timestamp: uh.timestamp
      }

      query
      |> apply_filter(filter)
      |> Repo.all()
  end

  def search_hotspots(prefix, limit \\ 20) do
    name_prefix =
      prefix
      |> String.trim()
      |> String.downcase()
      |> String.replace(~r/\s+/, "-")
      |> String.replace(~r/[%_\\]/, "")

    # checked after cleanup, since "%%" or "  " would otherwise match every hotspot
    if String.length(name_prefix) < 2 do
      []
    else
      Repo.all(
        from uh in UplinkHeard,
          where: like(uh.hotspot_name, ^"#{name_prefix}%"),
          distinct: uh.hotspot_name,
          order_by: [asc: uh.hotspot_name, desc: uh.timestamp],
          limit: ^limit,
          select: %{name: uh.hotspot_name, lat: uh.latitude, lng: uh.longitude}
      )
    end
  end

  defp apply_filter(query, %Filter{} = filter) do
    query
    |> filter_start(filter.start)
    |> filter_end(filter.end)
    |> filter_hotspot(filter.hotspot)
  end

  defp filter_start(query, nil), do: query
  defp filter_start(query, start_at), do: where(query, [_u, uh], uh.timestamp >= ^start_at)

  defp filter_end(query, nil), do: query
  defp filter_end(query, end_at), do: where(query, [_u, uh], uh.timestamp < ^end_at)

  defp filter_hotspot(query, nil), do: query
  defp filter_hotspot(query, hotspot), do: where(query, [_u, uh], uh.hotspot_name == ^hotspot)
end
