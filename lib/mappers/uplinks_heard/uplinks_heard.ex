defmodule Mappers.UplinksHeard do
  alias Mappers.Repo
  alias Mappers.UplinksHeards.UplinkHeard

  # The hotspots arrive validated (Mappers.Ingest.Validate), so the rows skip the changeset
  # and go in with one statement, in the request process.
  def create(hotspots, uplink_id) do
    rows =
      Enum.map(hotspots, fn hotspot ->
        %{
          id: Ecto.UUID.generate(),
          hotspot_address: hotspot["id"],
          hotspot_name: hotspot["name"],
          latitude: hotspot["lat"],
          longitude: hotspot["long"],
          rssi: hotspot["rssi"],
          snr: hotspot["snr"],
          # stored to the second; the column type needs microsecond precision
          timestamp: %{
            DateTime.from_unix!(round(hotspot["reported_at"] / 1000))
            | microsecond: {0, 6}
          },
          uplink_id: uplink_id
        }
      end)

    {_count, uplinks_heard} = Repo.insert_all(UplinkHeard, rows, returning: true)
    {:ok, uplinks_heard}
  end
end
