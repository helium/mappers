defmodule Mappers.Uplinks.FilterTest do
  use ExUnit.Case, async: true

  alias Mappers.Uplinks.Filter

  test "no params means no filter" do
    assert {:ok, %Filter{start: nil, end: nil, hotspot: nil}} = Filter.parse(%{})
  end

  test "blank params are ignored" do
    assert {:ok, %Filter{start: nil, end: nil, hotspot: nil}} =
             Filter.parse(%{"start" => "", "end" => " ", "hotspot" => ""})
  end

  test "bare dates are midnight UTC" do
    assert {:ok, filter} = Filter.parse(%{"start" => "2025-01-01", "end" => "2025-02-01"})
    assert filter.start == ~U[2025-01-01 00:00:00Z]
    assert filter.end == ~U[2025-02-01 00:00:00Z]
  end

  test "accepts datetimes and hotspot names" do
    assert {:ok, filter} =
             Filter.parse(%{"start" => "2025-01-01T12:30:00Z", "hotspot" => "happy-amber-moose"})

    assert filter.start == ~U[2025-01-01 12:30:00Z]
    assert filter.hotspot == "happy-amber-moose"
  end

  test "rejects unparseable dates" do
    assert {:error, "Invalid start" <> _} = Filter.parse(%{"start" => "last tuesday"})
  end

  test "rejects a start that is not before the end" do
    assert {:error, "start must be before end"} =
             Filter.parse(%{"start" => "2025-02-01", "end" => "2025-01-01"})
  end
end
