defmodule MappersWeb.Plug.IngestOutcome do
  @moduledoc """
  One log line and one `ingest.outcome.count` per ingest request, with the status actually
  sent, so failures can be counted by sender and reason.

  It runs first in the ingest pipeline, so requests stopped by the rate limit are logged
  too, and so are crashes: Phoenix renders a crash's 500 with the conn this plug returned.
  The controller adds the reason.
  """
  import Plug.Conn
  require Logger

  alias MappersWeb.Plug.RateLimit

  def init(opts), do: opts

  def call(conn, _opts) do
    started = System.monotonic_time(:millisecond)

    register_before_send(conn, fn conn ->
      log(conn, started)
      conn
    end)
  end

  defp log(conn, started) do
    status = conn.status
    # reasons are always one of a fixed set of codes
    reason = conn.private[:ingest_reason] || default_reason(status)
    format = Mappers.Ingest.format(conn.body_params)

    :telemetry.execute([:ingest, :outcome], %{count: 1}, %{
      status: status,
      reason: reason,
      format: format
    })

    hotspots = conn.private[:ingest_hotspots]

    # the query string and headers are sender-controlled; keep each field one token
    Logger.info(
      "ingest status=#{status} reason=#{reason} format=#{format} " <>
        "event=#{clean(conn.query_params["event"], ~r/\A[a-z_]{1,16}\z/)} " <>
        "sender=#{clean(RateLimit.client_ip(conn), ~r/\A[0-9a-fA-F:.]{1,45}\z/)}" <>
        if(hotspots, do: " hotspots=#{hotspots}", else: "") <>
        " ms=#{System.monotonic_time(:millisecond) - started}"
    )
  end

  defp default_reason(429), do: "rate_limited"
  defp default_reason(status) when status >= 500, do: "crash"
  defp default_reason(_status), do: "-"

  defp clean(nil, _pattern), do: "-"

  defp clean(value, pattern) when is_binary(value),
    do: if(value =~ pattern, do: value, else: "other")

  # e.g. ?event[]=up
  defp clean(_value, _pattern), do: "other"
end
