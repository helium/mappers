defmodule MappersWeb.Telemetry.Metrics do
  require Logger

  def handle_event_h3_res9_new([:ingest, :h3, :res9, :new], %{h3_res9_id: h3_res9_id}, metadata, _config) do
    # do some stuff like log a message or report metrics to a service like StatsD
    Logger.info("Received [:ingest, :h3, :res9, :new] event. New H3: #{h3_res9_id}")
  end

  def handle_event_h3_res9_existing([:ingest, :h3, :res9, :existing], %{h3_res9_id: h3_res9_id}, metadata, _config) do
    # do some stuff like log a message or report metrics to a service like StatsD
    Logger.info("Received [:ingest, :h3, :res9, :existing] event. Existing H3: #{h3_res9_id}")
  end
end
