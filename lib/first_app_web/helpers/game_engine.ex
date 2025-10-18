defmodule RPS.GameEngine do
  use GenServer
  alias Phoenix.PubSub

  def start_link(opts) do
    lobby_id = Keyword.fetch!(opts, :lobby_id)
    GenServer.start_link(__MODULE__, %{lobby_id: lobby_id}, name: via_tuple(lobby_id))
  end

  defp via_tuple(lobby_id),
    do: {:via, Registry, {FirstAppWeb.GameEngineRegistry, lobby_id}}

  # Usual dispatch
  def dispatch(lobby_id, type, data),
    do: GenServer.cast(via_tuple(lobby_id), {:dispatch, type, data})

  # Callbacks
  def init(%{lobby_id: id}) do
    topic = "game:#{id}"

    {:ok, %{lobby_id: id, topic: topic, events: [], game: %{}}}
  end
end
