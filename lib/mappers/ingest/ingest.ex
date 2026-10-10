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
      {event, _} when not is_nil(event) and event != "up" ->
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
          store(%{message | "hotspots" => hotspots})
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

  defp store(message) do
    with {:ok, h3_res9} <- H3.create(message),
         {:ok, uplink} <- Uplinks.create(message),
         {:ok, uplinks_heard} <- UplinksHeard.create(message["hotspots"], uplink.id),
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
    spreading = spreading(dig(message, ["txInfo", "modulation", "lora"]))
    frequency_hz = to_float(dig(message, ["txInfo", "frequency"]))

    cond do
      is_nil(spreading) ->
        {:reject, "unsupported_modulation", "only LoRa uplinks can be mapped"}

      is_nil(frequency_hz) ->
        {:reject, "missing_field", "txInfo.frequency"}

      true ->
        dev_eui = dig(message, ["deviceInfo", "devEui"])
        # the network server's own receive times back up the event time
        ns_times = for info <- message["rxInfo"], is_map(info), do: info["nsTime"]
        reported_at = pick_time([message["time"] | ns_times])

        {:ok,
         %{
           # ChirpStack does not provide this field
           "app_eui" => "0000000000000000",
           "dev_eui" => dev_eui,
           "id" => dev_eui,
           # protobuf JSON may leave out fields at their default, so a missing fCnt is 0
           "fcnt" => message["fCnt"] || 0,
           "reported_at" => reported_at,
           "frequency" => frequency_hz / 1_000_000,
           "spreading" => spreading,
           "decoded" => %{"payload" => position(message["object"])},
           "decoder_error" => false,
           "hotspots" => normalize_hotspots(message["rxInfo"], reported_at)
         }}
    end
  end

  defp normalize_payload(:console, message) do
    payload = dig(message, ["decoded", "payload"])
    reported_at = to_ms(message["reported_at"])

    hotspots =
      message["hotspots"]
      |> Enum.filter(&is_map/1)
      |> Enum.map(&normalize_console_hotspot(&1, reported_at))

    # the uplink's frequency and spreading, from the first hotspot that reports them
    radio = Enum.find(hotspots, %{}, &(is_float(&1["frequency"]) and is_binary(&1["spreading"])))

    {:ok,
     %{
       "app_eui" => message["app_eui"],
       "dev_eui" => message["dev_eui"],
       "id" => message["id"],
       "fcnt" => message["fcnt"],
       "reported_at" => reported_at,
       "frequency" => radio["frequency"],
       "spreading" => radio["spreading"],
       "decoded" => %{"payload" => position(payload)},
       "decoder_error" =>
         dig(message, ["decoded", "status"]) == "error" or
           not is_nil(dig(message, ["decoded", "error"])) or not is_nil(dig(payload, ["error"])),
       "hotspots" => hotspots
     }}
  end

  # One entry per gateway that heard the uplink. Gateways without an asserted location
  # (and non-Helium gateways) can't be mapped, so they are left out.
  defp normalize_hotspots(rx_info, reported_at) do
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
            # ChirpStack 4.6 renamed rxInfo time to gwTime and added nsTime; a gateway with
            # a wrong clock gets the uplink's time
            "reported_at" =>
              pick_time([info["gwTime"], info["nsTime"], info["time"], reported_at])
          }
        ]
      end
    end)
  end

  defp normalize_console_hotspot(hotspot, reported_at) do
    Map.merge(hotspot, %{
      "lat" => to_float(hotspot["lat"]),
      "long" => to_float(hotspot["long"]),
      "rssi" => to_float(hotspot["rssi"]),
      "snr" => to_snr(hotspot["snr"]),
      "frequency" => to_float(hotspot["frequency"]),
      # a hotspot with a missing or wrong clock gets the uplink's time
      "reported_at" => pick_time([hotspot["reported_at"], reported_at])
    })
  end

  defp spreading(%{"spreadingFactor" => sf, "bandwidth" => bw})
       when is_integer(sf) and is_integer(bw),
       do: "SF#{sf}BW#{div(bw, 1000)}"

  defp spreading(_lora), do: nil

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

  # milliseconds from a ms number or an ISO 8601 string
  defp to_ms(value) when is_integer(value), do: value
  defp to_ms(value) when is_float(value), do: trunc(value)

  defp to_ms(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> DateTime.to_unix(datetime, :millisecond)
      _ -> nil
    end
  end

  defp to_ms(_), do: nil

  # The first candidate that is a plausible time; else the first readable one, for
  # validation to reject.
  defp pick_time(candidates) do
    times = candidates |> Enum.map(&to_ms/1) |> Enum.reject(&is_nil/1)
    Enum.find(times, &Ingest.Validate.plausible_time?/1) || List.first(times)
  end

  # get_in that returns nil instead of raising when a level isn't a map
  defp dig(value, []), do: value
  defp dig(%{} = map, [key | rest]), do: dig(Map.get(map, key), rest)
  defp dig(_, _), do: nil
end
