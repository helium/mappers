defmodule MappersWeb.LeaderboardController do
  use MappersWeb, :controller
  alias Mappers.Metrics.Leaderboard

  def index(conn, _params) do
    leaders = Leaderboard.get_leaders()
    render(conn, "index.html", leaders: leaders)
  end
end
