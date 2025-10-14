defmodule FirstAppWeb.LobbyServer do
  use GenServer

  def start_link(%{id: id} = lobby) do
    GenServer.start_link(__MODULE__, lobby, name: via_tuple(id))
  end

  def via_tuple(id), do: {:via, Registry, {FirstAppWeb.LobbyRegistry, id}}

  # API
  def add_player(id, player) do
    GenServer.cast(via_tuple(id), {:add_player, player})
  end

  def state(id) do
    GenServer.call(via_tuple(id), :state)
  end

  # Callbacks
  def init(lobby) do
    IO.inspect(lobby, label: "INIT LOBBY SERVER")
    IO.puts("✅ Started LobbyServer for #{lobby.name} (#{lobby.id})")
    {:ok, lobby}
  end

  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:add_player, player}, state) do
    new_state = update_in(state.players, &[player | &1])
    {:noreply, new_state}
  end

  def terminate(reason, state) do
    IO.puts("💀 Lobby #{state.name} (#{state.id}) terminated: #{inspect(reason)}")

    # Optional cleanup logic:
    # - remove from ETS or Registry
    # - notify PubSub subscribers
    # - persist state to DB or file
    # - cancel timers, etc.
    :ok
  end
end
