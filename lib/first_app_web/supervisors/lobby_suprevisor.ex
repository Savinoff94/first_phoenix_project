defmodule FirstAppWeb.LobbySupervisor do
  use DynamicSupervisor

  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # Starts a full lobby (GameEngine + TimerWorker)
  def start_lobby(lobby) do
    child_spec = {FirstAppWeb.LobbySupervisor.LobbyTree, lobby}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
end
