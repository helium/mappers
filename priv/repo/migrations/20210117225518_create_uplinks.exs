defmodule Mappers.Repo.Migrations.CreateUplinks do
  use Ecto.Migration

  def change do
    create table(:uplinks, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :dev_eui, :string
      add :app_eui, :string
      add :device_id, :string
      add :fcnt, :integer
      add :frequency, :float
      add :spreading_factor, :string
      add :altitude, :integer
      add :gps_accuracy, :float
      add :first_timestamp, :utc_datetime_usec
    end

  end
end
