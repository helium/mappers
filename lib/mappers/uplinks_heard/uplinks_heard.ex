defmodule Mappers.UplinksHeard do
  alias Mappers.Repo
  alias Mappers.UplinksHeards.UplinkHeard

  def create(message, uplink_id) do
    IO.puts(uplink_id)
    uplink_heard =
      %{}
      |> Map.put(:hotspot_address, Enum.at(message["hotspots"], 0)["id"])
      |> Map.put(:hotspot_name, Enum.at(message["hotspots"], 0)["name"])
      |> Map.put(:latitude, Enum.at(message["hotspots"], 0)["lat"])
      |> Map.put(:longitude, Enum.at(message["hotspots"], 0)["long"])
      |> Map.put(:rssi, Enum.at(message["hotspots"], 0)["rssi"])
      |> Map.put(:snr, Enum.at(message["hotspots"], 0)["snr"])
      |> Map.put(
        :timestamp,
        Enum.at(message["hotspots"], 0)["reported_at"] |> DateTime.from_unix!()
      )
      |> Map.put(:uplink_id, uplink_id)

    %UplinkHeard{}
    |> UplinkHeard.changeset(uplink_heard)
    |> Repo.insert()
    |> case do
      {:ok, _} -> IO.puts("Uplink Heard Insert Successful")
      {:error, changeset} -> IO.puts("Uplink Heard Insert Error #{changeset}")
    end
  end
end
