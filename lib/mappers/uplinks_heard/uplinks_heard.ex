defmodule Mappers.UplinksHeard do
  alias Mappers.Repo
  alias Mappers.UplinksHeards.UplinkHeard

  @max_concurrency(3)

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

    changeset_insert_results = insert_uplinks_heard(uplinks_heard)

    changeset_results = Enum.map(changeset_insert_results, fn {_, {_, changeset}} ->
      changeset
    end)

    results =
      Enum.find(changeset_results, fn changeset ->
        match?({:error, _}, changeset)
      end)

    if results == nil do
      {:ok, changeset_results}
    else
      {:error, "Uplink Heard Insert Error"}
    end
  end

  def insert_uplinks_heard(uplinks_heard) do
    uplinks_heard
    |> Task.async_stream(fn uplink_heard -> insert_uplink_heard(uplink_heard) end)
  end

  def insert_uplink_heard(uplink_heard) do
    %UplinkHeard{}
    |> UplinkHeard.changeset(uplink_heard)
    |> Repo.insert()
  end
end
