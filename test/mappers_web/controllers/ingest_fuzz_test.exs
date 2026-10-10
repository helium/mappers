defmodule MappersWeb.API.V1.IngestFuzzTest do
  # Mangled versions of real payload shapes must be answered (stored, ignored or rejected
  # with a reason), never crash with a 500.
  use MappersWeb.ConnCase

  import Mappers.IngestFixtures

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

    mutated =
      for _ <- 1..String.to_integer(System.get_env("FUZZ_RUNS", "400")) do
        base = Enum.random([chirpstack_up(), console_uplink()])
        Enum.reduce(1..Enum.random(1..3), base, fn _, body -> mutate(body) end)
      end

    requests = mutated ++ [[], "text", 42, [chirpstack_up()]]

    failures =
      requests
      |> Enum.with_index()
      |> Enum.map(fn {body, i} -> attempt(body, Enum.random(@queries), i) end)
      |> Enum.reject(&is_nil/1)

    assert failures == [],
           "#{length(failures)} of #{length(requests)} requests failed:\n" <>
             (failures
              |> Enum.uniq_by(&elem(&1, 0))
              |> Enum.map_join("\n", &inspect(&1, limit: 12)))
  end

  # nil when the request got an expected answer, else {what went wrong, body}
  defp attempt(body, query, i) do
    conn =
      build_conn()
      # a sender per request, so the rate limit doesn't interfere
      |> put_req_header("cf-connecting-ip", "10.9.#{div(i, 250)}.#{rem(i, 250)}")
      |> post_uplink(body, query)

    if conn.status in [200, 204, 422], do: nil, else: {"#{conn.status} #{conn.resp_body}", body}
  rescue
    e -> {("raised " <> Exception.message(e)) |> String.slice(0, 160), body}
  end

  defp mutate(body) do
    case paths(body, []) -- [[]] do
      [] ->
        body

      paths ->
        path = paths |> Enum.random() |> Enum.map(&access/1)

        if :rand.uniform() < 0.3,
          do: body |> pop_in(path) |> elem(1),
          else: put_in(body, path, Enum.random(@junk))
    end
  end

  defp access(index) when is_integer(index), do: Access.at(index)
  defp access(key), do: key

  defp paths(value, prefix) when is_map(value),
    do: [prefix | Enum.flat_map(value, fn {k, v} -> paths(v, prefix ++ [k]) end)]

  defp paths(value, prefix) when is_list(value) do
    [
      prefix
      | value |> Enum.with_index() |> Enum.flat_map(fn {v, i} -> paths(v, prefix ++ [i]) end)
    ]
  end

  defp paths(_value, prefix), do: [prefix]
end
