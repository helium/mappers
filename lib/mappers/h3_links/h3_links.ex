defmodule Mappers.H3.Links do
  alias Mappers.Repo
  alias Mappers.H3.Links.Link

  def create(h3_res9_id, uplink_id) do
    link = %{}
      |> Map.put(:uplink_id, uplink_id)
      |> Map.put(:h3_res9_id, h3_res9_id)

    %Link{}
    |> Link.changeset(link)
    |> Repo.insert()
    |> case do
      {:ok, changeset} -> {:ok, changeset}
      {:error, _} -> {:error, "H3 Link Insert Error"}
    end
  end
end
