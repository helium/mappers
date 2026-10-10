defmodule MappersWeb.Plug.RateLimit do
  import Plug.Conn

  def init(default), do: default

  def call(conn, [action, limit]) do
    case Hammer.check_rate("#{action}:#{client_ip(conn)}", 60_000, limit) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        conn
        |> send_resp(:too_many_requests, "Too many requests")
        |> halt()

      # the limiter's backend failed; don't drop the request over it
      {:error, _reason} ->
        conn
    end
  end

  @doc "The client's IP as Cloudflare or the first X-Forwarded-For hop reports it, if any."
  def client_ip(conn) do
    case get_req_header(conn, "cf-connecting-ip") do
      [ip | _] ->
        ip

      [] ->
        case get_req_header(conn, "x-forwarded-for") do
          [forwarded_for | _] -> forwarded_for |> String.split(",") |> hd() |> String.trim()
          [] -> nil
        end
    end
  end
end
