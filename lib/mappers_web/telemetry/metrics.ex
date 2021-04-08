defmodule MappersWeb.Telemetry.Metrics do
  require Logger

  def handle_event([:ingest, :request], %{duration: dur}, metadata, _config) do
    # do some stuff like log a message or report metrics to a service like StatsD
    Logger.info("Received [:ingest, :request] event. Request duration: #{dur}, Route: #{metadata.request_path}")
  end
end
