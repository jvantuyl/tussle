defmodule Tussle.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Tussle.Supervisor]
    case get_children() do
      {:error, _} = e -> e
      children when is_list(children) -> Supervisor.start_link(children, opts)
    end
  end

  defp get_children do
    Application.get_env(:tussle, :controllers, [])
    |> Enum.reduce_while([], fn controller, lst ->
      case Application.get_env(:tussle, controller) do
        worker_opts when is_list(worker_opts) ->
          {:cont, [start_worker(controller, worker_opts) | lst]}
        nil ->
            {:halt, {:error, "Tussle configuration for #{controller} not found"}}
      end
    end)
  end

  defp start_worker(controller, opts) do
    config = opts
    |> Enum.into(%{})
    |> Map.put(:cache_name, Module.concat(controller, TussleCache))

    # Modern child spec format (replaces deprecated Supervisor.Spec.worker/3)
    %{
      id: config.cache_name,
      start: {config.cache, :start_link, [config]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
  end
end
