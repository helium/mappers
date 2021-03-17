defmodule Mappers.UplinksHeards.UplinkHeard do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, []}
  schema "uplinks_heard" do
    field :hotspot_address, :string
    field :hotspot_name, :string
    field :latitude, :float
    field :longitude, :float
    field :rssi, :integer
    field :snr, :float
    field :timestamp, :utc_datetime_usec
    field :uplink_id, :id
  end

  @doc false
  def changeset(uplink_heard, attrs) do
    uplink_heard
    |> cast(attrs, [:id, :hotspot_address, :hotspot_name, :latitude, :longitude, :rssi, :snr, :timestamp])
    |> validate_required([:id, :hotspot_address, :hotspot_name, :latitude, :longitude, :rssi, :snr, :timestamp])
  end
end
