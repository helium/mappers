defmodule Mappers.Ingest.Validate do
  @max_hotspot_distance_m 500_000
  # uplinks.fcnt and uplinks.altitude are int4 columns
  @max_int4 2_147_483_647
  # 2015-01-01, before any Helium hotspot; clocks can also run wildly ahead (year 2478 seen)
  @earliest_ms 1_420_070_400_000
  @max_ahead_ms 86_400_000

  @doc """
  Checks a normalized message before anything is written. Returns `{:ok, hotspots}` with
  the hotspots that can be stored, or `{:reject, reason, detail}`.
  """
  def validate_message(message) do
    payload = message["decoded"]["payload"]
    lat = payload["latitude"]
    lng = payload["longitude"]
    alt = payload["altitude"]
    acc = payload["accuracy"]

    cond do
      message["decoder_error"] ->
        {:reject, "decoder_error", "the device's payload decoder reported an error"}

      payload["fix_failed"] ->
        {:reject, "no_fix", "the device reported no GPS fix"}

      not (is_float(lat) and is_float(lng)) ->
        {:reject, "no_position", "the decoded payload has no numeric latitude and longitude"}

      lat == 0.0 or lng == 0.0 ->
        {:reject, "no_position", "latitude or longitude is 0"}

      lat < -90 or lat > 90 or lng < -180 or lng > 180 ->
        {:reject, "invalid_position", "latitude or longitude is out of range"}

      not is_float(alt) or alt < -500 or alt >= @max_int4 ->
        {:reject, "invalid_altitude", "altitude is missing, below -500 m or too large"}

      not is_float(acc) or acc < 0 ->
        {:reject, "invalid_accuracy", "accuracy is missing or negative"}

      not is_integer(message["reported_at"]) ->
        {:reject, "no_timestamp", "the uplink has no readable timestamp"}

      not plausible_time?(message["reported_at"]) ->
        {:reject, "invalid_timestamp", "the timestamp is before 2015 or more than a day ahead"}

      true ->
        case invalid_fields(message) do
          [] -> validate_hotspots(message["hotspots"], lat, lng, message["reported_at"])
          invalid -> {:reject, "invalid_field", Enum.join(invalid, ", ")}
        end
    end
  end

  # fields the uplink row requires, checked here so nothing is written for an uplink that
  # would fail its insert
  defp invalid_fields(message) do
    invalid = Enum.reject(["dev_eui", "id", "app_eui"], &text?(message[&1]))
    fcnt = message["fcnt"]

    if is_integer(fcnt) and fcnt >= 0 and fcnt <= @max_int4,
      do: invalid,
      else: invalid ++ ["fcnt"]
  end

  @doc "Whether a millisecond Unix time is after 2015 and at most a day ahead."
  def plausible_time?(ms) when is_integer(ms),
    do: ms >= @earliest_ms and ms <= System.os_time(:millisecond) + @max_ahead_ms

  def plausible_time?(_), do: false

  # a string that fits a varchar(255) column and that the insert's changeset won't treat
  # as blank (Postgres also rejects NUL bytes)
  defp text?(value) do
    is_binary(value) and byte_size(value) <= 255 and String.trim(value) != "" and
      not String.contains?(value, <<0>>)
  end

  defp validate_hotspots([], _lat, _lng, _reported_at) do
    {:reject, "no_hotspot_location", "none of the gateways that heard the uplink has a location"}
  end

  defp validate_hotspots(hotspots, lat, lng, reported_at) do
    {valid, errors} =
      Enum.reduce(hotspots, {[], []}, fn hotspot, {valid, errors} ->
        # a hotspot with a missing or wrong clock still heard the uplink; use the uplink's time
        hotspot =
          if plausible_time?(hotspot["reported_at"]),
            do: hotspot,
            else: Map.put(hotspot, "reported_at", reported_at)

        case validate_hotspot(hotspot, lat, lng) do
          :ok -> {[hotspot | valid], errors}
          {:error, error} -> {valid, [error | errors]}
        end
      end)

    case valid do
      [] ->
        {:reject, "no_valid_hotspots", errors |> Enum.reverse() |> Enum.uniq() |> Enum.join("; ")}

      _ ->
        {:ok, Enum.reverse(valid)}
    end
  end

  defp validate_hotspot(hotspot, lat, lng) do
    hotspot_lat = hotspot["lat"]
    hotspot_lng = hotspot["long"]
    rssi = hotspot["rssi"]
    snr = hotspot["snr"]

    cond do
      not (is_float(hotspot_lat) and is_float(hotspot_lng)) or hotspot_lat == 0.0 or
        hotspot_lng == 0.0 or hotspot_lat < -90 or hotspot_lat > 90 or hotspot_lng < -180 or
          hotspot_lng > 180 ->
        {:error, "invalid hotspot location"}

      distance_m([lat, lng], [hotspot_lat, hotspot_lng]) > @max_hotspot_distance_m ->
        {:error, "hotspot more than 500 km from the device"}

      not is_float(rssi) or rssi < -141 or rssi > 0 ->
        {:error, "invalid rssi"}

      not is_float(snr) or snr < -40 or snr > 40 ->
        {:error, "invalid snr"}

      not (text?(hotspot["id"]) and text?(hotspot["name"])) ->
        {:error, "missing hotspot id or name"}

      not (is_float(hotspot["frequency"]) and text?(hotspot["spreading"])) ->
        {:error, "missing frequency or spreading"}

      true ->
        :ok
    end
  end

  # Geocalc's haversine can take the square root of a value just below 0 for points almost
  # exactly opposite each other on the globe
  defp distance_m(from, to) do
    Geocalc.distance_between(from, to)
  rescue
    ArithmeticError -> 20_037_508.0
  end
end
