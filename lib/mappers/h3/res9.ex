defmodule Mappers.H3.Res9 do
  use Ecto.Schema
  import Ecto.Changeset

  schema "h3_res9" do
    field :state, :string
    field :average_rssi, :integer

    timestamps()
  end

  @doc false
  def changeset(res9, attrs) do
    res9
    |> cast(attrs, [:id, :state, :average_rssi])
    |> validate_required([:id, :state, :average_rssi])
  end
end
