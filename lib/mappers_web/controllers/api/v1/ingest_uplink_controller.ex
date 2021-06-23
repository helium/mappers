defmodule MappersWeb.API.V1.IngestUplinkController do
  use MappersWeb, :controller

  alias Mappers.Ingest

  def create(conn, params) do
    resp = Ingest.ingest_uplink(params)
    case resp do
      %{error: _} -> Plug.Conn.put_status(conn, 400)
      _ -> Plug.Conn.put_status(conn, 200)
    end
    |> json(resp)
  end
end
