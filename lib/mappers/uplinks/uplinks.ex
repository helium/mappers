defmodule Mappers.Uplinks do
  alias Mappers.Repo
  alias Mappers.Uplinks.Uplink

  def create(message) do
    uplink = %{}
      |> Map.put(:app_eui, message["app_eui"])
      |> Map.put(:dev_eui, message["dev_eui"])
      |> Map.put(:device_id, message["id"])
      |> Map.put(:fcnt, message["fcnt"])
      |> Map.put(:first_timestamp, message["reported_at"] |> DateTime.from_unix!())
      |> Map.put(:frequency, Enum.at(message["hotspots"], 0)["frequency"])
      |> Map.put(:gps_accuracy, 2)
      |> Map.put(:spreading_factor, Enum.at(message["hotspots"], 0)["spreading"])

    %Uplink{}
    |> Uplink.changeset(uplink)
    |> Repo.insert()
  end
end
