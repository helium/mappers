defmodule Mappers.H3.Res9Blank do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, []}
  schema "h3_res9_blank" do
    field :geom, Geo.PostGIS.Geometry

    timestamps()
  end

  @doc false
  def changeset(res9_blank, attrs) do
    res9_blank
    |> cast(attrs, [:id, :geom])
    |> validate_required([:id, :geom])
  end
end
