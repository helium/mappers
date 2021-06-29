defmodule Mappers.UplinksHeard do
  alias Mappers.Repo
  alias Mappers.UplinksHeards.UplinkHeard

  def create(hotspots, uplink_id) do
    uplinks_heard =
      Enum.map(hotspots, fn hotspot ->
        %{}
        |> Map.put(:hotspot_address, hotspot["id"])
        |> Map.put(:hotspot_name, hotspot["name"])
        |> Map.put(:latitude, hotspot["lat"])
        |> Map.put(:longitude, hotspot["long"])
        |> Map.put(:rssi, hotspot["rssi"])
        |> Map.put(:snr, hotspot["snr"])
        |> Map.put(
          :timestamp,
          round(hotspot["reported_at"] / 1000) |> DateTime.from_unix!()
        )
        |> Map.put(:uplink_id, uplink_id)
      end)

    changesets = []

    changeset_results =
      Enum.map(uplinks_heard, fn uplink_heard ->
        %UplinkHeard{}
        |> UplinkHeard.changeset(uplink_heard)
        |> Repo.insert()
        |> case do
          {:ok, changeset} -> changesets ++ changeset
          {:error, _} -> {:error, ""}
        end
      end)

    results = Enum.find(changeset_results, fn(changeset) ->
      match?({:error, _}, changeset)
    end)

    if results == nil do
      {:ok, changeset_results}
    else
      {:error, "Uplink Heard Insert Error"}
    end
  end
end
