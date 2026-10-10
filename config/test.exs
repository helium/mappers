use Mix.Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :mappers, Mappers.Repo,
  username: "postgres",
  password: "postgres",
  database: "mappers_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# Point tests at another server, e.g. TEST_DATABASE_URL=ecto://user:pass@host:port/mappers_test
if url = System.get_env("TEST_DATABASE_URL") do
  config :mappers, Mappers.Repo, url: url
end

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :mappers, MappersWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn
