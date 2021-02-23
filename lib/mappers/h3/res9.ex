defmodule Mappers.H3.Res9 do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, []}
  schema "h3_res9" do
    field :state, :string
    field :average_rssi, :integer
    field :geom, Geo.PostGIS.Geometry

    timestamps()
  end

  @doc false
  def changeset(res9, attrs) do
    res9
    |> cast(attrs, [:id, :state, :average_rssi, :geom])
    |> validate_required([:id, :state, :average_rssi, :geom])
  end
end
