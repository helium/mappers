defmodule Mappers.Repo.Migrations.CreateH3Res9 do
  use Ecto.Migration

  def change do
    create table(:h3_res9, primary_key: false) do
      add :id, :string, primary_key: true
      add :state, :string
      add :average_rssi, :integer

      timestamps()
    end

  end
end
