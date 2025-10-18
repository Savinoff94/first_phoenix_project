defmodule FirstAppWeb.LobbySupervisor.LobbyTree do
  use Supervisor

  def start_link(lobby) do
    id = lobby.id
    Supervisor.start_link(__MODULE__, lobby, name: via_tuple(id))
  end

  defp via_tuple(lobby_id),
    do: {:via, Registry, {FirstAppWeb.LobbyRegistry, "lobby_tree:#{lobby_id}"}}

  @impl true
  def init(lobby) do
    lobby_id = lobby.id

    children = [
      {FirstAppWeb.LobbyServer, lobby},
      {FirstAppWeb.GameEngine, lobby_id: lobby_id},
      {FirstAppWeb.TimerWorker, lobby_id: lobby_id, seconds: 5}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
