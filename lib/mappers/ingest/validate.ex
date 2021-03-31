defmodule Mappers.Ingest.Validate do
  def validate_message(message) do
    device_lat = message["decoded"]["payload"]["latitude"]
    device_lng = message["decoded"]["payload"]["longitude"]

    hotspot_lat = Enum.at(message["hotspots"], 0)["lat"]
    hotspot_lng = Enum.at(message["hotspots"], 0)["long"]

    if device_lat == 0.0 or device_lat < -90 or device_lat > 90 or device_lng == 0.0 or device_lng < -180 or device_lng > 180 do
      {:error, "Invalid Device Latitude or Longitude Values"}
    else
      if hotspot_lat == 0.0 or hotspot_lat < -90 or hotspot_lat > 90 or hotspot_lng == 0.0 or
           hotspot_lng < -180 or hotspot_lng > 180 do
        {:error, "Invalid Hotspot Latitude or Longitude Values"}
      else
        if Geocalc.distance_between([device_lat, device_lng], [hotspot_lat, hotspot_lng]) > 500000 do
          {:error, "Invalid Distance Between Device and Hotspot"}
        else
          {:ok, "Valid Ingest Message"}
        end
      end
    end
  end
end
