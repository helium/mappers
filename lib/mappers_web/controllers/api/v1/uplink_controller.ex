defmodule MappersWeb.API.V1.UplinkController do
  use MappersWeb, :controller

  alias Mappers.Uplinks
  alias Mappers.Uplinks.Filter

  def get_uplinks(conn, %{"h3_index" => h3_index} = params) do
    case Filter.parse(params) do
      {:ok, filter} ->
        conn |> json(%{uplinks: Uplinks.get_uplinks(h3_index, filter)})

      {:error, reason} ->
        conn |> put_status(400) |> json(%{error: reason})
    end
  end

  def get_latest(conn, params) do
    case Filter.parse(params) do
      {:ok, filter} ->
        conn |> json(%{latest: Uplinks.get_latest_uplink(filter)})

      {:error, reason} ->
        conn |> put_status(400) |> json(%{error: reason})
    end
  end
end
