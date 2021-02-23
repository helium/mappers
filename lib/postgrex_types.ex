Postgrex.Types.define(Mappers.PostgresTypes,
                      [Geo.PostGIS.Extension] ++ Ecto.Adapters.Postgres.extensions(),
                      json: Jason)
