defmodule Mic.Repo do
  use Ecto.Repo,
    otp_app: :mic,
    adapter: Ecto.Adapters.Postgres
end
