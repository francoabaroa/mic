defmodule Mic.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MicWeb.Telemetry,
      Mic.Repo,
      {Oban, Application.fetch_env!(:mic, Oban)},
      {DNSCluster, query: Application.get_env(:mic, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Mic.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Mic.Finch},
      # Start a worker by calling: Mic.Worker.start_link(arg)
      # {Mic.Worker, arg},
      # Start to serve requests, typically the last entry
      MicWeb.Endpoint,
      Mic.Chat.Tokenizer
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Mic.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MicWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
