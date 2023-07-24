# Example: config/appsignal.exs
config :appsignal, :config,
  ignore_actions: ["MappersWeb.API.V1.IngestUplinkController#create"]
