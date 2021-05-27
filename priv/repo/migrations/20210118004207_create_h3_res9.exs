defmodule Mappers.Repo.Migrations.CreateH3Res9 do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS postgis"

    create table(:h3_res9, primary_key: false) do
      add :id, :string, primary_key: true
      add :h3_index_int, :bigint
      add :state, :string
      add :avg_rssi, :float
      add :avg_snr, :float
      add :geom, :geometry

      timestamps()
    end
  end
end
