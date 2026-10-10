defmodule Mappers.IngestFixtures do
  @moduledoc """
  Uplink bodies in the shapes captured from production on 2026-10-09. The keys and value
  types match what senders posted; every value is made up.
  """

  @doc """
  POSTs a body as JSON to the ingest endpoint. Unless the conn already names a sender, it
  gets one of its own, so tests don't share a rate-limit bucket.
  """
  def post_uplink(conn, body, query \\ "") do
    conn
    |> Plug.Conn.put_req_header("content-type", "application/json")
    |> ensure_sender()
    |> Phoenix.ConnTest.dispatch(
      MappersWeb.Endpoint,
      :post,
      "/api/v1/ingest/uplink" <> query,
      Jason.encode!(body)
    )
  end

  defp ensure_sender(conn) do
    case Plug.Conn.get_req_header(conn, "cf-connecting-ip") do
      [] ->
        n = System.unique_integer([:positive])

        Plug.Conn.put_req_header(
          conn,
          "cf-connecting-ip",
          "10.#{rem(div(n, 65_536), 256)}.#{rem(div(n, 256), 256)}.#{rem(n, 256)}"
        )

      _ ->
        conn
    end
  end

  @doc "A ChirpStack v4.6+ `up` event: rxInfo has gwTime/nsTime and no time."
  def chirpstack_up do
    %{
      "deduplicationId" => "6f1c2d3e-1111-4222-8333-944455556666",
      "time" => "2026-10-09T16:43:50.700+00:00",
      "deviceInfo" => %{
        "tenantId" => "0d1f6c2a-0000-4000-8000-000000000001",
        "tenantName" => "Example Tenant",
        "applicationId" => "0d1f6c2a-0000-4000-8000-000000000002",
        "applicationName" => "Mappers",
        "deviceProfileId" => "0d1f6c2a-0000-4000-8000-000000000003",
        "deviceProfileName" => "Tracker",
        "deviceName" => "tracker-1",
        "devEui" => "a84041000181c0de",
        "deviceClassEnabled" => "CLASS_A",
        "tags" => %{}
      },
      "devAddr" => "fc00ac11",
      "adr" => true,
      "dr" => 5,
      "fCnt" => 42,
      "fPort" => 2,
      "confirmed" => false,
      "data" => "AQID",
      "regionConfigId" => "eu868",
      "object" => %{
        "latitude" => 51.5072,
        "longitude" => -0.1276,
        "altitude" => 35.0,
        "accuracy" => 4.2,
        "fixFailed" => false,
        "inTrip" => true,
        "batV" => 3.9,
        "headingDeg" => 90.0,
        "speedKmph" => 12.0,
        "manDown" => nil,
        "type" => "position"
      },
      "rxInfo" => [
        rx_info(
          "11exampleGatewayOne",
          "example-gateway-one",
          "51.508000000000003",
          "-0.128000000000000",
          -95,
          7.5
        ),
        rx_info(
          "11exampleGatewayTwo",
          "example-gateway-two",
          "51.501000000000001",
          "-0.120000000000000",
          -110,
          -3.25
        )
      ],
      "txInfo" => %{
        "frequency" => 868_100_000,
        "modulation" => %{
          "lora" => %{"bandwidth" => 125_000, "spreadingFactor" => 7, "codeRate" => "CR_4_5"}
        }
      }
    }
  end

  @doc "One rxInfo entry as Helium Packet Router and ChirpStack 4.6+ report it."
  def rx_info(gateway_id, name, lat, long, rssi, snr) do
    %{
      "gatewayId" => "6081f9fffe000001",
      "uplinkId" => 1234,
      "gwTime" => "2026-10-09T16:43:50.712Z",
      "nsTime" => "2026-10-09T16:43:50.731Z",
      "rssi" => rssi,
      "snr" => snr,
      "context" => "AAAAAA==",
      "crcStatus" => "CRC_OK",
      "metadata" => %{
        "gateway_id" => gateway_id,
        "gateway_name" => name,
        "gateway_lat" => lat,
        "gateway_long" => long,
        "gateway_h3index" => "8c194ad30d067ff",
        "network" => "helium_iot",
        "regi" => "EU868"
      }
    }
  end

  @doc "A ChirpStack `log` event body (posted with ?event=log)."
  def chirpstack_log do
    %{
      "time" => "2026-10-09T16:43:53.600+00:00",
      "deviceInfo" => chirpstack_up()["deviceInfo"],
      "level" => "ERROR",
      "code" => "UPLINK_CODEC",
      "description" => "example codec error",
      "context" => %{
        "deduplication_id" => "6f1c2d3e-1111-4222-8333-944455556666",
        "f_cnt_up" => "42"
      }
    }
  end

  @doc "A Helium Console uplink in the minimal shape (no dc, metadata or downlink_url)."
  def console_uplink do
    %{
      "app_eui" => "6081F9A1B2C3D4E5",
      "dev_eui" => "6081F9F6E5D4C3B2",
      "devaddr" => "48000a1b",
      "fcnt" => 101,
      "id" => "1b9a6c5e-1111-4222-8333-944455556666",
      "name" => "6081f9f6e5d4c3b2",
      "payload" => "AQIDBA==",
      "port" => 2,
      "reported_at" => 1_791_571_430_000,
      "type" => "uplink",
      "decoded" => %{
        "payload" => %{
          "latitude" => -33.8688,
          "longitude" => 151.2093,
          "altitude" => 58,
          "accuracy" => 2.5,
          "hdop" => 1,
          "sats" => 9
        }
      },
      "hotspots" => [
        hotspot("11exampleHotspotThree", "example-hotspot-three", -33.87, 151.21, -101, 6.5),
        hotspot("11exampleHotspotFour", "example-hotspot-four", -33.865, 151.2, -117, -9.0)
      ]
    }
  end

  @doc "One Console hotspot entry."
  def hotspot(id, name, lat, long, rssi, snr) do
    %{
      "id" => id,
      "name" => name,
      "lat" => lat,
      "long" => long,
      "rssi" => rssi,
      "snr" => snr,
      "reported_at" => 1_791_571_430_120,
      "frequency" => 916.8,
      "spreading" => "SF9BW125",
      "channel" => 3
    }
  end
end
