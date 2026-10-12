defmodule MappersWeb.PageControllerTest do
  use MappersWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Helium Mappers"
  end
end
