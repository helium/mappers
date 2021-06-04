defmodule MappersWeb.API.V1.IngestUplinkController do
  use MappersWeb, :controller

  alias Mappers.Ingest

  def create(conn, params) do
    resp = Ingest.ingest_uplink(params)
    MappersWeb.Endpoint.broadcast!("h3:new", "new_h3", %{body: %{id: resp.h3_res9_id, avg_rssi: resp.avg_rssi, avg_snr: resp.avg_snr}})
    conn |> json(resp.resp)
  end
end
