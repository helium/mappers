defmodule Mappers.Repo.Migrations.CreateH3Links do
  use Ecto.Migration

  def change do
    create table(:h3_links) do
      add :uplink_id, references(:uplinks, type: :uuid, on_delete: :nothing)
      add :h3_res9_id, references(:h3_res9, type: :string, on_delete: :nothing)

      timestamps()
    end

    create index(:h3_links, [:uplink_id])
    create index(:h3_links, [:h3_res9_id])
  end
end
