defmodule MappersWeb.API.V1.IngestUplinkControllerTest do
  use MappersWeb.ConnCase

  import ExUnit.CaptureLog
  import Mappers.IngestFixtures

  alias Mappers.Repo
  alias Mappers.H3.Res9
  alias Mappers.H3.Links.Link
  alias Mappers.Uplinks.Uplink
  alias Mappers.UplinksHeards.UplinkHeard

  @path "/api/v1/ingest/uplink"

  defp post_uplink(conn, body, query \\ "") do
    conn
    |> put_req_header("content-type", "application/json")
    |> post(@path <> query, Jason.encode!(body))
  end

  defp row_counts do
    for schema <- [Res9, Uplink, UplinkHeard, Link], into: %{} do
      {schema, Repo.aggregate(schema, :count)}
    end
  end

  defp assert_nothing_written(before), do: assert(row_counts() == before)

  defp update_rx(body, index, fun), do: update_in(body, ["rxInfo", Access.at(index)], fun)

  defp set_rx_times(rx, times),
    do: rx |> Map.drop(["gwTime", "nsTime", "time"]) |> Map.merge(times)

  defp heard_times do
    for heard <- Repo.all(UplinkHeard), into: %{} do
      {heard.hotspot_name, heard.timestamp |> DateTime.truncate(:second) |> DateTime.to_iso8601()}
    end
  end

  defp update_hotspot(body, index, fun), do: update_in(body, ["hotspots", Access.at(index)], fun)

  describe "ChirpStack uplinks" do
    test "a v4.6+ uplink (gwTime/nsTime, no time) is stored", %{conn: conn} do
      conn = post_uplink(conn, chirpstack_up(), "?event=up")
      assert %{"status" => "success"} = json_response(conn, 200)

      [uplink] = Repo.all(Uplink)
      assert uplink.dev_eui == "a84041000181c0de"
      # the duplicate "id" key used to store the deduplicationId here
      assert uplink.device_id == "a84041000181c0de"
      assert uplink.app_eui == "0000000000000000"
      assert uplink.fcnt == 42
      assert uplink.spreading_factor == "SF7BW125"
      assert uplink.frequency == 868.1

      heard = Repo.all(UplinkHeard) |> Enum.sort_by(& &1.rssi, :desc)
      assert Enum.map(heard, & &1.hotspot_name) == ["example-gateway-one", "example-gateway-two"]
      assert Enum.map(heard, & &1.snr) == [7.5, -3.25]
      assert hd(heard).latitude == 51.508
      assert DateTime.to_unix(hd(heard).timestamp) == DateTime.to_unix(~U[2026-10-09 16:43:51Z])

      [hex] = Repo.all(Res9)
      assert hex.best_rssi == -95.0
      assert hex.snr == 7.5
      assert [%Link{h3_res9_id: hex_id}] = Repo.all(Link)
      assert hex_id == hex.id
    end

    test "rxInfo times are read in the order gwTime, nsTime, time", %{conn: conn} do
      body =
        chirpstack_up()
        |> update_rx(
          0,
          &set_rx_times(&1, %{
            "gwTime" => "2026-10-09T16:43:55Z",
            "nsTime" => "2026-10-09T16:43:57Z"
          })
        )
        |> update_rx(
          1,
          &set_rx_times(&1, %{
            "nsTime" => "2026-10-09T16:43:57Z",
            "time" => "2026-10-09T16:43:53Z"
          })
        )

      assert json_response(post_uplink(conn, body, "?event=up"), 200)

      assert heard_times() == %{
               "example-gateway-one" => "2026-10-09T16:43:55Z",
               "example-gateway-two" => "2026-10-09T16:43:57Z"
             }
    end

    test "a pre-4.6 rxInfo time is read", %{conn: conn} do
      body = update_rx(chirpstack_up(), 0, &set_rx_times(&1, %{"time" => "2026-10-09T16:43:53Z"}))

      assert json_response(post_uplink(conn, body, "?event=up"), 200)
      assert heard_times()["example-gateway-one"] == "2026-10-09T16:43:53Z"
    end

    test "a gateway clock that is wildly wrong falls back to nsTime", %{conn: conn} do
      body =
        update_rx(
          chirpstack_up(),
          0,
          &set_rx_times(&1, %{
            "gwTime" => "1980-01-06T00:00:00Z",
            "nsTime" => "2026-10-09T16:43:57Z"
          })
        )

      assert json_response(post_uplink(conn, body, "?event=up"), 200)
      assert heard_times()["example-gateway-one"] == "2026-10-09T16:43:57Z"
    end

    test "an rxInfo without snr (ChirpStack omits 0.0) is stored as 0.0", %{conn: conn} do
      body = update_rx(chirpstack_up(), 1, &Map.delete(&1, "snr"))

      assert json_response(post_uplink(conn, body), 200)
      assert Enum.sort(Enum.map(Repo.all(UplinkHeard), & &1.snr)) == [0.0, 7.5]
    end

    test "whole-number gateway coordinates parse", %{conn: conn} do
      body = update_rx(chirpstack_up(), 0, &put_in(&1, ["metadata", "gateway_lat"], "51"))

      assert json_response(post_uplink(conn, body), 200)
      assert Enum.any?(Repo.all(UplinkHeard), &(&1.latitude == 51.0))
    end

    test "a gateway that fails validation does not set the hex's best RSSI", %{conn: conn} do
      far_away = rx_info("11exampleFarGateway", "example-far-gateway", "40.7", "-74.0", -40, 9.0)
      body = update_in(chirpstack_up(), ["rxInfo"], &(&1 ++ [far_away]))

      assert json_response(post_uplink(conn, body), 200)
      assert Repo.aggregate(UplinkHeard, :count) == 2
      assert [%Res9{best_rssi: -95.0}] = Repo.all(Res9)
    end

    test "a reported failed fix is rejected as no_fix", %{conn: conn} do
      before = row_counts()
      body = put_in(chirpstack_up(), ["object", "fixFailed"], true)

      assert %{"error" => "no_fix"} = json_response(post_uplink(conn, body), 422)
      assert_nothing_written(before)
    end

    test "an empty decoded object is rejected as no_position", %{conn: conn} do
      before = row_counts()
      body = Map.put(chirpstack_up(), "object", %{})

      assert %{"error" => "no_position"} = json_response(post_uplink(conn, body), 422)
      assert_nothing_written(before)
    end

    test "gateways without a location are rejected as no_hotspot_location", %{conn: conn} do
      before = row_counts()

      body =
        chirpstack_up()
        |> update_rx(
          0,
          &update_in(&1, ["metadata"], fn m -> Map.drop(m, ["gateway_lat", "gateway_long"]) end)
        )
        |> update_rx(
          1,
          &update_in(&1, ["metadata"], fn m -> Map.drop(m, ["gateway_lat", "gateway_long"]) end)
        )

      assert %{"error" => "no_hotspot_location"} = json_response(post_uplink(conn, body), 422)
      assert_nothing_written(before)
    end

    test "an uplink with no readable timestamp is rejected as no_timestamp", %{conn: conn} do
      before = row_counts()

      body =
        chirpstack_up()
        |> Map.delete("time")
        |> update_rx(0, &Map.drop(&1, ["gwTime", "nsTime"]))
        |> update_rx(1, &Map.drop(&1, ["gwTime", "nsTime"]))

      assert %{"error" => "no_timestamp"} = json_response(post_uplink(conn, body), 422)
      assert_nothing_written(before)
    end

    test "an up event without rxInfo is rejected rather than ignored", %{conn: conn} do
      body = Map.drop(chirpstack_up(), ["rxInfo", "txInfo"])

      assert %{"error" => "unsupported_payload"} =
               json_response(post_uplink(conn, body, "?event=up"), 422)
    end

    test "non-LoRa uplinks are rejected as unsupported_modulation", %{conn: conn} do
      body =
        put_in(chirpstack_up(), ["txInfo", "modulation"], %{"fsk" => %{"datarate" => 50_000}})

      assert %{"error" => "unsupported_modulation"} = json_response(post_uplink(conn, body), 422)
    end
  end

  describe "ChirpStack events that aren't uplinks" do
    test "are acknowledged with 204 and write nothing", %{conn: conn} do
      before = row_counts()

      assert response(post_uplink(conn, chirpstack_log(), "?event=log"), 204) == ""

      assert response(
               post_uplink(
                 build_conn(),
                 %{"deviceInfo" => %{}, "batteryLevel" => 90.0},
                 "?event=status"
               ),
               204
             )

      # a relayed join event without ?event
      assert response(
               post_uplink(build_conn(), %{"deviceInfo" => %{}, "devAddr" => "fc00ac11"}),
               204
             )

      assert_nothing_written(before)
    end
  end

  describe "Console uplinks" do
    test "a minimal Console uplink is stored", %{conn: conn} do
      assert %{"status" => "success"} = json_response(post_uplink(conn, console_uplink()), 200)

      [uplink] = Repo.all(Uplink)
      assert uplink.device_id == "1b9a6c5e-1111-4222-8333-944455556666"
      assert uplink.frequency == 916.8
      assert uplink.spreading_factor == "SF9BW125"
      assert uplink.altitude == 58
      assert Repo.aggregate(UplinkHeard, :count) == 2
      assert [%Res9{best_rssi: -101.0, snr: 6.5}] = Repo.all(Res9)
    end

    test "a hotspot without snr no longer crashes the uplink", %{conn: conn} do
      body = update_hotspot(console_uplink(), 1, &Map.delete(&1, "snr"))

      assert json_response(post_uplink(conn, body), 200)
      assert Enum.sort(Enum.map(Repo.all(UplinkHeard), & &1.snr)) == [0.0, 6.5]
    end

    test "a single hotspot without snr is stored", %{conn: conn} do
      body =
        Map.update!(console_uplink(), "hotspots", fn [first | _] -> [Map.delete(first, "snr")] end)

      assert json_response(post_uplink(conn, body), 200)
      assert [%UplinkHeard{snr: snr}] = Repo.all(UplinkHeard)
      assert snr == 0.0
    end

    test "integer device coordinates are stored", %{conn: conn} do
      body =
        update_in(
          console_uplink(),
          ["decoded", "payload"],
          &Map.merge(&1, %{"latitude" => -34, "longitude" => 151})
        )

      assert json_response(post_uplink(conn, body), 200)
      assert Repo.aggregate(Res9, :count) == 1
    end

    test "decoder errors are rejected as decoder_error", %{conn: conn} do
      at_decoded =
        Map.put(console_uplink(), "decoded", %{
          "status" => "error",
          "error" => "example decode failure"
        })

      at_payload =
        put_in(console_uplink(), ["decoded", "payload"], %{"error" => "example decode failure"})

      assert %{"error" => "decoder_error"} = json_response(post_uplink(conn, at_decoded), 422)

      assert %{"error" => "decoder_error"} =
               json_response(post_uplink(build_conn(), at_payload), 422)
    end

    test "a payload without a position is rejected as no_position", %{conn: conn} do
      sensor = %{
        "temperature" => 21.5,
        "level" => 0.62,
        "alarmLevel" => false,
        "alarmBattery" => false
      }

      at_zero =
        update_in(
          console_uplink(),
          ["decoded", "payload"],
          &Map.merge(&1, %{"latitude" => 0, "longitude" => 0})
        )

      assert %{"error" => "no_position"} =
               json_response(
                 post_uplink(conn, put_in(console_uplink(), ["decoded", "payload"], sensor)),
                 422
               )

      assert %{"error" => "no_position"} = json_response(post_uplink(build_conn(), at_zero), 422)
    end

    test "a missing accuracy is rejected before anything is written", %{conn: conn} do
      before = row_counts()
      body = update_in(console_uplink(), ["decoded", "payload"], &Map.delete(&1, "accuracy"))

      assert %{"error" => "invalid_accuracy"} = json_response(post_uplink(conn, body), 422)
      assert_nothing_written(before)
    end

    test "a timestamp from a wildly wrong clock is rejected", %{conn: conn} do
      before = row_counts()
      year_2478 = 16_088_428_800_000
      body = Map.put(console_uplink(), "reported_at", year_2478)

      assert %{"error" => "invalid_timestamp"} = json_response(post_uplink(conn, body), 422)
      assert_nothing_written(before)
    end

    test "a hotspot with a wildly wrong clock gets the uplink's time", %{conn: conn} do
      body =
        console_uplink()
        |> Map.put("reported_at", 1_791_571_400_000)
        |> update_hotspot(1, &Map.put(&1, "reported_at", 16_088_428_800_000))

      assert json_response(post_uplink(conn, body), 200)

      assert heard_times() == %{
               "example-hotspot-three" => "2026-10-09T18:43:50Z",
               "example-hotspot-four" => "2026-10-09T18:43:20Z"
             }
    end

    test "fields that wouldn't fit their columns are rejected before anything is written", %{
      conn: conn
    } do
      before = row_counts()
      long_eui = Map.put(console_uplink(), "dev_eui", String.duplicate("A", 300))
      huge_fcnt = Map.put(console_uplink(), "fcnt", 2_147_483_648)

      empty_ids =
        Map.update!(console_uplink(), "hotspots", &Enum.map(&1, fn h -> Map.put(h, "id", "") end))

      assert %{"error" => "invalid_field", "detail" => "dev_eui"} =
               json_response(post_uplink(conn, long_eui), 422)

      assert %{"error" => "invalid_field", "detail" => "fcnt"} =
               json_response(post_uplink(build_conn(), huge_fcnt), 422)

      assert %{"error" => "no_valid_hotspots"} =
               json_response(post_uplink(build_conn(), empty_ids), 422)

      assert_nothing_written(before)
    end

    test "a second uplink in the same hex keeps the better RSSI", %{conn: conn} do
      weaker = update_hotspot(console_uplink(), 0, &Map.put(&1, "rssi", -120))

      stronger =
        update_hotspot(console_uplink(), 0, &Map.merge(&1, %{"rssi" => -80, "snr" => 9.0}))

      assert json_response(post_uplink(conn, weaker), 200)
      assert [%Res9{best_rssi: -117.0}] = Repo.all(Res9)
      assert json_response(post_uplink(build_conn(), stronger), 200)
      assert [%Res9{best_rssi: -80.0, snr: 9.0}] = Repo.all(Res9)
      assert json_response(post_uplink(build_conn(), weaker), 200)
      assert [%Res9{best_rssi: -80.0, snr: 9.0}] = Repo.all(Res9)
    end
  end

  describe "other requests" do
    test "a body that isn't JSON (e.g. ChirpStack's Protobuf encoding) gets 415", %{conn: conn} do
      protobuf =
        conn
        |> put_req_header("content-type", "application/octet-stream")
        |> post(@path <> "?event=up", <<10, 36, 54, 102>>)

      plain =
        build_conn()
        |> put_req_header("content-type", "text/plain")
        |> post(@path, Jason.encode!(console_uplink()))

      assert %{"error" => "unsupported_encoding"} = json_response(protobuf, 415)
      assert %{"error" => "unsupported_encoding"} = json_response(plain, 415)
    end

    test "outcomes are counted for Prometheus", %{conn: conn} do
      post_uplink(conn, chirpstack_up(), "?event=up")

      assert TelemetryMetricsPrometheus.Core.scrape()
             |> String.split("\n")
             |> Enum.any?(fn line ->
               String.starts_with?(line, "ingest_outcome_count{") and
                 Enum.all?(
                   [~s(format="chirpstack"), ~s(reason="stored"), ~s(status="200")],
                   &(line =~ &1)
                 )
             end)
    end

    test "any Accept header is fine", %{conn: conn} do
      conn = conn |> put_req_header("accept", "text/plain") |> post_uplink(console_uplink())

      assert json_response(conn, 200)
    end

    test "JSON in neither format is rejected as unsupported_payload", %{conn: conn} do
      body = %{"decoded" => %{"payload" => %{"latitude" => 51.5, "longitude" => -0.12}}}

      assert %{"error" => "unsupported_payload"} = json_response(post_uplink(conn, body), 422)
    end
  end

  describe "outcome logging" do
    setup do
      level = Logger.level()
      Logger.configure(level: :info)
      on_exit(fn -> Logger.configure(level: level) end)
    end

    test "logs exactly one line per request with status, reason and format", %{conn: conn} do
      log =
        capture_log(fn ->
          post_uplink(conn, chirpstack_up(), "?event=up")
          post_uplink(build_conn(), chirpstack_log(), "?event=log")
          post_uplink(build_conn(), Map.put(chirpstack_up(), "object", %{}), "?event=up")

          build_conn()
          |> put_req_header("content-type", "application/octet-stream")
          |> post(@path <> "?event=up", <<10, 36>>)
        end)

      assert length(Regex.scan(~r/ingest status=/, log)) == 4

      assert log =~
               ~r/ingest status=200 reason=stored format=chirpstack event=up sender=\S+ hotspots=2 ms=\d+/

      assert log =~ "ingest status=204 reason=not_uplink format=chirpstack_event event=log"
      assert log =~ "ingest status=422 reason=no_position format=chirpstack event=up"
      assert log =~ "ingest status=415 reason=unsupported_encoding format=unknown event=up"
    end

    test "a crash is logged once, as a 500", %{conn: conn} do
      # make the last write fail with a database error; the sandbox rolls this back
      Repo.query!("DROP TABLE h3_links")

      log =
        capture_log(fn ->
          assert_raise Postgrex.Error, fn -> post_uplink(conn, chirpstack_up(), "?event=up") end
        end)

      assert length(Regex.scan(~r/ingest status=/, log)) == 1
      assert log =~ "ingest status=500 reason=crash format=chirpstack event=up"
    end

    test "a list-valued ?event is logged as other and not treated as an uplink", %{conn: conn} do
      log =
        capture_log(fn ->
          assert response(post_uplink(conn, chirpstack_up(), "?event[]=up"), 204)
        end)

      assert length(Regex.scan(~r/ingest status=/, log)) == 1
      assert log =~ "ingest status=204 reason=not_uplink format=chirpstack event=other"
    end

    test "sender comes from cf-connecting-ip, and odd values are not logged verbatim", %{
      conn: conn
    } do
      log =
        capture_log(fn ->
          conn
          |> put_req_header("cf-connecting-ip", "203.0.113.7")
          |> post_uplink(chirpstack_log(), "?event=log")

          build_conn()
          |> put_req_header("cf-connecting-ip", "1.2.3.4\nfake=1")
          |> post_uplink(chirpstack_log(), "?event=log")
        end)

      assert log =~ "sender=203.0.113.7 "
      assert log =~ "sender=other "
      refute log =~ "fake=1"
    end

    test "requests over the rate limit are logged as rate_limited", %{conn: conn} do
      post = fn conn ->
        conn
        |> put_req_header("cf-connecting-ip", "198.51.100.9")
        |> post_uplink(chirpstack_log(), "?event=log")
      end

      log =
        capture_log(fn ->
          for _ <- 1..120, do: assert(response(post.(build_conn()), 204))
          assert post.(conn).status == 429
        end)

      assert log =~
               "ingest status=429 reason=rate_limited format=chirpstack_event event=log sender=198.51.100.9"
    end
  end
end
