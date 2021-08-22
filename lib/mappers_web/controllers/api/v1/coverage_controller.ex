defmodule MappersWeb.API.V1.CoverageController do
  use MappersWeb, :controller

  alias Mappers.Coverage

  def get_coverage_from_geo(conn, %{"coords" => coords}) do
    resp = Coverage.get_coverage_from_geo(coords)

    case resp do
      %{error: error} -> Plug.Conn.put_status(conn, 400)
      _ -> Plug.Conn.put_status(conn, 200)
    end
    |> json(resp)
  end
end
