defmodule MappersWeb.API.V1.CoverageFiltersTest do
  use MappersWeb.ConnCase

  alias Mappers.Ingest

  @lat 37.7749
  @lng -122.4194
  @hex :h3.from_geo({@lat, @lng}, 9) |> :h3.to_string() |> to_string()

  setup do
    ingest("2024-03-01T10:00:00Z", "happy-amber-moose", -100)
    ingest("2025-06-01T10:00:00Z", "quiet-cedar-otter", -90)
    :ok
  end

  describe "GET /api/v1/uplinks/hex/:h3_index" do
    test "returns every hotspot without filters", %{conn: conn} do
      assert names(get(conn, "/api/v1/uplinks/hex/#{@hex}")) ==
               ["happy-amber-moose", "quiet-cedar-otter"]
    end

    test "filters by heard time", %{conn: conn} do
      conn = get(conn, "/api/v1/uplinks/hex/#{@hex}?start=2025-01-01&end=2026-01-01")
      assert names(conn) == ["quiet-cedar-otter"]
    end

    test "filters by hotspot", %{conn: conn} do
      conn = get(conn, "/api/v1/uplinks/hex/#{@hex}?hotspot=happy-amber-moose")
      assert names(conn) == ["happy-amber-moose"]
    end

    test "rejects a bad date", %{conn: conn} do
      conn = get(conn, "/api/v1/uplinks/hex/#{@hex}?start=nope")
      assert %{"error" => "Invalid start" <> _} = json_response(conn, 400)
    end
  end

  describe "GET /api/v1/hotspots" do
    test "matches name prefixes, with spaces treated as dashes", %{conn: conn} do
      conn = get(conn, "/api/v1/hotspots?q=Happy%20Amber")
      assert [%{"name" => "happy-amber-moose", "lat" => _, "lng" => _}] = json_response(conn, 200)["hotspots"]
    end

    test "does not match the middle of a name", %{conn: conn} do
      assert json_response(get(conn, "/api/v1/hotspots?q=amber"), 200)["hotspots"] == []
    end

    test "requires two characters", %{conn: conn} do
      assert json_response(get(conn, "/api/v1/hotspots?q=h"), 400)
    end

    test "wildcards and spaces don't count toward the two characters", %{conn: conn} do
      assert json_response(get(conn, "/api/v1/hotspots?q=%25%25"), 200)["hotspots"] == []
      assert json_response(get(conn, "/api/v1/hotspots?q=++"), 200)["hotspots"] == []
    end
  end

  defp names(conn) do
    conn
    |> json_response(200)
    |> Map.fetch!("uplinks")
    |> Enum.map(& &1["hotspot_name"])
    |> Enum.sort()
  end

  defp ingest(timestamp, hotspot, rssi) do
    {:ok, at, _} = DateTime.from_iso8601(timestamp)
    reported_at = DateTime.to_unix(at, :millisecond)

    {:ok, %{status: "success"}} =
      Ingest.ingest_uplink(%{
        "app_eui" => "0000000000000000",
        "dev_eui" => "00000000000000AA",
        "id" => "test-device",
        "fcnt" => 1,
        "reported_at" => reported_at,
        "decoded" => %{
          "payload" => %{"latitude" => @lat, "longitude" => @lng, "altitude" => 10, "accuracy" => 2.0},
          "status" => "success"
        },
        "hotspots" => [
          %{
            "id" => "address-#{hotspot}",
            "name" => hotspot,
            "lat" => @lat + 0.01,
            "long" => @lng + 0.01,
            "rssi" => rssi,
            "snr" => 5.0,
            "frequency" => 904.3,
            "spreading" => "SF10BW125",
            "reported_at" => reported_at
          }
        ]
      })
  end
end
