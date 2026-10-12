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

    test "lists hotspots strongest RSSI first", %{conn: conn} do
      ingest("2025-07-01T10:00:00Z", "brisk-alder-heron", -110)

      assert ordered(get(conn, "/api/v1/uplinks/hex/#{@hex}")) ==
               [{"quiet-cedar-otter", -90.0}, {"happy-amber-moose", -100.0}, {"brisk-alder-heron", -110.0}]
    end

    test "returns one row per hotspot with its best RSSI", %{conn: conn} do
      ingest("2023-05-01T10:00:00Z", "happy-amber-moose", -80)
      ingest("2025-08-01T10:00:00Z", "happy-amber-moose", -115)

      assert ordered(get(conn, "/api/v1/uplinks/hex/#{@hex}")) ==
               [{"happy-amber-moose", -80.0}, {"quiet-cedar-otter", -90.0}]
    end

    test "picks the best RSSI within the filtered time range", %{conn: conn} do
      ingest("2023-05-01T10:00:00Z", "happy-amber-moose", -80)

      conn = get(conn, "/api/v1/uplinks/hex/#{@hex}?start=2024-01-01")
      assert ordered(conn) == [{"quiet-cedar-otter", -90.0}, {"happy-amber-moose", -100.0}]
    end

    test "rejects a bad date", %{conn: conn} do
      conn = get(conn, "/api/v1/uplinks/hex/#{@hex}?start=nope")
      assert %{"error" => "Invalid start" <> _} = json_response(conn, 400)
    end
  end

  describe "GET /api/v1/uplinks/latest" do
    @other_hex :h3.from_geo({37.8044, -122.2712}, 9) |> :h3.to_string() |> to_string()

    test "returns the most recently heard uplink and its hex", %{conn: conn} do
      ingest("2025-09-01T10:00:00Z", "brave-lime-heron", -95, {37.8044, -122.2712})

      assert %{"h3_id" => @other_hex, "hotspot_name" => "brave-lime-heron", "timestamp" => timestamp} =
               latest(get(conn, "/api/v1/uplinks/latest"))

      assert {:ok, heard_at, 0} = DateTime.from_iso8601(timestamp)
      assert DateTime.compare(heard_at, ~U[2025-09-01 10:00:00Z]) == :eq
    end

    test "filters by heard time", %{conn: conn} do
      conn = get(conn, "/api/v1/uplinks/latest?end=2025-01-01")
      assert %{"h3_id" => @hex, "hotspot_name" => "happy-amber-moose"} = latest(conn)
    end

    test "filters by hotspot", %{conn: conn} do
      conn = get(conn, "/api/v1/uplinks/latest?hotspot=happy-amber-moose")
      assert %{"hotspot_name" => "happy-amber-moose"} = latest(conn)
    end

    test "returns null when nothing matches", %{conn: conn} do
      assert latest(get(conn, "/api/v1/uplinks/latest?start=2026-01-01")) == nil
    end

    test "rejects a bad date", %{conn: conn} do
      conn = get(conn, "/api/v1/uplinks/latest?end=nope")
      assert %{"error" => "Invalid end" <> _} = json_response(conn, 400)
    end

    test "rejects a reversed range", %{conn: conn} do
      conn = get(conn, "/api/v1/uplinks/latest?start=2025-01-01&end=2024-01-01")
      assert %{"error" => "start must be before end"} = json_response(conn, 400)
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

  defp ordered(conn) do
    conn
    |> json_response(200)
    |> Map.fetch!("uplinks")
    |> Enum.map(&{&1["hotspot_name"], &1["rssi"]})
  end

  defp latest(conn), do: conn |> json_response(200) |> Map.fetch!("latest")

  defp ingest(timestamp, hotspot, rssi, {lat, lng} \\ {@lat, @lng}) do
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
          "payload" => %{"latitude" => lat, "longitude" => lng, "altitude" => 10, "accuracy" => 2.0},
          "status" => "success"
        },
        "hotspots" => [
          %{
            "id" => "address-#{hotspot}",
            "name" => hotspot,
            "lat" => lat + 0.01,
            "long" => lng + 0.01,
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
