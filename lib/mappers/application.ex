defmodule Mappers.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Mappers.Repo,
      # Start the Telemetry supervisor
      MappersWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Mappers.PubSub},
      # Start the Endpoint (http/https)
      MappersWeb.Endpoint
      # Start a worker by calling: Mappers.Worker.start_link(arg)
      # {Mappers.Worker, arg}
    ]

    :ok = :telemetry.attach(
    # unique handler id
    "ingest-h3-res9-new-count",
    [:ingest, :h3, :res9, :new],
    &MappersWeb.Telemetry.Metrics.handle_event_h3_res9_new/4,
    nil
    )

    :ok = :telemetry.attach(
    # unique handler id
    "ingest-h3-res9-existing-count",
    [:ingest, :h3, :res9, :existing],
    &MappersWeb.Telemetry.Metrics.handle_event_h3_res9_existing/4,
    nil
    )

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Mappers.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    MappersWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
