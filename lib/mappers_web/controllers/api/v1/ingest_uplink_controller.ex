defmodule MappersWeb.API.V1.IngestUplinkController do
  use MappersWeb, :controller

  alias Mappers.Ingest
  alias Mappers.Uplinks.Uplink

  def create(conn, params) do
    with {:ok, %Uplink{} = uplink} <- Ingest.ingest_uplink(params) do
      conn |> json(uplink)
    end
  end
end
