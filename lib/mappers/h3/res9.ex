defmodule Mappers.H3.Res9 do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, []}
  schema "h3_res9" do
    field :state, :string
    field :avg_rssi, :float
    field :avg_snr, :float
    field :geom, Geo.PostGIS.Geometry

    timestamps()
  end

  @doc false
  def changeset(res9, attrs) do
    res9
    |> cast(attrs, [:id, :state, :avg_rssi, :avg_snr, :geom])
    |> validate_required([:id, :state, :avg_rssi, :avg_snr, :geom])
  end
end
