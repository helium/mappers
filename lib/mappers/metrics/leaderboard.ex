defmodule Mappers.Metrics.Leaderboard do
  import Ecto.Query
  alias Mappers.Repo
  alias Mappers.H3.Links.Link
  alias Mappers.Uplinks.Uplink

  def get_leaders() do
    query =
      from l in Link,
        join: u in Uplink,
        on: u.id == l.uplink_id,
        group_by: u.device_id,
        order_by: [desc: count(l.h3_res9_id, :distinct)],
        select: %{
          device_id: u.device_id,
          total_unique_hex: count(l.h3_res9_id, :distinct)
        }

    Repo.all(query)
  end
end
