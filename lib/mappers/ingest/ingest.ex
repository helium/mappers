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

  @doc """
  Ingests one uplink POST body. `event` is ChirpStack's `?event=` query parameter, if any.

  Returns `{:ok, response}` once the uplink is stored, `{:ignore, reason}` for ChirpStack
  events that aren't uplinks, `{:reject, reason, detail}` for payloads that can't be mapped,
  or `{:error, reason, detail}` when storing a valid uplink fails.
  """
  def ingest_uplink(body, event \\ nil) do
    case {event, format(body)} do
      {event, _} when is_binary(event) and event != "up" ->
        {:ignore, "not_uplink"}

      {"up", :chirpstack_event} ->
        {:reject, "unsupported_payload", "an up event needs rxInfo and txInfo"}

      {_, :chirpstack_event} ->
        {:ignore, "not_uplink"}

      {_, :unknown} ->
        {:reject, "unsupported_payload",
         "expected a ChirpStack uplink event or a Helium Console uplink"}

      {_, format} ->
        with {:ok, message} <- normalize_payload(format, body),
             {:ok, hotspots} <- Ingest.Validate.validate_message(message) do
          # store only the hotspots that passed validation
          store(Map.put(message, "hotspots", hotspots), hotspots)
        end
    end
  end

  @doc """
  Which kind of payload a body is: a ChirpStack uplink (`:chirpstack`), another ChirpStack
  event such as join, log or status (`:chirpstack_event`), a Helium Console uplink
  (`:console`), or `:unknown`. Relays re-post ChirpStack JSON without `?event`, so the body
  decides, not the query string.
  """
  def format(%{"rxInfo" => rx_info, "txInfo" => tx_info})
      when is_list(rx_info) and is_map(tx_info),
      do: :chirpstack

  def format(%{"deviceInfo" => _}), do: :chirpstack_event
  def format(%{"hotspots" => hotspots}) when is_list(hotspots), do: :console
  def format(_), do: :unknown

  defp store(message, hotspots) do
    with {:ok, h3_res9} <- H3.create(message),
         {:ok, uplink} <- Uplinks.create(message),
         {:ok, uplinks_heard} <- UplinksHeard.create(hotspots, uplink.id),
         {:ok, _} <- Links.create(h3_res9.id, uplink.id) do
      {:ok,
       %IngestUplinkResponse{
         uplink: uplink,
         hotspots: uplinks_heard,
         status: "success"
       }}
    else
      {:error, reason} -> {:error, "store_failed", reason}
    end
  end

  defp normalize_payload(:chirpstack, message) do
    lora = dig(message, ["txInfo", "modulation", "lora"])
    frequency_hz = to_float(dig(message, ["txInfo", "frequency"]))

    cond do
      not (is_integer(dig(lora, ["spreadingFactor"])) and is_integer(dig(lora, ["bandwidth"]))) ->
        {:reject, "unsupported_modulation", "only LoRa uplinks can be mapped"}

      is_nil(frequency_hz) ->
        {:reject, "missing_field", "txInfo.frequency"}

      true ->
        spreading = "SF#{lora["spreadingFactor"]}BW#{div(lora["bandwidth"], 1000)}"
        tx_frequency = frequency_hz / 1_000_000
        uplink_time = message["time"]
        dev_eui = dig(message, ["deviceInfo", "devEui"])

        # the network server's own receive times back up the event time
        ns_times = for info <- message["rxInfo"], is_map(info), do: info["nsTime"]

        {:ok,
         %{
           # ChirpStack does not provide this field
           "app_eui" => "0000000000000000",
           "dev_eui" => dev_eui,
           "id" => dev_eui,
           "fcnt" => message["fCnt"],
           "reported_at" => pick_time([uplink_time | ns_times]),
           "frequency" => tx_frequency,
           "spreading" => spreading,
           "decoded" => %{
             "payload" => position(message["object"]),
             "status" => "success"
           },
           "decoder_error" => false,
           "hotspots" =>
             normalize_hotspots(message["rxInfo"], uplink_time, tx_frequency, spreading)
         }}
    end
  end

  defp normalize_payload(:console, message) do
    decoded = if is_map(message["decoded"]), do: message["decoded"], else: %{}
    payload = if is_map(decoded["payload"]), do: decoded["payload"], else: %{}

    hotspots =
      message["hotspots"]
      |> Enum.filter(&is_map/1)
      |> Enum.map(&normalize_console_hotspot/1)

    {:ok,
     %{
       "app_eui" => message["app_eui"],
       "dev_eui" => message["dev_eui"],
       "id" => message["id"],
       "fcnt" => message["fcnt"],
       "reported_at" => to_ms(message["reported_at"]),
       "decoded" => %{
         "payload" => position(payload),
         "status" => decoded["status"]
       },
       "decoder_error" =>
         decoded["status"] == "error" or not is_nil(decoded["error"]) or
           not is_nil(payload["error"]),
       "hotspots" => hotspots
     }}
  end

  # One entry per gateway that heard the uplink. Gateways without an asserted location
  # (and non-Helium gateways) can't be mapped, so they are left out.
  defp normalize_hotspots(rx_info, uplink_time, tx_frequency, spreading) do
    Enum.flat_map(rx_info, fn info ->
      metadata = dig(info, ["metadata"])
      lat = to_float(dig(metadata, ["gateway_lat"]))
      long = to_float(dig(metadata, ["gateway_long"]))

      if is_nil(lat) or is_nil(long) do
        []
      else
        [
          %{
            "id" => metadata["gateway_id"],
            "name" => metadata["gateway_name"],
            "lat" => lat,
            "long" => long,
            "rssi" => to_float(info["rssi"]),
            "snr" => to_snr(info["snr"]),
            "frequency" => tx_frequency,
            "spreading" => spreading,
            # ChirpStack 4.6 renamed rxInfo time to gwTime and added nsTime
            "reported_at" =>
              pick_time([info["gwTime"], info["nsTime"], info["time"], uplink_time])
          }
        ]
      end
    end)
  end

  defp normalize_console_hotspot(hotspot) do
    Map.merge(hotspot, %{
      "lat" => to_float(hotspot["lat"]),
      "long" => to_float(hotspot["long"]),
      "rssi" => to_float(hotspot["rssi"]),
      "snr" => to_snr(hotspot["snr"]),
      "frequency" => to_float(hotspot["frequency"]),
      "reported_at" => to_ms(hotspot["reported_at"])
    })
  end

  defp position(payload) when is_map(payload) do
    %{
      "latitude" => to_float(payload["latitude"]),
      "longitude" => to_float(payload["longitude"]),
      "altitude" => to_float(payload["altitude"]),
      "accuracy" => to_float(payload["accuracy"]),
      # trackers without a fix may still send their last known position
      "fix_failed" => payload["fixFailed"] == true or payload["gnssFix"] == false
    }
  end

  defp position(_), do: position(%{})

  # ChirpStack leaves snr out when it is exactly 0.0
  defp to_snr(nil), do: 0.0
  defp to_snr(snr), do: to_float(snr)

  defp to_float(value) when is_float(value), do: value
  # JSON integers can be bignums too large for a float
  defp to_float(value) when is_integer(value) and abs(value) < 1.0e300, do: value * 1.0

  # Float.parse raises on digit strings too long for a float
  defp to_float(value) when is_binary(value) and byte_size(value) <= 64 do
    case Float.parse(value) do
      {float, ""} -> float
      _ -> nil
    end
  end

  defp to_float(_), do: nil

  defp to_ms(value) when is_integer(value), do: value
  defp to_ms(value) when is_float(value), do: trunc(value)
  defp to_ms(value), do: parse_reported_at(value)

  defp parse_reported_at(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, datetime, _offset} -> DateTime.to_unix(datetime, :millisecond)
      _ -> nil
    end
  end

  defp parse_reported_at(_), do: nil

  # The first candidate that parses to a plausible time; else the first that parses at all,
  # for validation to reject.
  defp pick_time(candidates) do
    times = candidates |> Enum.map(&parse_reported_at/1) |> Enum.reject(&is_nil/1)
    Enum.find(times, &Ingest.Validate.plausible_time?/1) || List.first(times)
  end

  # get_in that returns nil instead of raising when a level isn't a map
  defp dig(value, []), do: value
  defp dig(%{} = map, [key | rest]), do: dig(Map.get(map, key), rest)
  defp dig(_, _), do: nil
end
