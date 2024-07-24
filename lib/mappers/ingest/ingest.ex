defmodule Mappers.Ingest do
  alias Mappers.Uplink
  alias Mappers.Uplinks
  alias Mappers.H3
  alias Mappers.H3.Links
  alias Mappers.UplinkHeard
  alias Mappers.UplinksHeard
  alias Mappers.Ingest

  defmodule IngestUplinkResponse do
    @fields [
      :uplink,
      :hotspots,
      :status
    ]
    @derive {Jason.Encoder, only: @fields}
    defstruct uplink: Uplink, hotspots: [UplinkHeard], status: nil
  end

  def ingest_uplink(message) do
    case normalize_payload(message) do
      {:ok, normalized_message} ->
        # validate that message geo values actually make sense
        Ingest.Validate.validate_message(normalized_message)
        |> case do
          {:error, reason} ->
            %{error: reason}

          {:ok, hotspots} ->
            # create new h3_res9 record if it doesn't exist
            H3.create(normalized_message)
            |> case do
              {:error, reason} ->
                %{error: reason}

              {:ok, h3_res9} ->
                h3_res9_id = h3_res9.id

                # create uplink record
                Uplinks.create(normalized_message)
                |> case do
                  {:error, reason} ->
                    %{error: reason}

                  {:ok, uplink} ->
                    uplink_id = uplink.id

                    # create uplinks heard
                    UplinksHeard.create(hotspots, uplink_id)
                    |> case do
                      {:error, reason} ->
                        %{error: reason}

                      {:ok, uplinks_heard} ->
                        # create h3/uplink link
                        Links.create(h3_res9_id, uplink_id)
                        |> case do
                          {:error, reason} ->
                            %{error: reason}

                          {:ok, _} ->
                            %IngestUplinkResponse{
                              uplink: uplink,
                              hotspots: uplinks_heard,
                              status: "success"
                            }
                        end
                    end
                end
            end
        end

      {:error, reason} ->
        %{error: reason}
    end
  end

  # ChirpStack: look for "object" key as indicator
  defp normalize_payload(%{"object" => object} = message) do
    spreading_factor = get_in(message, ["txInfo", "modulation", "lora", "spreadingFactor"])
    bandwidth = get_in(message, ["txInfo", "modulation", "lora", "bandwidth"])
    spreading = "SF#{spreading_factor}BW#{div(bandwidth, 1000)}"
    tx_frequency = get_in(message, ["txInfo", "frequency"]) / 1_000_000

    normalized_message = %{
      "app_eui" => "0000000000000000", # ChirpStack does not provide this field
      "dev_eui" => get_in(message, ["deviceInfo", "devEui"]),
      "id" => get_in(message, ["deviceInfo", "deviceProfileId"]),
      "fcnt" => message["fCnt"],
      "reported_at" => parse_reported_at(message["time"]),
      "frequency" => tx_frequency,
      "spreading" => spreading,
      "decoded" => %{
        "payload" => %{
          "latitude" => object["latitude"],
          "longitude" => object["longitude"],
          "accuracy" => object["accuracy"],
          "altitude" => object["altitude"]
        },
        "status" => "success"
      },
      "hotspots" => normalize_hotspots(message["rxInfo"], tx_frequency, spreading),
      "id" => message["deduplicationId"]
    }

    {:ok, normalized_message}
  end

  defp normalize_payload(message) do
    # Assume Console payload already has the necessary fields
    normalized_message = %{
      "app_eui" => message["app_eui"],
      "dev_eui" => message["dev_eui"],
      "id" => message["id"],
      "fcnt" => message["fcnt"],
      "reported_at" => message["reported_at"],
      "frequency" => Enum.at(message["hotspots"], 0)["frequency"],
      "spreading" => Enum.at(message["hotspots"], 0)["spreading"],
      "decoded" => %{
        "payload" => %{
          "latitude" => message["decoded"]["payload"]["latitude"],
          "longitude" => message["decoded"]["payload"]["longitude"],
          "accuracy" => message["decoded"]["payload"]["accuracy"],
          "altitude" => message["decoded"]["payload"]["altitude"]
        },
        "status" => message["decoded"]["status"]
      },
      "hotspots" => message["hotspots"]
    }

    {:ok, normalized_message}
  end

  defp normalize_hotspots(rxInfo, tx_frequency, spreading) do
    Enum.filter_map(rxInfo, fn info ->
      lat = get_in(info, ["metadata", "gateway_lat"])
      long = get_in(info, ["metadata", "gateway_long"])

      if is_nil(lat) or is_nil(long) do
        IO.puts("Hotspot has no location; skipping.")
        false
      else
        true
      end
    end, fn info ->
      %{
        "id" => get_in(info, ["metadata", "gateway_id"]),
        "name" => get_in(info, ["metadata", "gateway_name"]),
        "lat" => String.to_float(get_in(info, ["metadata", "gateway_lat"])),
        "long" => String.to_float(get_in(info, ["metadata", "gateway_long"])),
        "rssi" => info["rssi"],
        "snr" => info["snr"],
        "frequency" => tx_frequency,
        "spreading" => spreading,
        "reported_at" => parse_reported_at(info["gwTime"])
      }
    end)
  end

  defp parse_reported_at(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, datetime, _offset} -> DateTime.to_unix(datetime, :millisecond)
      _ -> nil
    end
  end
end
