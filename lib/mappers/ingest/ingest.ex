defmodule Mappers.Ingest do
  alias Mappers.Uplinks

  def ingest_uplink(%{"app_eui" => app_eui, "dev_eui" => dev_eui, "id" => device_id, "fcnt" => fcnt, "reported_at" => first_timestamp, "frequency" => frequency, "gps_accuracy" => gps_accuracy, "spreading" => spreading_factor}) do
    # validate that lat/lng actually make sense
    # validate device location with hotspot locations

    # create new h3_res9 record if it doesn't exist
    # create uplink record
    attrs = %{}
      |> Map.put(:app_eui, app_eui)
      |> Map.put(:dev_eui, dev_eui)
      |> Map.put(:device_id, device_id)
      |> Map.put(:fcnt, fcnt)
      |> Map.put(:first_timestamp, first_timestamp |> DateTime.from_unix!())
      |> Map.put(:frequency, frequency)
      |> Map.put(:gps_accuracy, gps_accuracy)
      |> Map.put(:spreading_factor, spreading_factor)

    Uplinks.create(attrs)
    # create uplinks_heard
    # create h3/uplink link
  end
end
