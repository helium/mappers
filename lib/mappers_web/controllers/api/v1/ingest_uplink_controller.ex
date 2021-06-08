defmodule MappersWeb.API.V1.IngestUplinkController do
  use MappersWeb, :controller

  alias Mappers.Ingest

  def create(conn, params) do
    resp = Ingest.ingest_uplink(params)
    conn |> json(resp.resp)
  end
end
