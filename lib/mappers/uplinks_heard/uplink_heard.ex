defmodule Mappers.UplinksHeards.UplinkHeard do
  use Ecto.Schema
  import Ecto.Changeset

  @fields [
    :hotspot_address,
    :hotspot_name,
    :latitude,
    :longitude,
    :rssi,
    :snr,
    :timestamp
  ]

  @derive {Jason.Encoder, only: @fields}
  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "uplinks_heard" do
    field :hotspot_address, :string
    field :hotspot_name, :string
    field :latitude, :float
    field :longitude, :float
    field :rssi, :float
    field :snr, :float
    field :timestamp, :utc_datetime_usec
    field :uplink_id, Ecto.UUID
  end

  @doc false
  def changeset(uplink_heard, attrs) do
    uplink_heard
    |> cast(attrs, [:hotspot_address, :hotspot_name, :latitude, :longitude, :rssi, :snr, :timestamp, :uplink_id])
    |> validate_required([:hotspot_address, :hotspot_name, :latitude, :longitude, :rssi, :snr, :timestamp, :uplink_id])
  end
end
