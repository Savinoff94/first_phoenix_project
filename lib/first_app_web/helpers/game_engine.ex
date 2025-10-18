defmodule FirstAppWeb.GameEngine do
  use GenServer
  alias Phoenix.PubSub
  alias FirstAppWeb.RPS
  alias FirstAppWeb.LinkedList

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

    {:ok,
     %{
       lobby_id: id,
       topic: topic,
       events: nil,
       game: %{leftPlayer: nil, rightPlayer: nil}
     }}
  end

  def handle_cast({:dispatch, type, data}, state) do
    new_events = LinkedList.prepend(state.events, type, data)
    new_state  = %{state | events: new_events}
    updated    = process_event(type, data, new_state)

    PubSub.broadcast(FirstApp.PubSub, updated.topic, {:game_updated, updated.game})

    {:noreply, updated}
  end

  # player leave
  defp process_event(:player_leave, %{login: login}, state) do
    new_game =
      state.game
      |> Map.update(:leftPlayer, nil, fn
        %{login: ^login} -> nil
        player -> player
      end)
      |> Map.update(:rightPlayer, nil, fn
        %{login: ^login} -> nil
        player -> player
      end)

    %{state | game: new_game}
  end
end
