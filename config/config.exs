# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :mappers,
  ecto_repos: [Mappers.Repo]

# Configures the endpoint
config :mappers, MappersWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "whCfGAlaLabs2q5lgrSINZYucrspLGDHrrr1njEDFiOttXrhI3lS0ryNAHoF1e8X",
  render_errors: [view: MappersWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Mappers.PubSub,
  live_view: [signing_salt: "4qo9q6yd"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
