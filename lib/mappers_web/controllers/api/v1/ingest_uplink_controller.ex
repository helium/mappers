defmodule MappersWeb.API.V1.IngestUplinkController do
  use MappersWeb, :controller

  alias Mappers.Ingest
  alias MappersWeb.Plug.IngestOutcome

  def create(conn, _params) do
    if json?(conn) do
      respond(conn, Ingest.ingest_uplink(conn.body_params, IngestOutcome.event(conn)))
    else
      # Plug.Parsers leaves other bodies (e.g. ChirpStack's Protobuf encoding) unparsed
      conn
      |> put_private(:ingest_reason, "unsupported_encoding")
      |> put_status(415)
      |> json(%{
        error: "unsupported_encoding",
        detail: "send JSON with content-type application/json"
      })
    end
  end

  defp respond(conn, {:ok, resp}) do
    conn
    |> put_private(:ingest_reason, "stored")
    |> put_private(:ingest_hotspots, length(resp.hotspots))
    |> put_status(200)
    |> json(resp)
  end

  defp respond(conn, {:ignore, reason}) do
    conn
    |> put_private(:ingest_reason, reason)
    |> send_resp(204, "")
  end

  defp respond(conn, {:reject, reason, detail}) do
    conn
    |> put_private(:ingest_reason, reason)
    |> put_status(422)
    |> json(%{error: reason, detail: detail})
  end

  defp respond(conn, {:error, reason, detail}) do
    conn
    |> put_private(:ingest_reason, reason)
    |> put_status(500)
    |> json(%{error: reason, detail: detail})
  end

  defp json?(conn) do
    case get_req_header(conn, "content-type") do
      [type | _] -> type =~ ~r{\Aapplication/([\w.-]+\+)?json\b}i
      [] -> false
    end
  end
end
