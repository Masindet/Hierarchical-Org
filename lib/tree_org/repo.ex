defmodule TreeOrg.Repo do
  use Ecto.Repo,
    otp_app: :tree_org,
    adapter: Ecto.Adapters.Postgres
end
