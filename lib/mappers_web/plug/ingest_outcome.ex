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

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_private(:ingest_started, System.monotonic_time(:millisecond))
    |> register_before_send(fn conn ->
      log(conn)
      conn
    end)
  end

  @doc "ChirpStack's `?event=`, or \"other\" when it isn't a plain string (e.g. `event[]=up`)."
  def event(conn) do
    case conn.query_params["event"] do
      event when is_binary(event) or is_nil(event) -> event
      _ -> "other"
    end
  end

  defp log(conn) do
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
    started = conn.private[:ingest_started] || System.monotonic_time(:millisecond)

    Logger.info(
      "ingest status=#{status} reason=#{reason} format=#{format} " <>
        "event=#{clean(event(conn), ~r/\A[a-z_]{1,16}\z/)} sender=#{sender(conn)}" <>
        if(hotspots, do: " hotspots=#{hotspots}", else: "") <>
        " ms=#{System.monotonic_time(:millisecond) - started}"
    )
  end

  defp default_reason(429), do: "rate_limited"
  defp default_reason(status) when status >= 500, do: "crash"
  defp default_reason(_status), do: "-"

  defp sender(conn) do
    ip =
      List.first(get_req_header(conn, "cf-connecting-ip")) ||
        conn |> get_req_header("x-forwarded-for") |> List.first() |> first_hop()

    clean(ip, ~r/\A[0-9a-fA-F:.]{1,45}\z/)
  end

  defp first_hop(nil), do: nil
  defp first_hop(forwarded_for), do: forwarded_for |> String.split(",") |> hd() |> String.trim()

  # query strings and headers are sender-controlled; keep each field one token
  defp clean(nil, _pattern), do: "-"

  defp clean(value, pattern) when is_binary(value),
    do: if(value =~ pattern, do: value, else: "other")

  defp clean(_value, _pattern), do: "other"
end
