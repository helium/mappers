defmodule Mappers.Uplinks do
  import Ecto.Query
  alias Mappers.Repo
  alias Mappers.Uplinks.Uplink
  alias Mappers.UplinksHeards.UplinkHeard
  alias Mappers.H3.Links.Link

  def create(message) do
    uplink = %{}
      |> Map.put(:app_eui, message["app_eui"])
      |> Map.put(:dev_eui, message["dev_eui"])
      |> Map.put(:device_id, message["id"])
      |> Map.put(:fcnt, message["fcnt"])
      |> Map.put(:first_timestamp, round(message["reported_at"]/1000) |> DateTime.from_unix!())
      |> Map.put(:frequency, Enum.at(message["hotspots"], 0)["frequency"])
      |> Map.put(:altitude, message["decoded"]["payload"]["altitude"])
      |> Map.put(:gps_accuracy, message["decoded"]["payload"]["accuracy"])
      |> Map.put(:spreading_factor, Enum.at(message["hotspots"], 0)["spreading"])

    %Uplink{}
    |> Uplink.changeset(uplink)
    |> Repo.insert()
    |> case do
      {:ok, changeset} -> {:ok, changeset}
      {:error, _} -> {:error, "Uplink Insert Error"}
    end
  end

  def get_uplinks(h3_index) do
    query =
      from u in Uplink,
      join: uh in UplinkHeard,
      on: u.id == uh.uplink_id,
      join: h3 in Link,
      on: h3.uplink_id == u.id,
      where: h3.h3_res9_id == ^h3_index,
      distinct: [uh.hotspot_name],
      order_by: [desc: uh.rssi],
      select: %{
        uplink_heard_id: uh.id,
        hotspot_name: uh.hotspot_name,
        rssi: uh.rssi,
        snr: uh.snr,
        lat: uh.latitude,
        lng: uh.longitude,
        timestamp: uh.timestamp
      }

      Repo.all(query)
  end
end
