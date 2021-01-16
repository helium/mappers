defmodule Mappers.Uplinks.Uplink do
  use Ecto.Schema
  import Ecto.Changeset

  schema "uplinks" do
    field :dev_eui, :string
    field :app_eui, :string
    field :device_id, :string
    field :fcnt, :integer
    field :frequency, :float
    field :spreading_factor, :string
    field :gps_accuracy, :integer
    field :first_timestamp, :utc_datetime_usec
  end

  @doc false
  def changeset(uplink, attrs) do
    uplink
    |> cast(attrs, [:id, :dev_eui, :app_eui, :device_id, :fcnt, :frequency, :spreading_factor, :gps_accuracy, :first_timestamp])
    |> validate_required([:id, :dev_eui, :app_eui, :device_id, :fcnt, :frequency, :spreading_factor, :gps_accuracy, :first_timestamp])
  end
end
