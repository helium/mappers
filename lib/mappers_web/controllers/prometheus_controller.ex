defmodule MappersWeb.PrometheusController do
  use MappersWeb, :controller
  alias Plug.Conn

  def scrape(conn, _params) do
    name = :prometheus_metrics
    metrics = TelemetryMetricsPrometheus.Core.scrape(name)

    conn
    |> Conn.put_private(:prometheus_metrics_name, name)
    |> Conn.put_resp_content_type("text/plain")
    |> Conn.send_resp(200, metrics)
  end
end
