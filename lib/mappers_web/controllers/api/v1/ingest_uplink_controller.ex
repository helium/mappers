defmodule MappersWeb.API.V1.IngestUplinkController do
  use MappersWeb, :controller

  alias Mappers.Ingest

  def create(conn, params) do
    resp = Ingest.ingest_uplink(params)
    MappersWeb.Endpoint.broadcast!("h3:new", "new_h3", %{body: %{h3_id: resp.h3_res9_id, average_rssi: resp.average_rssi}})
    conn |> json(resp.resp)
  end
end
