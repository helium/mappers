defmodule Mappers.H3.Res9 do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, []}
  schema "h3_res9" do
    field :h3_index_int, :integer
    field :state, :string
    field :best_rssi, :float
    field :snr, :float
    field :geom, Geo.PostGIS.Geometry
    field :last_heard, :integer

    timestamps()
  end

  @doc false
  def changeset(res9, attrs) do
    res9
    |> cast(attrs, [:id, :h3_index_int, :state, :best_rssi, :snr, :geom, :last_heard])
    |> validate_required([:id, :h3_index_int, :state, :best_rssi, :snr, :geom])
  end
end
