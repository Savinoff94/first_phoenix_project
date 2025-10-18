defmodule FirstApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FirstAppWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:first_app, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: FirstApp.PubSub},
      # Start a worker by calling: FirstApp.Worker.start_link(arg)
      # {FirstApp.Worker, arg},
      # Start to serve requests, typically the last entry
      {Registry, keys: :unique, name: FirstAppWeb.LobbyRegistry},
      {Registry, keys: :unique, name: FirstAppWeb.GameEngineRegistry},
      {FirstAppWeb.LobbySupervisor, []},
      {FirstAppWeb.Players, []},
      {FirstAppWeb.LobbiesManager, []},
      {FirstAppWeb.Presence, []},
      FirstAppWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FirstApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FirstAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
