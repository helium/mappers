defmodule MappersWeb.API.V1.IngestFuzzTest do
  # Mangled versions of real payload shapes must be answered (stored, ignored or rejected
  # with a reason), never crash with a 500.
  use MappersWeb.ConnCase

  import Mappers.IngestFixtures

  @path "/api/v1/ingest/uplink"
  @junk [
    nil,
    "",
    "51",
    "abc",
    "1e400",
    1.0e300,
    -0.0,
    0,
    2_147_483_648,
    [],
    %{},
    [1, 2],
    true,
    "2026-13-45T99:99:99Z",
    String.duplicate("x", 300),
    "∞ 東京",
    " ",
    "a" <> <<0>> <> "b",
    Integer.pow(10, 400),
    String.duplicate("9", 400)
  ]
  @queries [
    "",
    "?event=up",
    "?event=join",
    "?event=status",
    "?event=UP",
    "?event=a%20b%0Ac",
    "?event[]=up",
    "?event[x]=up"
  ]

  # FUZZ_SEED and FUZZ_RUNS widen the search locally; the default run is fixed and repeatable
  test "mutated payloads never get a 500" do
    :rand.seed(:exsss, {String.to_integer(System.get_env("FUZZ_SEED", "20261009")), 1, 2})

    bodies =
      for _ <- 1..String.to_integer(System.get_env("FUZZ_RUNS", "400")) do
        base = Enum.random([chirpstack_up(), console_uplink()])
        Enum.reduce(1..Enum.random(1..3), base, fn _, body -> mutate(body) end)
      end

    failures =
      (bodies ++ [[], "text", 42, [chirpstack_up()]])
      |> Enum.with_index()
      |> Enum.map(fn {body, i} -> attempt(body, Enum.random(@queries), i) end)
      |> Enum.reject(&is_nil/1)

    assert failures == [],
           "#{length(failures)} of #{length(bodies) + 4} requests failed:\n" <>
             (failures
              |> Enum.uniq_by(&elem(&1, 0))
              |> Enum.map_join("\n", &inspect(&1, limit: 12)))
  end

  # nil when the request got an expected answer, else {what went wrong, body}
  defp attempt(body, query, i) do
    conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      # a sender per request, so the rate limit doesn't interfere
      |> put_req_header("cf-connecting-ip", "10.9.#{div(i, 250)}.#{rem(i, 250)}")
      |> post(@path <> query, Jason.encode!(body))

    if conn.status in [200, 204, 422], do: nil, else: {"#{conn.status} #{conn.resp_body}", body}
  rescue
    e -> {("raised " <> Exception.message(e)) |> String.slice(0, 160), body}
  end

  defp mutate(body) do
    case paths(body, []) -- [[]] do
      [] ->
        body

      paths ->
        path = Enum.random(paths)

        if :rand.uniform() < 0.3,
          do: delete_at(body, path),
          else: put_at(body, path, Enum.random(@junk))
    end
  end

  defp paths(value, prefix) when is_map(value),
    do: [prefix | Enum.flat_map(value, fn {k, v} -> paths(v, prefix ++ [k]) end)]

  defp paths(value, prefix) when is_list(value) do
    [
      prefix
      | value |> Enum.with_index() |> Enum.flat_map(fn {v, i} -> paths(v, prefix ++ [i]) end)
    ]
  end

  defp paths(_value, prefix), do: [prefix]

  defp put_at(_value, [], new), do: new

  defp put_at(map, [key | rest], new) when is_map(map),
    do: Map.put(map, key, put_at(Map.get(map, key), rest, new))

  defp put_at(list, [i | rest], new) when is_list(list),
    do: List.update_at(list, i, &put_at(&1, rest, new))

  defp delete_at(map, [key]) when is_map(map), do: Map.delete(map, key)
  defp delete_at(list, [i]) when is_list(list), do: List.delete_at(list, i)

  defp delete_at(map, [key | rest]) when is_map(map),
    do: Map.update!(map, key, &delete_at(&1, rest))

  defp delete_at(list, [i | rest]) when is_list(list),
    do: List.update_at(list, i, &delete_at(&1, rest))
end
