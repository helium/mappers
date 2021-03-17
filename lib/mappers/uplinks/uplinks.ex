defmodule Mappers.Uplinks do
  alias Mappers.Repo
  alias Mappers.Uplinks.Uplink

  def create(uplink) do

    %Uplink{}
    |> Uplink.changeset(uplink)
    |> Repo.insert()
  end
end
