defmodule Mappers.Uplinks.Filter do
  @moduledoc """
  Parses the optional coverage filters shared by the hex API and the
  filtered tile source: `start` (inclusive), `end` (exclusive), and
  `hotspot` (exact hotspot name). Dates are ISO 8601 dates or datetimes;
  a bare date means midnight UTC.
  """

  defstruct start: nil, end: nil, hotspot: nil

  def parse(params) do
    with {:ok, start_at} <- parse_time(params["start"], "start"),
         {:ok, end_at} <- parse_time(params["end"], "end"),
         :ok <- check_order(start_at, end_at) do
      {:ok, %__MODULE__{start: start_at, end: end_at, hotspot: blank_to_nil(params["hotspot"])}}
    end
  end

  defp parse_time(value, name) do
    case blank_to_nil(value) do
      nil ->
        {:ok, nil}

      value ->
        case DateTime.from_iso8601(value) do
          {:ok, datetime, _offset} ->
            {:ok, datetime}

          {:error, _} ->
            case Date.from_iso8601(value) do
              {:ok, date} -> DateTime.new(date, ~T[00:00:00], "Etc/UTC")
              {:error, _} -> {:error, "Invalid #{name}: expected an ISO 8601 date or datetime"}
            end
        end
    end
  end

  defp check_order(%DateTime{} = start_at, %DateTime{} = end_at) do
    if DateTime.compare(start_at, end_at) == :lt,
      do: :ok,
      else: {:error, "start must be before end"}
  end

  defp check_order(_, _), do: :ok

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(_), do: nil
end
