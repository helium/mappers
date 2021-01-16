defmodule Mappers.H3.Link do
  use Ecto.Schema
  import Ecto.Changeset

  schema "h3_links" do
    field :uplink_id, :id
    field :h3_res9_id, :id

    timestamps()
  end

  @doc false
  def changeset(link, attrs) do
    link
    |> cast(attrs, [])
    |> validate_required([])
  end
end
