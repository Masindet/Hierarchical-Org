defmodule TreeOrg.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TreeOrgWeb.Telemetry,
      #TreeOrg.Repo,
      {DNSCluster, query: Application.get_env(:tree_org, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TreeOrg.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: TreeOrg.Finch},
      # Start the ETS storage server
      TreeOrg.TreeStorageServer,
      # Start to serve requests, typically the last entry
      TreeOrgWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TreeOrg.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TreeOrgWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
