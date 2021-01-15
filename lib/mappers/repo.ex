defmodule Mappers.Repo do
  use Ecto.Repo,
    otp_app: :mappers,
    adapter: Ecto.Adapters.Postgres
end
