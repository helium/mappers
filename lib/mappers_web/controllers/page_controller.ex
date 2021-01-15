defmodule MappersWeb.PageController do
  use MappersWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
