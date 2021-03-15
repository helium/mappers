defmodule Mappers.Repo.Migrations.CreateH3Res9Blank do
  use Ecto.Migration

  def change do
    create table(:h3_res9_blank, primary_key: false) do
      add :id, :string, primary_key: true
      add :geom, :geometry

      timestamps()
    end

  end
end
