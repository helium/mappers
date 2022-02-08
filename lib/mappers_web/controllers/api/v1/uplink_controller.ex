defmodule MappersWeb.API.V1.UplinkController do
  use MappersWeb, :controller

  alias Mappers.Uplinks

  def get_uplinks(conn, %{ "h3_index" => h3_index }) do
    IO.puts(h3_index)
    uplinks = Uplinks.get_uplinks(h3_index)
    conn |> json(%{uplinks: uplinks})
  end

  def get_hotspot_uplinks(conn, %{ "hotspot_name" => hotspot_name }) do
    IO.puts(hotspot_name)
    uplinks = Uplinks.get_hotspot_uplinks(hotspot_name)
    conn |> json(%{uplinks: uplinks})
  end
end
