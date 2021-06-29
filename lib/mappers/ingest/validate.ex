defmodule Mappers.Ingest.Validate do
  def validate_message(message) do
    if match?(%{"decoded" => %{"payload" => %{"latitude" => _}}}, message) == false do
      {:error, "Missing Field: latitude"}
    else
      if match?(%{"decoded" => %{"payload" => %{"longitude" => _}}}, message) == false do
        {:error, "Missing Field: longitude"}
      else
        if match?(%{"decoded" => %{"payload" => %{"altitude" => _}}}, message) == false do
          {:error, "Missing Field: altitude"}
        else
          if match?(%{"decoded" => %{"payload" => %{"accuracy" => _}}}, message) == false do
            {:error, "Missing Field: accuracy"}
          else
            device_lat = message["decoded"]["payload"]["latitude"]
            device_lng = message["decoded"]["payload"]["longitude"]
            device_alt = message["decoded"]["payload"]["altitude"]
            device_acu = message["decoded"]["payload"]["accuracy"]

            if device_lat == 0.0 or device_lat < -90 or device_lat > 90 or device_lng == 0.0 or
                 device_lng < -180 or device_lng > 180 do
              {:error,
               "Invalid Device Latitude or Longitude Values for Lat: #{device_lat} Lng: #{device_lng}"}
            else
              if device_alt < -500 do
                {:error, "Invalid Device Altitude Value for Alt: #{device_alt}"}
              else
                if device_acu < 0 do
                  {:error, "Invalid Device Accuracy Value for Accuracy: #{device_acu}"}
                else
                  Enum.map(message["hotspots"], fn hotspot ->
                    hotspot_name = hotspot["name"]
                    hotspot_lat = hotspot["lat"]
                    hotspot_lng = hotspot["long"]
                    hotspot_rssi = hotspot["rssi"]
                    hotspot_snr = hotspot["snr"]

                    if hotspot_lat == 0.0 or hotspot_lat < -90 or
                         hotspot_lat > 90 or hotspot_lng == 0.0 or
                         hotspot_lng < -180 or hotspot_lng > 180 do
                      {:error,
                       "Invalid Latitude or Longitude Values for Hotspot: #{hotspot_name}"}
                    else
                      if Geocalc.distance_between([device_lat, device_lng], [
                           hotspot_lat,
                           hotspot_lng
                         ]) >
                           500_000 do
                        {:error, "Invalid Distance Between Device and Hotspot: #{hotspot_name}"}
                      else
                        if hotspot_rssi < -130 or hotspot_rssi > 0 do
                          {:error, "Invalid Uplink RSSI for Hotspot: #{hotspot_name}"}
                        else
                          if hotspot_snr < -40 or hotspot_snr > 40 do
                            {:error, "Invalid Uplink SNR for Hotspot: #{hotspot_name}"}
                          else
                            {:ok, hotspot}
                          end
                        end
                      end
                    end
                  end)
                  |> Enum.split_with(fn
                    {:error, _} -> true
                    {:ok, _} -> false
                  end)
                  |> case do
                    # if there are any hotspot errors but no oks
                    {errors, []} ->
                      errors_s =
                        errors
                        |> Enum.map(&elem(&1, 1))

                      {:error, errors_s}

                    # if there are any hotspot oks
                    {_, hotspots} ->
                      hotspots_s =
                        hotspots
                        |> Enum.map(&elem(&1, 1))

                      {:ok, hotspots_s}
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
