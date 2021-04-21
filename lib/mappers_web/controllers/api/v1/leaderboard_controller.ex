defmodule MappersWeb.API.V1.LeaderboardController do
  use MappersWeb, :controller
  alias Mappers.Metrics.Leaderboard

  def index(conn, _params) do
    leaders = Leaderboard.get_leaders()
    conn |> json(leaders)
  end
end
