defmodule MappersWeb.API.V1.HotspotController do
  use MappersWeb, :controller

  alias Mappers.Uplinks

  def search(conn, %{"q" => q}) when byte_size(q) >= 2 do
    conn |> json(%{hotspots: Uplinks.search_hotspots(q)})
  end

  def search(conn, _params) do
    conn |> put_status(400) |> json(%{error: "q must be at least 2 characters"})
  end
end
