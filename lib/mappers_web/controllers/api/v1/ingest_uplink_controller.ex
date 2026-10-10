defmodule MappersWeb.API.V1.IngestUplinkController do
  use MappersWeb, :controller

  alias Mappers.Ingest

  def create(conn, _params) do
    if json?(conn) do
      respond(conn, Ingest.ingest_uplink(conn.body_params, conn.query_params["event"]))
    else
      # Plug.Parsers leaves other bodies (e.g. ChirpStack's Protobuf encoding) unparsed
      fail(conn, 415, "unsupported_encoding", "send JSON with content-type application/json")
    end
  end

  defp respond(conn, {:ok, resp}) do
    conn
    |> put_private(:ingest_reason, "stored")
    |> put_private(:ingest_hotspots, length(resp.hotspots))
    |> json(resp)
  end

  defp respond(conn, {:ignore, reason}) do
    conn
    |> put_private(:ingest_reason, reason)
    |> send_resp(204, "")
  end

  defp respond(conn, {:reject, reason, detail}), do: fail(conn, 422, reason, detail)
  defp respond(conn, {:error, reason, detail}), do: fail(conn, 500, reason, detail)

  defp fail(conn, status, reason, detail) do
    conn
    |> put_private(:ingest_reason, reason)
    |> put_status(status)
    |> json(%{error: reason, detail: detail})
  end

  # the same test Plug.Parsers.JSON uses to decide whether to parse the body
  defp json?(conn) do
    with [content_type | _] <- get_req_header(conn, "content-type"),
         {:ok, "application", subtype, _params} <- Plug.Conn.Utils.content_type(content_type) do
      subtype == "json" or String.ends_with?(subtype, "+json")
    else
      _ -> false
    end
  end
end
