defmodule AbaViewer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      AbaViewerWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: AbaViewer.PubSub},
      # Start Finch
      {Finch, name: AbaViewer.Finch},
      # Start the Endpoint (http/https)
      AbaViewerWeb.Endpoint,
      {Task, fn -> shutdown_when_inactive(:timer.minutes(1)) end},
      # Start a worker by calling: AbaViewer.Worker.start_link(arg)
      # {AbaViewer.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AbaViewer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AbaViewerWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp shutdown_when_inactive(every_ms) do
    IO.puts("prepping shutdown_when_inactive")
    Process.sleep(every_ms)
    if :ranch.procs(AbaViewerWeb.Endpoint.HTTP, :connections) |> IO.inspect(label: "shutdown_when_inactive") == [] do
      System.stop(0)
    else
      shutdown_when_inactive(every_ms)
    end
  end
end
