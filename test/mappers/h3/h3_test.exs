defmodule Mappers.H3Test do
  use Mappers.DataCase, async: true

  alias Mappers.H3
  alias Mappers.H3.Res9

  @lat 37.7749
  @lng -122.4194

  defp message(rssi, reported_at) do
    %{
      "decoded" => %{"payload" => %{"latitude" => @lat, "longitude" => @lng}},
      # ingest hands H3 float rssi
      "hotspots" => [%{"rssi" => rssi * 1.0, "snr" => 5.5}],
      "reported_at" => reported_at
    }
  end

  defp ms(datetime), do: DateTime.to_unix(datetime, :millisecond)

  defp hex do
    id = :h3.from_geo({@lat, @lng}, 9) |> :h3.to_string() |> to_string()
    Repo.get!(Res9, id)
  end

  defp unix(datetime), do: DateTime.to_unix(datetime)

  test "a new hex records when it was heard" do
    assert {:ok, _} = H3.create(message(-100, ms(~U[2026-09-01 12:00:00.750Z])))

    assert hex().last_heard == unix(~U[2026-09-01 12:00:00Z])
  end

  test "a later, weaker uplink moves last_heard but keeps the best rssi" do
    {:ok, _} = H3.create(message(-90, ms(~U[2026-09-01 12:00:00Z])))
    {:ok, _} = H3.create(message(-110, ms(~U[2026-09-02 08:30:00Z])))

    hex = hex()
    assert hex.best_rssi == -90.0
    assert hex.last_heard == unix(~U[2026-09-02 08:30:00Z])
  end

  test "an older uplink arriving late does not move last_heard back" do
    {:ok, _} = H3.create(message(-110, ms(~U[2026-09-02 08:30:00Z])))
    {:ok, _} = H3.create(message(-80, ms(~U[2026-08-01 00:00:00Z])))

    hex = hex()
    assert hex.best_rssi == -80.0
    assert hex.last_heard == unix(~U[2026-09-02 08:30:00Z])
  end

  test "a hex backfilled without a heard time picks one up on its next uplink" do
    {:ok, _} = H3.create(message(-90, ms(~U[2026-09-01 12:00:00Z])))
    hex() |> Ecto.Changeset.change(last_heard: nil) |> Repo.update!()

    {:ok, _} = H3.create(message(-120, ms(~U[2026-09-03 00:00:00Z])))

    assert hex().last_heard == unix(~U[2026-09-03 00:00:00Z])
  end

  test "a missing reported_at falls back to now" do
    before = System.os_time(:second)
    {:ok, _} = H3.create(message(-100, nil))

    assert hex().last_heard >= before
  end

  test "a reported_at in the future is clamped to now" do
    future = DateTime.add(DateTime.utc_now(), 30 * 24 * 3600, :second)
    {:ok, _} = H3.create(message(-100, ms(future)))

    assert (System.os_time(:second) - hex().last_heard) in 0..5
  end

  test "new hexes broadcast their heard time in epoch seconds" do
    MappersWeb.Endpoint.subscribe("h3:new")
    {:ok, _} = H3.create(message(-100, ms(~U[2026-09-01 12:00:00Z])))

    assert_receive %Phoenix.Socket.Broadcast{payload: %{body: %{last_heard: 1_788_264_000}}}
  end
end
