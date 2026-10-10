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

    insert_results = insert_uplinks_heard(uplinks_heard)

    if Enum.any?(insert_results, &match?({:error, _}, &1)) do
      {:error, "Uplink Heard Insert Error"}
    else
      {:ok, Enum.map(insert_results, fn {:ok, uplink_heard} -> uplink_heard end)}
    end
  end

  # In the request process rather than in linked tasks, so a failed insert comes back as an
  # error instead of killing the request before anything can log it.
  def insert_uplinks_heard(uplinks_heard) do
    Enum.map(uplinks_heard, &insert_uplink_heard/1)
  end

  def insert_uplink_heard(uplink_heard) do
    %UplinkHeard{}
    |> UplinkHeard.changeset(uplink_heard)
    |> Repo.insert()
  end
end
