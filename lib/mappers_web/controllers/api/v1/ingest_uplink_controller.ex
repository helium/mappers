defmodule MappersWeb.API.V1.IngestUplinkController do
  use MappersWeb, :controller

  alias Mappers.Ingest

  def create(conn, params) do
    start = System.monotonic_time()
    resp = Ingest.ingest_uplink(params)
    :telemetry.execute([:ingest, :request], %{duration: System.monotonic_time() - start}, conn)
    conn |> json(resp)
  end
end
