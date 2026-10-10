defmodule Mappers.Repo.Migrations.AddH3Res9GeomIndex do
  use Ecto.Migration

  # Tile queries filter h3_res9 on geom &&. Production got this index by hand on
  # 2026-10-10 under the same name, so there this only records the version.
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists index(:h3_res9, [:geom], using: :gist, concurrently: true)
  end
end
