defmodule Mappers.Repo.Migrations.CreateUplinksHeard do
  use Ecto.Migration

  def change do
    create table(:uplinks_heard, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :hotspot_address, :string
      add :hotspot_name, :string
      add :latitude, :float
      add :longitude, :float
      add :rssi, :float
      add :snr, :float
      add :timestamp, :utc_datetime_usec
      add :uplink_id, references(:uplinks, type: :uuid, on_delete: :delete_all)
    end

    create index(:uplinks_heard, [:uplink_id])
  end
end
